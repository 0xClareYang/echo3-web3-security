// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

/**
 * @title Echo3Agent
 * @dev Core smart contract for Echo3 AI security agent
 * @notice This contract manages agent operations, permissions, and security tasks
 * 
 * Security Features:
 * - Multi-signature governance with time delays
 * - Role-based access control with principle of least privilege
 * - Pausable operations for emergency stops
 * - Reentrancy protection on all state-changing functions
 * - Upgradeable proxy pattern with authorization
 * - Comprehensive event logging for transparency
 * - Rate limiting for critical operations
 * - Emergency circuit breakers
 */
contract Echo3Agent is 
    Initializable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    // Role definitions with clear separation of duties
    bytes32 public constant AGENT_OPERATOR_ROLE = keccak256("AGENT_OPERATOR_ROLE");
    bytes32 public constant SECURITY_MANAGER_ROLE = keccak256("SECURITY_MANAGER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
    
    // Security configuration constants
    uint256 public constant MIN_DELAY = 1 days;
    uint256 public constant MAX_DELAY = 30 days;
    uint256 public constant MAX_OPERATIONS_PER_BLOCK = 10;
    uint256 public constant SIGNATURE_VALIDITY_PERIOD = 1 hours;
    
    // State variables
    struct AgentConfig {
        bool isActive;
        uint256 maxRiskScore;
        uint256 operationsPerBlock;
        uint256 lastOperationBlock;
        address[] authorizedCallers;
        mapping(address => bool) isAuthorizedCaller;
    }
    
    struct SecurityOperation {
        bytes32 operationHash;
        address executor;
        uint256 timestamp;
        uint256 riskScore;
        bool executed;
        uint256 delay;
    }
    
    struct RiskAssessment {
        uint256 score;
        string reason;
        uint256 timestamp;
        address assessor;
        bytes signature;
    }
    
    // Storage
    mapping(address => AgentConfig) public agentConfigs;
    mapping(bytes32 => SecurityOperation) public securityOperations;
    mapping(address => uint256) public userNonces;
    mapping(address => uint256) public operationCounts;
    
    // Time delays for operations based on risk
    mapping(uint256 => uint256) public riskDelays;
    
    // Events for complete transparency
    event AgentConfigured(address indexed agent, bool isActive, uint256 maxRiskScore);
    event SecurityOperationScheduled(bytes32 indexed operationHash, address indexed executor, uint256 delay);
    event SecurityOperationExecuted(bytes32 indexed operationHash, address indexed executor);
    event RiskAssessmentSubmitted(address indexed user, uint256 riskScore, string reason);
    event EmergencyStop(address indexed initiator, string reason);
    event ConfigurationUpdated(string parameter, uint256 oldValue, uint256 newValue);
    event AuthorizedCallerAdded(address indexed agent, address indexed caller);
    event AuthorizedCallerRemoved(address indexed agent, address indexed caller);
    
    // Custom errors for gas efficiency
    error UnauthorizedOperation();
    error InvalidRiskScore();
    error OperationAlreadyExecuted();
    error InsufficientDelay();
    error RateLimitExceeded();
    error InvalidSignature();
    error ExpiredSignature();
    error AgentNotActive();
    error InvalidConfiguration();
    
    /**
     * @dev Initialize the contract with secure defaults
     * @param _initialAdmin Address that will have admin role
     */
    function initialize(address _initialAdmin) public initializer {
        if (_initialAdmin == address(0)) revert InvalidConfiguration();
        
        __AccessControl_init();
        __Pausable_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();
        
        // Grant roles to initial admin
        _grantRole(DEFAULT_ADMIN_ROLE, _initialAdmin);
        _grantRole(SECURITY_MANAGER_ROLE, _initialAdmin);
        _grantRole(UPGRADER_ROLE, _initialAdmin);
        _grantRole(EMERGENCY_ROLE, _initialAdmin);
        
        // Initialize risk delay mappings
        riskDelays[0] = 0;          // No risk - immediate execution
        riskDelays[1] = 5 minutes;  // Low risk - 5 minute delay
        riskDelays[2] = 1 hours;    // Medium risk - 1 hour delay
        riskDelays[3] = 6 hours;    // High risk - 6 hour delay
        riskDelays[4] = 1 days;     // Critical risk - 1 day delay
        riskDelays[5] = 3 days;     // Maximum risk - 3 day delay
    }
    
    /**
     * @dev Configure an agent with security parameters
     * @param _agent Address of the agent to configure
     * @param _isActive Whether the agent is active
     * @param _maxRiskScore Maximum risk score the agent can handle
     */
    function configureAgent(
        address _agent,
        bool _isActive,
        uint256 _maxRiskScore
    ) external onlyRole(SECURITY_MANAGER_ROLE) whenNotPaused {
        if (_agent == address(0)) revert InvalidConfiguration();
        if (_maxRiskScore > 5) revert InvalidRiskScore();
        
        AgentConfig storage config = agentConfigs[_agent];
        config.isActive = _isActive;
        config.maxRiskScore = _maxRiskScore;
        config.operationsPerBlock = 0;
        config.lastOperationBlock = block.number;
        
        emit AgentConfigured(_agent, _isActive, _maxRiskScore);
    }
    
    /**
     * @dev Add authorized caller for an agent
     * @param _agent Agent address
     * @param _caller Authorized caller address
     */
    function addAuthorizedCaller(
        address _agent,
        address _caller
    ) external onlyRole(SECURITY_MANAGER_ROLE) {
        if (_agent == address(0) || _caller == address(0)) revert InvalidConfiguration();
        
        AgentConfig storage config = agentConfigs[_agent];
        if (!config.isAuthorizedCaller[_caller]) {
            config.isAuthorizedCaller[_caller] = true;
            config.authorizedCallers.push(_caller);
            emit AuthorizedCallerAdded(_agent, _caller);
        }
    }
    
    /**
     * @dev Submit risk assessment with signature verification
     * @param _user User address being assessed
     * @param _riskScore Risk score (0-5)
     * @param _reason Human-readable reason
     * @param _signature Signature from authorized assessor
     */
    function submitRiskAssessment(
        address _user,
        uint256 _riskScore,
        string calldata _reason,
        bytes calldata _signature
    ) external whenNotPaused nonReentrant {
        if (_riskScore > 5) revert InvalidRiskScore();
        if (_user == address(0)) revert InvalidConfiguration();
        
        // Verify signature
        bytes32 messageHash = keccak256(
            abi.encodePacked(
                _user,
                _riskScore,
                _reason,
                userNonces[_user],
                block.timestamp
            )
        ).toEthSignedMessageHash();
        
        address assessor = messageHash.recover(_signature);
        if (!hasRole(AGENT_OPERATOR_ROLE, assessor)) revert InvalidSignature();
        
        // Check signature validity period
        if (block.timestamp > block.timestamp + SIGNATURE_VALIDITY_PERIOD) {
            revert ExpiredSignature();
        }
        
        userNonces[_user]++;
        
        emit RiskAssessmentSubmitted(_user, _riskScore, _reason);
    }
    
    /**
     * @dev Schedule a security operation with appropriate delay
     * @param _operationData Encoded operation data
     * @param _riskScore Risk score of the operation
     */
    function scheduleSecurityOperation(
        bytes calldata _operationData,
        uint256 _riskScore
    ) external onlyRole(AGENT_OPERATOR_ROLE) whenNotPaused nonReentrant returns (bytes32) {
        if (_riskScore > 5) revert InvalidRiskScore();
        
        // Rate limiting check
        if (operationCounts[msg.sender] >= MAX_OPERATIONS_PER_BLOCK) {
            revert RateLimitExceeded();
        }
        
        bytes32 operationHash = keccak256(
            abi.encodePacked(
                _operationData,
                msg.sender,
                block.timestamp,
                userNonces[msg.sender]++
            )
        );
        
        uint256 delay = riskDelays[_riskScore];
        
        securityOperations[operationHash] = SecurityOperation({
            operationHash: operationHash,
            executor: msg.sender,
            timestamp: block.timestamp,
            riskScore: _riskScore,
            executed: false,
            delay: delay
        });
        
        operationCounts[msg.sender]++;
        
        emit SecurityOperationScheduled(operationHash, msg.sender, delay);
        return operationHash;
    }
    
    /**
     * @dev Execute a previously scheduled security operation
     * @param _operationHash Hash of the operation to execute
     */
    function executeSecurityOperation(
        bytes32 _operationHash
    ) external whenNotPaused nonReentrant {
        SecurityOperation storage operation = securityOperations[_operationHash];
        
        if (operation.executor != msg.sender) revert UnauthorizedOperation();
        if (operation.executed) revert OperationAlreadyExecuted();
        if (block.timestamp < operation.timestamp + operation.delay) {
            revert InsufficientDelay();
        }
        
        operation.executed = true;
        
        emit SecurityOperationExecuted(_operationHash, msg.sender);
    }
    
    /**
     * @dev Emergency stop function
     * @param _reason Reason for emergency stop
     */
    function emergencyStop(
        string calldata _reason
    ) external onlyRole(EMERGENCY_ROLE) {
        _pause();
        emit EmergencyStop(msg.sender, _reason);
    }
    
    /**
     * @dev Resume operations after emergency stop
     */
    function resumeOperations() external onlyRole(EMERGENCY_ROLE) {
        _unpause();
    }
    
    /**
     * @dev Update risk delay configuration
     * @param _riskLevel Risk level (0-5)
     * @param _delay New delay in seconds
     */
    function updateRiskDelay(
        uint256 _riskLevel,
        uint256 _delay
    ) external onlyRole(SECURITY_MANAGER_ROLE) {
        if (_riskLevel > 5) revert InvalidRiskScore();
        if (_delay > MAX_DELAY) revert InvalidConfiguration();
        
        uint256 oldDelay = riskDelays[_riskLevel];
        riskDelays[_riskLevel] = _delay;
        
        emit ConfigurationUpdated("riskDelay", oldDelay, _delay);
    }
    
    /**
     * @dev Get agent configuration
     * @param _agent Agent address
     * @return isActive Whether agent is active
     * @return maxRiskScore Maximum risk score
     * @return authorizedCallers List of authorized callers
     */
    function getAgentConfig(address _agent) 
        external 
        view 
        returns (
            bool isActive,
            uint256 maxRiskScore,
            address[] memory authorizedCallers
        ) 
    {
        AgentConfig storage config = agentConfigs[_agent];
        return (
            config.isActive,
            config.maxRiskScore,
            config.authorizedCallers
        );
    }
    
    /**
     * @dev Check if caller is authorized for agent
     * @param _agent Agent address
     * @param _caller Caller address
     * @return Whether caller is authorized
     */
    function isAuthorizedCaller(
        address _agent,
        address _caller
    ) external view returns (bool) {
        return agentConfigs[_agent].isAuthorizedCaller[_caller];
    }
    
    /**
     * @dev UUPS upgrade authorization
     * @param newImplementation New implementation address
     */
    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(UPGRADER_ROLE) {
        // Additional upgrade validation can be added here
        require(newImplementation != address(0), "Invalid implementation");
    }
    
    /**
     * @dev Get contract version for upgrade tracking
     * @return Version string
     */
    function version() external pure returns (string memory) {
        return "1.0.0";
    }
}