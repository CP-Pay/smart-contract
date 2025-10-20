// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ICNGNToken is IERC20 {
    function mint(address to, uint256 amount) external;

    function burnFrom(address account, uint256 amount) external;
}

/**
 * @title NGNBridge
 * @notice Manages mint and burn flows for the cNGN stable token based on fiat settlement events.
 */
contract NGNBridge is AccessControl, Pausable, ReentrancyGuard {
    bytes32 public constant FIAT_CONTROLLER_ROLE = keccak256("FIAT_CONTROLLER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    uint64 private constant SECONDS_IN_DAY = 1 days;

    ICNGNToken public immutable cngnToken;

    uint256 public defaultDailyMintLimit;
    uint256 public defaultDailyBurnLimit;

    uint256 public maxMintPerTx;
    uint256 public maxBurnPerTx;

    struct AccountLimits {
        uint256 mintLimit;
        uint256 burnLimit;
        bool enabled;
    }

    struct DailyUsage {
        uint256 minted;
        uint256 burned;
        uint64 lastResetDay;
    }

    mapping(address => AccountLimits) private customLimits;
    mapping(address => DailyUsage) private usage;
    mapping(bytes32 => bool) public processedRefs;
    mapping(address => bool) public blockedAccounts;

    event Minted(address indexed beneficiary, uint256 amount, string ref, bytes32 metadataHash);
    event Burned(address indexed beneficiary, uint256 amount, string ref, bytes32 metadataHash);
    event AccountBlocked(address indexed account, bool blocked);
    event DailyLimitsUpdated(uint256 mintLimit, uint256 burnLimit);
    event PerTxLimitsUpdated(uint256 mintLimit, uint256 burnLimit);
    event AccountLimitsUpdated(address indexed account, uint256 mintLimit, uint256 burnLimit, bool enabled);

    constructor(address token, address admin) {
        require(token != address(0), "NGNB: token zero");
        require(admin != address(0), "NGNB: admin zero");

        cngnToken = ICNGNToken(token);
        defaultDailyMintLimit = type(uint256).max;
        defaultDailyBurnLimit = type(uint256).max;
        maxMintPerTx = type(uint256).max;
        maxBurnPerTx = type(uint256).max;

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(FIAT_CONTROLLER_ROLE, admin);
        _grantRole(PAUSER_ROLE, admin);
    }

    function mint(
        address beneficiary,
        uint256 amount,
        string calldata ref,
        bytes calldata metadata
    ) external nonReentrant whenNotPaused onlyRole(FIAT_CONTROLLER_ROLE) {
        _requireAccountActive(beneficiary);
        bytes32 refHash = _useReference(ref);

        require(amount > 0, "NGNB: zero amount");

        (uint256 mintLimit, ) = _effectiveLimits(beneficiary);
        require(amount <= maxMintPerTx, "NGNB: mint per-tx");

        DailyUsage storage record = _ensureDay(beneficiary);
        require(record.minted + amount <= mintLimit, "NGNB: mint daily");

        record.minted += amount;
        processedRefs[refHash] = true;
        cngnToken.mint(beneficiary, amount);

        emit Minted(beneficiary, amount, ref, keccak256(metadata));
    }

    function burn(
        address beneficiary,
        uint256 amount,
        string calldata ref,
        bytes calldata metadata
    ) external nonReentrant whenNotPaused onlyRole(FIAT_CONTROLLER_ROLE) {
        _requireAccountActive(beneficiary);
        bytes32 refHash = _useReference(ref);

        require(amount > 0, "NGNB: zero amount");

        (, uint256 burnLimit) = _effectiveLimits(beneficiary);
        require(amount <= maxBurnPerTx, "NGNB: burn per-tx");

        DailyUsage storage record = _ensureDay(beneficiary);
        require(record.burned + amount <= burnLimit, "NGNB: burn daily");

        record.burned += amount;
        processedRefs[refHash] = true;
        cngnToken.burnFrom(beneficiary, amount);

        emit Burned(beneficiary, amount, ref, keccak256(metadata));
    }

    function setDailyLimits(uint256 mintLimit, uint256 burnLimit) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(mintLimit > 0 && burnLimit > 0, "NGNB: zero limit");
        defaultDailyMintLimit = mintLimit;
        defaultDailyBurnLimit = burnLimit;
        emit DailyLimitsUpdated(mintLimit, burnLimit);
    }

    function setPerTxLimits(uint256 mintLimit, uint256 burnLimit) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(mintLimit > 0 && burnLimit > 0, "NGNB: zero limit");
        maxMintPerTx = mintLimit;
        maxBurnPerTx = burnLimit;
        emit PerTxLimitsUpdated(mintLimit, burnLimit);
    }

    function setAccountLimits(
        address account,
        uint256 mintLimit,
        uint256 burnLimit,
        bool enabled
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (enabled) {
            require(mintLimit > 0 && burnLimit > 0, "NGNB: zero limit");
            customLimits[account] = AccountLimits({mintLimit: mintLimit, burnLimit: burnLimit, enabled: true});
        } else {
            delete customLimits[account];
        }
        emit AccountLimitsUpdated(account, mintLimit, burnLimit, enabled);
    }

    function setBlocked(address account, bool blocked) external onlyRole(DEFAULT_ADMIN_ROLE) {
        blockedAccounts[account] = blocked;
        emit AccountBlocked(account, blocked);
    }

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function getDailyUsage(address account)
        external
        view
        returns (uint256 minted, uint256 burned, uint64 currentDay)
    {
        DailyUsage memory record = usage[account];
        (minted, burned) = (record.minted, record.burned);
        currentDay = record.lastResetDay;
    }

    function getAccountLimits(address account) external view returns (uint256 mintLimit, uint256 burnLimit) {
        (mintLimit, burnLimit) = _effectiveLimits(account);
    }

    function isReferenceProcessed(string calldata ref) external view returns (bool) {
        return processedRefs[_referenceKey(ref)];
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function _useReference(string calldata ref) private view returns (bytes32 refHash) {
        refHash = _referenceKey(ref);
        require(refHash != bytes32(0), "NGNB: ref empty");
        require(!processedRefs[refHash], "NGNB: ref used");
    }

    function _referenceKey(string calldata ref) private pure returns (bytes32) {
        return keccak256(bytes(ref));
    }

    function _effectiveLimits(address account) private view returns (uint256 mintLimit, uint256 burnLimit) {
        AccountLimits memory limits = customLimits[account];
        if (limits.enabled) {
            return (limits.mintLimit, limits.burnLimit);
        }
        return (defaultDailyMintLimit, defaultDailyBurnLimit);
    }

    function _ensureDay(address account) private returns (DailyUsage storage record) {
        record = usage[account];
        uint64 today = uint64(block.timestamp / SECONDS_IN_DAY);
        if (record.lastResetDay < today) {
            record.lastResetDay = today;
            record.minted = 0;
            record.burned = 0;
        }
    }

    function _requireAccountActive(address account) private view {
        require(!blockedAccounts[account], "NGNB: blocked");
    }
}