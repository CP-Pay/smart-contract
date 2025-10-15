// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interfaces/IAccount.sol";
import "../libraries/BatchLib.sol";
import "../libraries/LibDiamond.sol";
import "./ImportFacet.sol";

contract AccountFacet is IAccount {
    bytes32 constant ACCOUNT_STORAGE_POSITION = keccak256("cppay.account.storage");

    struct AccountStorage {
        address owner;
        address entryPoint;
        uint256 nonce;
        mapping(bytes32 => bool) executedOps;
        mapping(address => bool) approvedExecutors;
        bool locked; // Reentrancy guard
    }

    function accountStorage() internal pure returns (AccountStorage storage as_) {
        bytes32 position = ACCOUNT_STORAGE_POSITION;
        assembly {
            as_.slot := position
        }
    }

    event AccountInitialized(address indexed owner, address indexed entryPoint);
    event UserOperationExecuted(bytes32 indexed userOpHash, bool success, bytes returnData);
    event ExecutorApproved(address indexed executor, bool approved);
    event BatchExecuted(uint256 indexed batchId, bool[] results);

    error Unauthorized();
    error ReentrancyGuard();

    modifier nonReentrant() {
        AccountStorage storage as_ = accountStorage();
        if (as_.locked) revert ReentrancyGuard();
        as_.locked = true;
        _;
        as_.locked = false;
    }

    modifier onlyAuthorized() {
        AccountStorage storage as_ = accountStorage();
        if (msg.sender != as_.entryPoint && msg.sender != as_.owner && !as_.approvedExecutors[msg.sender]) {
            revert Unauthorized();
        }
        _;
    }

    function initialize(address _owner, address _entryPoint) external {
        AccountStorage storage as_ = accountStorage();
        require(as_.owner == address(0), "Already initialized");
        as_.owner = _owner;
        as_.entryPoint = _entryPoint;
        emit AccountInitialized(_owner, _entryPoint);
    }

    function validateUserOp(UserOperation calldata userOp, bytes32 userOpHash, uint256 missingAccountFunds)
        external
        override
        returns (uint256 validationData)
    {
        AccountStorage storage as_ = accountStorage();
        require(msg.sender == as_.entryPoint, "Account: not from EntryPoint");

        validationData = _validateSignature(userOp, userOpHash);

        if (missingAccountFunds > 0) {
            (bool success,) = payable(msg.sender).call{value: missingAccountFunds}("");
            require(success, "Account: failed to pay EntryPoint");
        }
    }

    function _validateSignature(UserOperation calldata userOp, bytes32 userOpHash)
        internal
        view
        returns (uint256 validationData)
    {
        AccountStorage storage as_ = accountStorage();

        bytes32 hash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", userOpHash));
        address signer = _recoverSigner(hash, userOp.signature);

        // Check if signer is owner or approved executor
        if (signer == as_.owner || as_.approvedExecutors[signer]) {
            return 0;
        }

        // Check if signer is imported address
        try ImportFacet(address(this)).isAuthorizedSigner(signer) returns (bool authorized) {
            if (authorized) return 0;
        } catch {
            // ImportFacet not installed or call failed, continue
        }

        return 1; // Invalid signature
    }

    function _recoverSigner(bytes32 hash, bytes memory signature) internal pure returns (address) {
        require(signature.length == 65, "Invalid signature length");

        bytes32 r;
        bytes32 s;
        uint8 v;

        assembly {
            r := mload(add(signature, 32))
            s := mload(add(signature, 64))
            v := byte(0, mload(add(signature, 96)))
        }

        return ecrecover(hash, v, r, s);
    }

    function execute(address dest, uint256 value, bytes calldata func) external onlyAuthorized nonReentrant {
        _call(dest, value, func);
    }

    function executeBatch(address[] calldata dest, uint256[] calldata value, bytes[] calldata func)
        external
        onlyAuthorized
        nonReentrant
    {
        require(dest.length == func.length && dest.length == value.length, "Account: wrong array lengths");

        for (uint256 i = 0; i < dest.length; i++) {
            _call(dest[i], value[i], func[i]);
        }
    }

    /**
     * @notice Execute batch atomically (all or nothing)
     * @param dest Array of destination addresses
     * @param value Array of values
     * @param func Array of function data
     */
    function executeBatchAtomic(address[] calldata dest, uint256[] calldata value, bytes[] calldata func)
        external
        onlyAuthorized
        nonReentrant
    {
        require(dest.length == func.length && dest.length == value.length, "Account: wrong array lengths");

        BatchLib.Call[] memory calls = new BatchLib.Call[](dest.length);
        for (uint256 i = 0; i < dest.length; i++) {
            calls[i] = BatchLib.Call({target: dest[i], value: value[i], data: func[i]});
        }

        BatchLib.executeAtomic(calls);
        emit BatchExecuted(block.number, new bool[](0));
    }

    /**
     * @notice Execute batch sequentially (continue on failure)
     * @param dest Array of destination addresses
     * @param value Array of values
     * @param func Array of function data
     * @return results Array of execution results
     */
    function executeBatchSequential(address[] calldata dest, uint256[] calldata value, bytes[] calldata func)
        external
        onlyAuthorized
        nonReentrant
        returns (bool[] memory results)
    {
        require(dest.length == func.length && dest.length == value.length, "Account: wrong array lengths");

        BatchLib.Call[] memory calls = new BatchLib.Call[](dest.length);
        for (uint256 i = 0; i < dest.length; i++) {
            calls[i] = BatchLib.Call({target: dest[i], value: value[i], data: func[i]});
        }

        results = BatchLib.executeSequential(calls);
        emit BatchExecuted(block.number, results);
    }

    function _call(address target, uint256 value, bytes memory data) internal {
        (bool success, bytes memory result) = target.call{value: value}(data);
        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
    }

    function setExecutor(address executor, bool approved) external {
        AccountStorage storage as_ = accountStorage();
        require(msg.sender == as_.owner, "Account: not owner");
        as_.approvedExecutors[executor] = approved;
        emit ExecutorApproved(executor, approved);
    }

    function accountOwner() external view returns (address) {
        return accountStorage().owner;
    }

    function getNonce() external view returns (uint256) {
        return accountStorage().nonce;
    }

    function isExecutor(address executor) external view returns (bool) {
        return accountStorage().approvedExecutors[executor];
    }
}
