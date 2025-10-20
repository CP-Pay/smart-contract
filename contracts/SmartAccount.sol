// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@account-abstraction/contracts/core/BaseAccount.sol";
import "@account-abstraction/contracts/interfaces/IEntryPoint.sol";
import "@account-abstraction/contracts/interfaces/UserOperation.sol";
import "@account-abstraction/contracts/core/Helpers.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/// @notice Modular smart account supporting owner, guardians, and scoped session keys.
contract SmartAccount is BaseAccount {
    using ECDSA for bytes32;
    using Address for address;

    /// @dev EntryPoint contract used for validations and execution.
    IEntryPoint private immutable _entryPoint;

    /// @dev Primary owner controlling the account.
    address private _owner;

    /// @dev Owner channel identifier for nonce separation.
    uint192 private constant OWNER_NONCE_KEY = 0;

    /// @dev Guardian approvals for social recovery.
    mapping(address => bool) public guardians;
    uint256 public guardianCount;
    uint256 public guardianThreshold;
    uint256 public recoveryNonce;

    /// @dev Authorized modules allowed to execute via `executeModule`.
    mapping(address => bool) public modules;

    struct SessionKey {
        address key;
        uint48 validAfter;
        uint48 validUntil;
        uint128 spendLimitWei;
        bytes32 scope;
        bool active;
    }

    /// @dev Session key definitions keyed by packed identifier.
    mapping(bytes32 => SessionKey) private _sessionKeys;
    /// @dev Tracks cumulative spend per session key (reset policy handled off-chain if required).
    mapping(bytes32 => uint256) public sessionUsage;
    /// @dev Selector allowlist per session key.
    mapping(bytes32 => mapping(bytes4 => bool)) private _sessionSelectorAllowed;
    mapping(bytes32 => bool) private _sessionHasRestrictions;

    /// @dev Emitted once during deployment.
    event SmartAccountInitialized(address indexed owner, address indexed entryPoint);
    event OwnerChanged(address indexed previousOwner, address indexed newOwner);
    event GuardianAdded(address indexed guardian);
    event GuardianRemoved(address indexed guardian);
    event GuardianThresholdUpdated(uint256 newThreshold);
    event SessionKeyRegistered(bytes32 indexed keyId, address indexed key, bytes32 scope);
    event SessionKeyRevoked(bytes32 indexed keyId);
    event ModuleUpdated(address indexed module, bool allowed);

    modifier onlyOwner() {
        require(msg.sender == _owner, "SA: not owner");
        _;
    }

    modifier onlyEntryPointOrOwner() {
        require(msg.sender == address(_entryPoint) || msg.sender == _owner, "SA: not allowed");
        _;
    }

    constructor(IEntryPoint entryPoint_, address owner_) {
        require(address(entryPoint_) != address(0), "SA: invalid entrypoint");
        require(owner_ != address(0), "SA: invalid owner");
        _entryPoint = entryPoint_;
        _owner = owner_;
        guardianThreshold = 0;
        emit SmartAccountInitialized(owner_, address(entryPoint_));
    }

    /// @notice Returns the owner address.
    function owner() external view returns (address) {
        return _owner;
    }

    /// @inheritdoc BaseAccount
    function entryPoint() public view override returns (IEntryPoint) {
        return _entryPoint;
    }

    /// @notice Update owner, callable by current owner.
    function setOwner(address newOwner) external onlyOwner {
        require(newOwner != address(0), "SA: zero owner");
        address previous = _owner;
        _owner = newOwner;
        emit OwnerChanged(previous, newOwner);
    }

    /// @notice Add a guardian address.
    function addGuardian(address guardian) external onlyOwner {
        require(guardian != address(0), "SA: zero guardian");
        require(!guardians[guardian], "SA: guardian exists");
        guardians[guardian] = true;
        guardianCount += 1;
        emit GuardianAdded(guardian);
    }

    /// @notice Remove a guardian.
    function removeGuardian(address guardian) external onlyOwner {
        require(guardians[guardian], "SA: unknown guardian");
        delete guardians[guardian];
        guardianCount -= 1;
        emit GuardianRemoved(guardian);
    }

    /// @notice Update guardian approval threshold.
    function setGuardianThreshold(uint256 newThreshold) external onlyOwner {
        require(newThreshold <= guardianCount, "SA: threshold too high");
        guardianThreshold = newThreshold;
        emit GuardianThresholdUpdated(newThreshold);
    }

    /// @notice Guardian-assisted recovery using aggregated signatures.
    function recoverWithGuardians(
        address newOwner,
        uint256 nonce,
        uint256 deadline,
        bytes[] calldata signatures
    ) external {
        require(newOwner != address(0), "SA: zero owner");
        require(block.timestamp <= deadline, "SA: recovery expired");
        require(signatures.length >= guardianThreshold && guardianThreshold > 0, "SA: insufficient guardians");
        require(nonce == recoveryNonce, "SA: invalid nonce");

        bytes32 digest = keccak256(
            abi.encodePacked(address(this), "RECOVER", newOwner, nonce, deadline)
        ).toEthSignedMessageHash();

        address[] memory seen = new address[](signatures.length);
        for (uint256 i = 0; i < signatures.length; i++) {
            address signer = digest.recover(signatures[i]);
            require(guardians[signer], "SA: invalid guardian");
            for (uint256 j = 0; j < i; j++) {
                require(seen[j] != signer, "SA: duplicate guardian");
            }
            seen[i] = signer;
        }

        recoveryNonce += 1;
        address previous = _owner;
        _owner = newOwner;
        emit OwnerChanged(previous, newOwner);
    }

    struct SessionKeyConfig {
        address key;
        uint48 validAfter;
        uint48 validUntil;
        uint128 spendLimitWei;
        bytes32 scope;
        bytes4[] selectors;
    }

    /// @notice Register a session key with optional spend/selector restrictions.
    function registerSessionKey(SessionKeyConfig calldata config) external onlyOwner {
        require(config.key != address(0), "SA: zero session key");
        require(config.validUntil == 0 || config.validUntil > block.timestamp, "SA: invalid validity");

        bytes32 keyId = keccak256(abi.encodePacked(config.key, config.scope));

        SessionKey storage slot = _sessionKeys[keyId];
        slot.key = config.key;
        slot.validAfter = config.validAfter;
        slot.validUntil = config.validUntil;
        slot.spendLimitWei = config.spendLimitWei;
        slot.scope = config.scope;
        slot.active = true;

        // reset selector allowlist
        bytes4[] memory selectors = config.selectors;
        _sessionHasRestrictions[keyId] = selectors.length > 0;
        if (selectors.length > 0) {
            for (uint256 i = 0; i < selectors.length; i++) {
                _sessionSelectorAllowed[keyId][selectors[i]] = true;
            }
        }

        emit SessionKeyRegistered(keyId, config.key, config.scope);
    }

    /// @notice Revoke a previously registered session key.
    function revokeSessionKey(bytes32 keyId) external onlyOwner {
        SessionKey storage slot = _sessionKeys[keyId];
        require(slot.active, "SA: unknown session");
        slot.active = false;
        emit SessionKeyRevoked(keyId);
    }

    /// @notice Enable or disable module contracts for delegated execution.
    function setModule(address module, bool allowed) external onlyOwner {
        require(module != address(0), "SA: zero module");
        modules[module] = allowed;
        emit ModuleUpdated(module, allowed);
    }

    /// @notice Returns the EntryPoint nonce for a specific channel.
    function getAccountNonce(uint192 key) external view returns (uint256) {
        return _entryPoint.getNonce(address(this), key);
    }

    /// @notice Execute call to target contract (single).
    function execute(address target, uint256 value, bytes calldata data) external onlyEntryPointOrOwner {
        _call(target, value, data);
    }

    /// @notice Execute batch of calls.
    function executeBatch(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata data
    ) external onlyEntryPointOrOwner {
        require(targets.length == values.length, "SA: array mismatch");
        require(targets.length == data.length, "SA: array mismatch");
        for (uint256 i = 0; i < targets.length; i++) {
            _call(targets[i], values[i], data[i]);
        }
    }

    /// @notice Execute via approved module.
    function executeModule(address module, bytes calldata data) external onlyEntryPointOrOwner {
        require(modules[module], "SA: module disabled");
        (bool success, bytes memory returndata) = module.delegatecall(data);
        require(success, _getRevertMsg(returndata));
    }

    /// @inheritdoc BaseAccount
    function _validateSignature(UserOperation calldata userOp, bytes32 userOpHash)
        internal
        override
        returns (uint256)
    {
        (uint8 sigType, bytes memory sigData) = abi.decode(userOp.signature, (uint8, bytes));
        if (sigType == 0) {
            bool ok = _validateOwnerSignature(sigData, userOpHash, userOp.nonce);
            return ok ? 0 : SIG_VALIDATION_FAILED;
        }
        if (sigType == 1) {
            bool ok = _validateSessionSignature(sigData, userOpHash, userOp);
            return ok ? 0 : SIG_VALIDATION_FAILED;
        }
        return SIG_VALIDATION_FAILED;
    }

    /// @inheritdoc BaseAccount
    function _validateNonce(uint256 rawNonce) internal view override {
        uint192 key = uint192(rawNonce >> 64);
        if (key == OWNER_NONCE_KEY) {
            return;
        }
        bytes32 sessionId = bytes32(uint256(key));
        require(_sessionKeys[sessionId].active, "SA: unknown nonce key");
    }

    function _validateOwnerSignature(
        bytes memory signature,
        bytes32 userOpHash,
        uint256 nonce
    ) private view returns (bool) {
        bytes32 hash = userOpHash.toEthSignedMessageHash();
        address signer = hash.recover(signature);
        if (signer != _owner) {
            return false;
        }
        uint192 key = uint192(nonce >> 64);
        return key == OWNER_NONCE_KEY;
    }

    function _validateSessionSignature(
        bytes memory sigData,
        bytes32 userOpHash,
        UserOperation calldata userOp
    ) private returns (bool) {
        (bytes32 keyId, bytes memory signature) = abi.decode(sigData, (bytes32, bytes));
        SessionKey storage session = _sessionKeys[keyId];
        if (!session.active || session.key == address(0)) {
            return false;
        }
        if (session.validAfter != 0) {
            require(block.timestamp >= session.validAfter, "SA: session not active");
        }
        if (session.validUntil != 0) {
            require(block.timestamp <= session.validUntil, "SA: session expired");
        }

        bytes32 hash = userOpHash.toEthSignedMessageHash();
        address signer = hash.recover(signature);
        if (signer != session.key) {
            return false;
        }

        // enforce nonce channel derived from keyId
        uint192 channel = uint192(userOp.nonce >> 64);
        if (channel != uint192(uint256(keyId))) {
            return false;
        }

        // enforce selector restrictions and spend limits
        bytes4 selector = bytes4(userOp.callData[0:4]);
        if (_sessionHasRestrictions[keyId]) {
            require(_sessionSelectorAllowed[keyId][selector], "SA: selector denied");
        }

        uint256 totalValue = _extractCallValue(userOp.callData);
        if (session.spendLimitWei > 0) {
            uint256 used = sessionUsage[keyId];
            require(used + totalValue <= session.spendLimitWei, "SA: spend limit");
            sessionUsage[keyId] = used + totalValue;
        }
        return true;
    }

    function _extractCallValue(bytes calldata callData) private pure returns (uint256 totalValue) {
        bytes4 selector = bytes4(callData[0:4]);
        if (selector == this.execute.selector) {
            (, uint256 value, ) = abi.decode(callData[4:], (address, uint256, bytes));
            return value;
        }
        if (selector == this.executeBatch.selector) {
            (, uint256[] memory values, ) = abi.decode(callData[4:], (address[], uint256[], bytes[]));
            for (uint256 i = 0; i < values.length; i++) {
                totalValue += values[i];
            }
            return totalValue;
        }
        // default: operations without ETH value (e.g., module calls)
        return 0;
    }

    function _call(address target, uint256 value, bytes calldata data) private {
        require(target != address(0), "SA: zero target");
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        require(success, _getRevertMsg(returndata));
    }

    function _getRevertMsg(bytes memory returnData) private pure returns (string memory) {
        if (returnData.length < 68) {
            return "SA: call reverted";
        }
        assembly {
            returnData := add(returnData, 0x04)
        }
        return abi.decode(returnData, (string));
    }

    /// @notice Allow receiving native tokens.
    receive() external payable {}
}