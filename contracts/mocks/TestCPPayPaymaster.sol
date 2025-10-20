// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../CPPayPaymaster.sol";

/// @dev Testing harness exposing internal hooks for unit and fork testing.
contract TestCPPayPaymaster is CPPayPaymaster {
    constructor(IEntryPoint entryPoint_) CPPayPaymaster(entryPoint_) {}

    function exposedValidate(
        UserOperation calldata userOp,
        uint256 maxCost
    ) external returns (bytes memory context, uint256 validationData) {
        return _validatePaymasterUserOp(userOp, bytes32(0), maxCost);
    }

    function exposedPostOp(bytes calldata context, uint256 actualGasCost) external {
        _postOp(PostOpMode.opSucceeded, context, actualGasCost);
    }
}