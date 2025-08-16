// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title Echo3RiskAssessment
 * @dev Advanced risk assessment engine for DeFi transactions
 * @notice Provides comprehensive risk scoring for transactions, contracts, and addresses
 * 
 * Features:
 * - Multi-dimensional risk scoring
 * - Historical risk tracking
 * - Contract interaction analysis
 * - Address reputation system
 * - Automated threat detection
 * - Community-driven risk intelligence
 */
contract Echo3RiskAssessment is 
    Initializable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    // Role definitions
    bytes32 public constant RISK_ASSESSOR_ROLE = keccak256("RISK_ASSESSOR_ROLE");
    bytes32 public constant RISK_MANAGER_ROLE = keccak256("RISK_MANAGER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    
    // Risk categories and weights
    enum RiskCategory {
        CONTRACT_SECURITY,    // Smart contract vulnerabilities
        LIQUIDITY_RISK,      // Liquidity and rug pull risks
        GOVERNANCE_RISK,     // Governance and admin key risks
        MARKET_RISK,         // Price manipulation and volatility
        OPERATIONAL_RISK,    // Technical and operational issues
        REGULATORY_RISK      // Compliance and regulatory issues
    }
    
    struct RiskMetrics {
        uint256 contractSecurity;   // 0-100
        uint256 liquidityRisk;      // 0-100
        uint256 governanceRisk;     // 0-100
        uint256 marketRisk;         // 0-100
        uint256 operationalRisk;    // 0-100
        uint256 regulatoryRisk;     // 0-100
        uint256 overallScore;       // Weighted average
        uint256 confidence;         // Confidence level 0-100
        uint256 lastUpdated;
        address assessor;
    }
    
    struct TransactionRisk {
        address from;
        address to;
        address tokenContract;
        uint256 amount;
        bytes4 functionSelector;
        uint256 riskScore;
        string riskReason;
        uint256 timestamp;
        bool approved;
    }
    
    struct AddressReputation {
        uint256 trustScore;         // 0-100, higher is more trusted
        uint256 transactionCount;
        uint256 successfulTxs;
        uint256 flaggedTxs;
        uint256 lastActivity;
        bool isBlacklisted;
        bool isWhitelisted;
        string[] tags;              // Human-readable tags
    }
    
    struct ContractAnalysis {
        bool isVerified;
        bool hasProxy;
        bool hasTimelock;
        bool hasMultisig;
        uint256 adminKeyRisk;       // Risk from admin keys
        uint256 upgradeabilityRisk; // Risk from upgradeability
        string[] vulnerabilities;   // Known vulnerabilities
        uint256 auditScore;         // Audit quality score
        uint256 tvlRisk;           // Total Value Locked risk
    }
    
    // Storage mappings
    mapping(address => RiskMetrics) public addressRisks;
    mapping(address => AddressReputation) public addressReputations;
    mapping(address => ContractAnalysis) public contractAnalyses;
    mapping(bytes32 => TransactionRisk) public transactionRisks;
    mapping(address => uint256[]) public addressRiskHistory;
    
    // Risk assessment weights (adjustable by governance)
    mapping(RiskCategory => uint256) public riskWeights;
    
    // Blacklist and whitelist management
    mapping(address => bool) public blacklistedAddresses;
    mapping(address => bool) public whitelistedAddresses;
    mapping(address => string) public blacklistReasons;
    
    // Events
    event RiskAssessmentUpdated(
        address indexed target,
        uint256 overallScore,
        uint256 confidence,
        address indexed assessor
    );
    event TransactionRiskEvaluated(
        bytes32 indexed txHash,
        address indexed from,
        address indexed to,
        uint256 riskScore
    );
    event AddressBlacklisted(address indexed target, string reason);
    event AddressWhitelisted(address indexed target, string reason);
    event ContractAnalysisUpdated(address indexed contract_, uint256 auditScore);
    event RiskWeightUpdated(RiskCategory category, uint256 oldWeight, uint256 newWeight);
    
    // Custom errors
    error InvalidRiskScore();
    error UnauthorizedAssessor();
    error AddressAlreadyBlacklisted();
    error AddressNotBlacklisted();
    error InvalidWeight();
    error EmptyReason();
    
    function initialize(address _admin) public initializer {
        __AccessControl_init();
        __Pausable_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();
        
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(RISK_MANAGER_ROLE, _admin);
        _grantRole(UPGRADER_ROLE, _admin);
        
        // Initialize default risk weights
        riskWeights[RiskCategory.CONTRACT_SECURITY] = 25;
        riskWeights[RiskCategory.LIQUIDITY_RISK] = 20;
        riskWeights[RiskCategory.GOVERNANCE_RISK] = 20;
        riskWeights[RiskCategory.MARKET_RISK] = 15;
        riskWeights[RiskCategory.OPERATIONAL_RISK] = 15;
        riskWeights[RiskCategory.REGULATORY_RISK] = 5;
    }
    
    /**
     * @dev Update comprehensive risk assessment for an address
     * @param _target Target address to assess
     * @param _contractSecurity Contract security score (0-100)
     * @param _liquidityRisk Liquidity risk score (0-100)
     * @param _governanceRisk Governance risk score (0-100)
     * @param _marketRisk Market risk score (0-100)
     * @param _operationalRisk Operational risk score (0-100)
     * @param _regulatoryRisk Regulatory risk score (0-100)
     * @param _confidence Confidence level in assessment (0-100)
     */
    function updateRiskAssessment(
        address _target,
        uint256 _contractSecurity,
        uint256 _liquidityRisk,
        uint256 _governanceRisk,
        uint256 _marketRisk,
        uint256 _operationalRisk,
        uint256 _regulatoryRisk,
        uint256 _confidence
    ) external onlyRole(RISK_ASSESSOR_ROLE) whenNotPaused {
        if (_target == address(0)) revert InvalidRiskScore();
        if (_contractSecurity > 100 || _liquidityRisk > 100 || _governanceRisk > 100 ||
            _marketRisk > 100 || _operationalRisk > 100 || _regulatoryRisk > 100 ||
            _confidence > 100) {
            revert InvalidRiskScore();
        }
        
        // Calculate weighted overall score
        uint256 overallScore = (
            _contractSecurity * riskWeights[RiskCategory.CONTRACT_SECURITY] +
            _liquidityRisk * riskWeights[RiskCategory.LIQUIDITY_RISK] +
            _governanceRisk * riskWeights[RiskCategory.GOVERNANCE_RISK] +
            _marketRisk * riskWeights[RiskCategory.MARKET_RISK] +
            _operationalRisk * riskWeights[RiskCategory.OPERATIONAL_RISK] +
            _regulatoryRisk * riskWeights[RiskCategory.REGULATORY_RISK]
        ) / 100;
        
        RiskMetrics storage metrics = addressRisks[_target];
        metrics.contractSecurity = _contractSecurity;
        metrics.liquidityRisk = _liquidityRisk;
        metrics.governanceRisk = _governanceRisk;
        metrics.marketRisk = _marketRisk;
        metrics.operationalRisk = _operationalRisk;
        metrics.regulatoryRisk = _regulatoryRisk;
        metrics.overallScore = overallScore;
        metrics.confidence = _confidence;
        metrics.lastUpdated = block.timestamp;
        metrics.assessor = msg.sender;
        
        // Store in history
        addressRiskHistory[_target].push(overallScore);
        
        emit RiskAssessmentUpdated(_target, overallScore, _confidence, msg.sender);
    }
    
    /**
     * @dev Evaluate transaction risk
     * @param _from Sender address
     * @param _to Recipient address
     * @param _tokenContract Token contract address
     * @param _amount Transaction amount
     * @param _functionSelector Function being called
     * @return riskScore Overall risk score (0-100)
     * @return riskReason Human-readable risk explanation
     */
    function evaluateTransactionRisk(
        address _from,
        address _to,
        address _tokenContract,
        uint256 _amount,
        bytes4 _functionSelector
    ) external view returns (uint256 riskScore, string memory riskReason) {
        // Check blacklist first
        if (blacklistedAddresses[_to] || blacklistedAddresses[_tokenContract]) {
            return (100, "Interacting with blacklisted address");
        }
        
        // Check whitelist for reduced risk
        if (whitelistedAddresses[_to] && whitelistedAddresses[_tokenContract]) {
            return (0, "Interacting with whitelisted addresses");
        }
        
        // Calculate composite risk score
        uint256 toRisk = addressRisks[_to].overallScore;
        uint256 tokenRisk = addressRisks[_tokenContract].overallScore;
        uint256 fromReputation = addressReputations[_from].trustScore;
        
        // Weight different risk factors
        riskScore = (toRisk * 40 + tokenRisk * 40 + (100 - fromReputation) * 20) / 100;
        
        // Adjust based on function selector risk
        if (_functionSelector == bytes4(keccak256("approve(address,uint256)"))) {
            riskScore += 10; // Approval operations are riskier
            riskReason = "Token approval operation with elevated risk";
        } else if (_functionSelector == bytes4(keccak256("transfer(address,uint256)"))) {
            riskReason = "Standard transfer operation";
        } else {
            riskScore += 5; // Unknown functions carry additional risk
            riskReason = "Unknown function call with moderate risk increase";
        }
        
        // Cap at 100
        if (riskScore > 100) riskScore = 100;
        
        // Provide more specific risk reason
        if (riskScore >= 80) {
            riskReason = "High risk: Multiple risk factors detected";
        } else if (riskScore >= 60) {
            riskReason = "Medium-high risk: Some concerning factors";
        } else if (riskScore >= 40) {
            riskReason = "Medium risk: Standard due diligence recommended";
        } else if (riskScore >= 20) {
            riskReason = "Low-medium risk: Generally safe with minor concerns";
        } else {
            riskReason = "Low risk: Transaction appears safe";
        }
    }
    
    /**
     * @dev Update contract analysis
     * @param _contract Contract address
     * @param _isVerified Whether contract is verified
     * @param _hasProxy Whether contract uses proxy pattern
     * @param _hasTimelock Whether contract has timelock
     * @param _hasMultisig Whether contract uses multisig
     * @param _auditScore Quality of security audits (0-100)
     */
    function updateContractAnalysis(
        address _contract,
        bool _isVerified,
        bool _hasProxy,
        bool _hasTimelock,
        bool _hasMultisig,
        uint256 _auditScore
    ) external onlyRole(RISK_ASSESSOR_ROLE) {
        if (_auditScore > 100) revert InvalidRiskScore();
        
        ContractAnalysis storage analysis = contractAnalyses[_contract];
        analysis.isVerified = _isVerified;
        analysis.hasProxy = _hasProxy;
        analysis.hasTimelock = _hasTimelock;
        analysis.hasMultisig = _hasMultisig;
        analysis.auditScore = _auditScore;
        
        // Calculate admin key risk
        uint256 adminRisk = 0;
        if (!_hasMultisig) adminRisk += 30;
        if (!_hasTimelock) adminRisk += 20;
        if (_hasProxy && !_hasTimelock) adminRisk += 25;
        analysis.adminKeyRisk = adminRisk > 100 ? 100 : adminRisk;
        
        // Calculate upgradeability risk
        analysis.upgradeabilityRisk = _hasProxy ? (_hasTimelock ? 20 : 60) : 0;
        
        emit ContractAnalysisUpdated(_contract, _auditScore);
    }
    
    /**
     * @dev Add address to blacklist
     * @param _address Address to blacklist
     * @param _reason Reason for blacklisting
     */
    function blacklistAddress(
        address _address,
        string calldata _reason
    ) external onlyRole(RISK_MANAGER_ROLE) {
        if (blacklistedAddresses[_address]) revert AddressAlreadyBlacklisted();
        if (bytes(_reason).length == 0) revert EmptyReason();
        
        blacklistedAddresses[_address] = true;
        blacklistReasons[_address] = _reason;
        
        emit AddressBlacklisted(_address, _reason);
    }
    
    /**
     * @dev Remove address from blacklist
     * @param _address Address to remove from blacklist
     */
    function removeFromBlacklist(
        address _address
    ) external onlyRole(RISK_MANAGER_ROLE) {
        if (!blacklistedAddresses[_address]) revert AddressNotBlacklisted();
        
        blacklistedAddresses[_address] = false;
        delete blacklistReasons[_address];
    }
    
    /**
     * @dev Add address to whitelist
     * @param _address Address to whitelist
     * @param _reason Reason for whitelisting
     */
    function whitelistAddress(
        address _address,
        string calldata _reason
    ) external onlyRole(RISK_MANAGER_ROLE) {
        whitelistedAddresses[_address] = true;
        emit AddressWhitelisted(_address, _reason);
    }
    
    /**
     * @dev Update risk category weights
     * @param _category Risk category to update
     * @param _weight New weight (total should sum to 100)
     */
    function updateRiskWeight(
        RiskCategory _category,
        uint256 _weight
    ) external onlyRole(RISK_MANAGER_ROLE) {
        if (_weight > 100) revert InvalidWeight();
        
        uint256 oldWeight = riskWeights[_category];
        riskWeights[_category] = _weight;
        
        emit RiskWeightUpdated(_category, oldWeight, _weight);
    }
    
    /**
     * @dev Get comprehensive risk information for an address
     * @param _address Address to query
     * @return metrics Risk metrics
     * @return reputation Address reputation
     * @return analysis Contract analysis (if applicable)
     */
    function getComprehensiveRisk(address _address) 
        external 
        view 
        returns (
            RiskMetrics memory metrics,
            AddressReputation memory reputation,
            ContractAnalysis memory analysis
        ) 
    {
        return (
            addressRisks[_address],
            addressReputations[_address],
            contractAnalyses[_address]
        );
    }
    
    /**
     * @dev Get risk history for an address
     * @param _address Address to query
     * @return Risk score history
     */
    function getRiskHistory(address _address) 
        external 
        view 
        returns (uint256[] memory) 
    {
        return addressRiskHistory[_address];
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