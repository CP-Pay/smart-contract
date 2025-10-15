// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interfaces/IAccount.sol";

/**
 * @title MockEntryPoint
 * @notice Simplified EntryPoint for testing ERC-4337 flows
 */
contract MockEntryPoint {
    event UserOperationEvent(
        bytes32 indexed userOpHash,
        address indexed sender,
        address indexed paymaster,
        uint256 nonce,
        bool success,
        uint256 actualGasCost
    );

    mapping(address => uint256) public nonces;

    function handleOps(UserOperation[] calldata ops, address payable beneficiary) external {
        for (uint256 i = 0; i < ops.length; i++) {
            _handleOp(ops[i], beneficiary);
        }
    }

    function _handleOp(UserOperation calldata userOp, address payable beneficiary) internal {
        bytes32 userOpHash = getUserOpHash(userOp);

        // Validate with account
        uint256 validationData = IAccount(userOp.sender).validateUserOp(userOp, userOpHash, 0);

        require(validationData == 0, "EntryPoint: validation failed");

        // Execute the call
        (bool success,) = userOp.sender.call(userOp.callData);

        emit UserOperationEvent(userOpHash, userOp.sender, address(0), userOp.nonce, success, userOp.callGasLimit);

        // Pay beneficiary (simplified)
        if (address(this).balance > 0) {
            beneficiary.transfer(address(this).balance);
        }
    }

    function getUserOpHash(UserOperation calldata userOp) public pure returns (bytes32) {
        return keccak256(
            abi.encode(
                userOp.sender,
                userOp.nonce,
                keccak256(userOp.initCode),
                keccak256(userOp.callData),
                userOp.callGasLimit,
                userOp.verificationGasLimit,
                userOp.preVerificationGas,
                userOp.maxFeePerGas,
                userOp.maxPriorityFeePerGas,
                keccak256(userOp.paymasterAndData)
            )
        );
    }

    function getNonce(address sender, uint192) external view returns (uint256) {
        return nonces[sender];
    }

    function incrementNonce(address sender) external {
        nonces[sender]++;
    }

    receive() external payable {}
}
