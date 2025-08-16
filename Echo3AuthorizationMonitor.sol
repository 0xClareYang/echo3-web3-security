// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title Echo3AuthorizationMonitor
 * @dev Advanced monitoring system for tracking and managing token approvals and delegations
 * @notice Monitors ERC20/ERC721/ERC1155 approvals and provides automated risk management
 * 
 * Features:
 * - Real-time approval tracking across multiple token standards
 * - Risk-based approval classification
 * - Automated revocation capabilities
 * - Historical approval analysis
 * - Integration with Echo3 risk assessment system
 * - Emergency approval revocation
 * - Batch operations for gas efficiency
 */
contract Echo3AuthorizationMonitor is 
    Initializable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    // Role definitions
    bytes32 public constant MONITOR_OPERATOR_ROLE = keccak256("MONITOR_OPERATOR_ROLE");
    bytes32 public constant RISK_MANAGER_ROLE = keccak256("RISK_MANAGER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
    
    // Token standards
    enum TokenStandard {
        ERC20,
        ERC721,
        ERC1155
    }
    
    // Approval risk levels
    enum RiskLevel {
        SAFE,           // 0 - Known safe contracts
        LOW,            // 1 - Low risk
        MEDIUM,         // 2 - Medium risk
        HIGH,           // 3 - High risk
        CRITICAL        // 4 - Critical risk - immediate action needed
    }
    
    struct ApprovalRecord {
        address owner;              // Address that granted approval
        address spender;            // Address that received approval
        address tokenContract;     // Token contract address
        TokenStandard standard;     // Token standard
        uint256 amount;            // Approved amount (for ERC20)
        uint256 tokenId;           // Token ID (for ERC721)
        bool isApprovedForAll;     // For ERC721/ERC1155 approveForAll
        uint256 timestamp;         // When approval was granted
        uint256 lastChecked;       // Last risk assessment time
        RiskLevel riskLevel;       // Current risk assessment
        bool isActive;             // Whether approval is still active
        bool revokedByUser;        // Whether user manually revoked
        bool revokedBySystem;      // Whether system auto-revoked
    }
    
    struct UserApprovalSummary {
        uint256 totalApprovals;
        uint256 activeApprovals;
        uint256 highRiskApprovals;
        uint256 lastReviewTime;
        address[] approvedContracts;
        mapping(address => bool) hasApprovalFor;
    }
    
    struct ContractRiskProfile {
        RiskLevel riskLevel;
        uint256 totalApprovals;
        uint256 revokedApprovals;
        uint256 lastIncident;
        string[] incidentReports;
        bool isBlacklisted;
        bool isWhitelisted;
        uint256 lastRiskUpdate;
    }
    
    // Storage
    mapping(bytes32 => ApprovalRecord) public approvalRecords;
    mapping(address => UserApprovalSummary) public userSummaries;
    mapping(address => ContractRiskProfile) public contractProfiles;
    mapping(address => bytes32[]) public userApprovals;
    mapping(address => bytes32[]) public contractApprovals;
    
    // Risk thresholds (adjustable by governance)
    mapping(RiskLevel => uint256) public riskThresholds;
    mapping(RiskLevel => uint256) public autoRevokeDelays;
    
    // Emergency settings
    bool public emergencyMode;
    mapping(address => bool) public emergencyBlacklist;
    
    // Events
    event ApprovalDetected(
        bytes32 indexed approvalId,
        address indexed owner,
        address indexed spender,
        address tokenContract,
        TokenStandard standard
    );
    event RiskLevelUpdated(
        bytes32 indexed approvalId,
        RiskLevel oldLevel,
        RiskLevel newLevel
    );
    event ApprovalRevoked(
        bytes32 indexed approvalId,
        address indexed owner,
        address indexed spender,
        bool automatic
    );
    event ContractBlacklisted(
        address indexed contract_,
        string reason,
        uint256 affectedApprovals
    );
    event EmergencyModeActivated(address indexed activator, string reason);
    event BatchRevocationExecuted(
        address indexed user,
        uint256 revokedCount,
        RiskLevel minimumRisk
    );
    
    // Custom errors
    error InvalidApprovalId();
    error UnauthorizedRevocation();
    error ApprovalAlreadyRevoked();
    error InvalidRiskLevel();
    error EmergencyModeActive();
    error ContractAlreadyBlacklisted();
    
    function initialize(address _admin) public initializer {
        __AccessControl_init();
        __Pausable_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();
        
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(RISK_MANAGER_ROLE, _admin);
        _grantRole(UPGRADER_ROLE, _admin);
        _grantRole(EMERGENCY_ROLE, _admin);
        
        // Initialize risk thresholds (0-100 scale)
        riskThresholds[RiskLevel.SAFE] = 10;
        riskThresholds[RiskLevel.LOW] = 25;
        riskThresholds[RiskLevel.MEDIUM] = 50;
        riskThresholds[RiskLevel.HIGH] = 75;
        riskThresholds[RiskLevel.CRITICAL] = 90;
        
        // Initialize auto-revoke delays (in seconds)
        autoRevokeDelays[RiskLevel.SAFE] = 0;           // No auto-revoke
        autoRevokeDelays[RiskLevel.LOW] = 0;            // No auto-revoke
        autoRevokeDelays[RiskLevel.MEDIUM] = 7 days;    // 7 days warning
        autoRevokeDelays[RiskLevel.HIGH] = 24 hours;    // 24 hours warning
        autoRevokeDelays[RiskLevel.CRITICAL] = 1 hours; // 1 hour warning
    }
    
    /**
     * @dev Record a new approval detected on-chain
     * @param _owner Address that granted the approval
     * @param _spender Address that received the approval
     * @param _tokenContract Token contract address
     * @param _standard Token standard
     * @param _amount Amount approved (for ERC20)
     * @param _tokenId Token ID (for ERC721)
     * @param _isApprovedForAll Whether it's an approveForAll operation
     */
    function recordApproval(
        address _owner,
        address _spender,
        address _tokenContract,
        TokenStandard _standard,
        uint256 _amount,
        uint256 _tokenId,
        bool _isApprovedForAll
    ) external onlyRole(MONITOR_OPERATOR_ROLE) whenNotPaused {
        bytes32 approvalId = keccak256(
            abi.encodePacked(
                _owner,
                _spender,
                _tokenContract,
                _standard,
                _amount,
                _tokenId,
                _isApprovedForAll,
                block.timestamp
            )
        );
        
        ApprovalRecord storage record = approvalRecords[approvalId];
        record.owner = _owner;
        record.spender = _spender;
        record.tokenContract = _tokenContract;
        record.standard = _standard;
        record.amount = _amount;
        record.tokenId = _tokenId;
        record.isApprovedForAll = _isApprovedForAll;
        record.timestamp = block.timestamp;
        record.lastChecked = block.timestamp;
        record.isActive = true;
        
        // Initial risk assessment
        record.riskLevel = _assessInitialRisk(_spender, _tokenContract);
        
        // Update user summary
        UserApprovalSummary storage userSummary = userSummaries[_owner];
        userSummary.totalApprovals++;
        userSummary.activeApprovals++;
        if (record.riskLevel >= RiskLevel.HIGH) {
            userSummary.highRiskApprovals++;
        }
        
        if (!userSummary.hasApprovalFor[_spender]) {
            userSummary.hasApprovalFor[_spender] = true;
            userSummary.approvedContracts.push(_spender);
        }
        
        // Update contract profile
        ContractRiskProfile storage profile = contractProfiles[_spender];
        profile.totalApprovals++;
        
        // Store references
        userApprovals[_owner].push(approvalId);
        contractApprovals[_spender].push(approvalId);
        
        emit ApprovalDetected(
            approvalId,
            _owner,
            _spender,
            _tokenContract,
            _standard
        );
    }
    
    /**
     * @dev Update risk level for an approval
     * @param _approvalId Approval ID to update
     * @param _newRiskLevel New risk level
     * @param _reason Reason for risk level change
     */
    function updateApprovalRisk(
        bytes32 _approvalId,
        RiskLevel _newRiskLevel,
        string calldata _reason
    ) external onlyRole(RISK_MANAGER_ROLE) {
        ApprovalRecord storage record = approvalRecords[_approvalId];
        if (record.owner == address(0)) revert InvalidApprovalId();
        
        RiskLevel oldLevel = record.riskLevel;
        record.riskLevel = _newRiskLevel;
        record.lastChecked = block.timestamp;
        
        // Update user summary if risk changed
        if (oldLevel != _newRiskLevel) {
            UserApprovalSummary storage userSummary = userSummaries[record.owner];
            
            if (oldLevel >= RiskLevel.HIGH && _newRiskLevel < RiskLevel.HIGH) {
                userSummary.highRiskApprovals--;
            } else if (oldLevel < RiskLevel.HIGH && _newRiskLevel >= RiskLevel.HIGH) {
                userSummary.highRiskApprovals++;
            }
        }
        
        emit RiskLevelUpdated(_approvalId, oldLevel, _newRiskLevel);
    }
    
    /**
     * @dev Revoke an approval (can be called by user or system)
     * @param _approvalId Approval ID to revoke
     * @param _automatic Whether this is an automatic system revocation
     */
    function revokeApproval(
        bytes32 _approvalId,
        bool _automatic
    ) external nonReentrant {
        ApprovalRecord storage record = approvalRecords[_approvalId];
        if (record.owner == address(0)) revert InvalidApprovalId();
        if (!record.isActive) revert ApprovalAlreadyRevoked();
        
        // Authorization check
        if (!_automatic && msg.sender != record.owner) {
            if (!hasRole(RISK_MANAGER_ROLE, msg.sender)) {
                revert UnauthorizedRevocation();
            }
        }
        
        // Mark as revoked
        record.isActive = false;
        if (_automatic) {
            record.revokedBySystem = true;
        } else {
            record.revokedByUser = true;
        }
        
        // Update user summary
        UserApprovalSummary storage userSummary = userSummaries[record.owner];
        userSummary.activeApprovals--;
        if (record.riskLevel >= RiskLevel.HIGH) {
            userSummary.highRiskApprovals--;
        }
        
        // Update contract profile
        contractProfiles[record.spender].revokedApprovals++;
        
        emit ApprovalRevoked(_approvalId, record.owner, record.spender, _automatic);
    }
    
    /**
     * @dev Batch revoke approvals for a user based on risk level
     * @param _user User address
     * @param _minimumRiskLevel Minimum risk level to revoke
     */
    function batchRevokeByRisk(
        address _user,
        RiskLevel _minimumRiskLevel
    ) external {
        if (msg.sender != _user && !hasRole(RISK_MANAGER_ROLE, msg.sender)) {
            revert UnauthorizedRevocation();
        }
        
        bytes32[] memory userApprovalList = userApprovals[_user];
        uint256 revokedCount = 0;
        
        for (uint256 i = 0; i < userApprovalList.length; i++) {
            bytes32 approvalId = userApprovalList[i];
            ApprovalRecord storage record = approvalRecords[approvalId];
            
            if (record.isActive && record.riskLevel >= _minimumRiskLevel) {
                record.isActive = false;
                record.revokedByUser = true;
                revokedCount++;
                
                emit ApprovalRevoked(approvalId, _user, record.spender, false);
            }
        }
        
        // Update user summary
        UserApprovalSummary storage userSummary = userSummaries[_user];
        userSummary.activeApprovals -= revokedCount;
        userSummary.lastReviewTime = block.timestamp;
        
        emit BatchRevocationExecuted(_user, revokedCount, _minimumRiskLevel);
    }
    
    /**
     * @dev Blacklist a contract and revoke all approvals
     * @param _contract Contract to blacklist
     * @param _reason Reason for blacklisting
     */
    function blacklistContract(
        address _contract,
        string calldata _reason
    ) external onlyRole(RISK_MANAGER_ROLE) {
        if (contractProfiles[_contract].isBlacklisted) {
            revert ContractAlreadyBlacklisted();
        }
        
        contractProfiles[_contract].isBlacklisted = true;
        contractProfiles[_contract].lastIncident = block.timestamp;
        contractProfiles[_contract].incidentReports.push(_reason);
        
        // Auto-revoke all active approvals for this contract
        bytes32[] memory contractApprovalList = contractApprovals[_contract];
        uint256 affectedCount = 0;
        
        for (uint256 i = 0; i < contractApprovalList.length; i++) {
            bytes32 approvalId = contractApprovalList[i];
            ApprovalRecord storage record = approvalRecords[approvalId];
            
            if (record.isActive) {
                record.isActive = false;
                record.revokedBySystem = true;
                record.riskLevel = RiskLevel.CRITICAL;
                affectedCount++;
                
                // Update user summary
                userSummaries[record.owner].activeApprovals--;
                if (record.riskLevel >= RiskLevel.HIGH) {
                    userSummaries[record.owner].highRiskApprovals--;
                }
                
                emit ApprovalRevoked(approvalId, record.owner, _contract, true);
            }
        }
        
        emit ContractBlacklisted(_contract, _reason, affectedCount);
    }
    
    /**
     * @dev Activate emergency mode - pauses all operations except revocations
     * @param _reason Reason for emergency activation
     */
    function activateEmergencyMode(
        string calldata _reason
    ) external onlyRole(EMERGENCY_ROLE) {
        emergencyMode = true;
        _pause();
        
        emit EmergencyModeActivated(msg.sender, _reason);
    }
    
    /**
     * @dev Deactivate emergency mode
     */
    function deactivateEmergencyMode() external onlyRole(EMERGENCY_ROLE) {
        emergencyMode = false;
        _unpause();
    }
    
    /**
     * @dev Get all active approvals for a user
     * @param _user User address
     * @return approvalIds Array of active approval IDs
     */
    function getUserActiveApprovals(address _user) 
        external 
        view 
        returns (bytes32[] memory approvalIds) 
    {
        bytes32[] memory allApprovals = userApprovals[_user];
        uint256 activeCount = 0;
        
        // Count active approvals
        for (uint256 i = 0; i < allApprovals.length; i++) {
            if (approvalRecords[allApprovals[i]].isActive) {
                activeCount++;
            }
        }
        
        // Build result array
        approvalIds = new bytes32[](activeCount);
        uint256 index = 0;
        for (uint256 i = 0; i < allApprovals.length; i++) {
            if (approvalRecords[allApprovals[i]].isActive) {
                approvalIds[index] = allApprovals[i];
                index++;
            }
        }
    }
    
    /**
     * @dev Get user approval summary
     * @param _user User address
     * @return summary User approval summary
     */
    function getUserSummary(address _user) 
        external 
        view 
        returns (
            uint256 totalApprovals,
            uint256 activeApprovals,
            uint256 highRiskApprovals,
            uint256 lastReviewTime,
            address[] memory approvedContracts
        ) 
    {
        UserApprovalSummary storage summary = userSummaries[_user];
        return (
            summary.totalApprovals,
            summary.activeApprovals,
            summary.highRiskApprovals,
            summary.lastReviewTime,
            summary.approvedContracts
        );
    }
    
    /**
     * @dev Internal function to assess initial risk
     * @param _spender Spender address
     * @param _tokenContract Token contract address
     * @return Initial risk level
     */
    function _assessInitialRisk(
        address _spender,
        address _tokenContract
    ) internal view returns (RiskLevel) {
        ContractRiskProfile storage profile = contractProfiles[_spender];
        
        if (profile.isBlacklisted) {
            return RiskLevel.CRITICAL;
        }
        
        if (profile.isWhitelisted) {
            return RiskLevel.SAFE;
        }
        
        // Default to medium risk for unknown contracts
        return RiskLevel.MEDIUM;
    }
    
    /**
     * @dev UUPS upgrade authorization
     * @param newImplementation New implementation address
     */
    function _authorizeUpgrade(address newImplementation) 
        internal 
        override 
        onlyRole(UPGRADER_ROLE) 
    {
        require(newImplementation != address(0), "Invalid implementation");
    }
    
    /**
     * @dev Get contract version
     * @return Version string
     */
    function version() external pure returns (string memory) {
        return "1.0.0";
    }
}