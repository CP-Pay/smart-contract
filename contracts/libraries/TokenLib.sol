// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title TokenLib
 * @notice Safe ERC20 token transfer helpers
 * @dev Handles non-standard ERC20 returns and edge cases
 */
library TokenLib {
    error TransferFailed();
    error ApproveFailed();
    error InsufficientAllowance();

    /**
     * @notice Safely transfer tokens from one address to another
     * @param token The token address
     * @param from The sender address
     * @param to The recipient address
     * @param amount The amount to transfer
     */
    function safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) =
            token.call(abi.encodeWithSignature("transferFrom(address,address,uint256)", from, to, amount));

        if (!success || (data.length > 0 && !abi.decode(data, (bool)))) {
            revert TransferFailed();
        }
    }

    /**
     * @notice Safely transfer tokens to an address
     * @param token The token address
     * @param to The recipient address
     * @param amount The amount to transfer
     */
    function safeTransfer(address token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(abi.encodeWithSignature("transfer(address,uint256)", to, amount));

        if (!success || (data.length > 0 && !abi.decode(data, (bool)))) {
            revert TransferFailed();
        }
    }

    /**
     * @notice Safely approve token spending
     * @dev Resets to 0 first to prevent race conditions
     * @param token The token address
     * @param spender The spender address
     * @param amount The amount to approve
     */
    function safeApprove(address token, address spender, uint256 amount) internal {
        // Reset to 0 first
        (bool success, bytes memory data) = token.call(abi.encodeWithSignature("approve(address,uint256)", spender, 0));

        if (!success || (data.length > 0 && !abi.decode(data, (bool)))) {
            revert ApproveFailed();
        }

        // Set new allowance
        (success, data) = token.call(abi.encodeWithSignature("approve(address,uint256)", spender, amount));

        if (!success || (data.length > 0 && !abi.decode(data, (bool)))) {
            revert ApproveFailed();
        }
    }

    /**
     * @notice Get token balance of an address
     * @param token The token address
     * @param account The account to check
     * @return balance The token balance
     */
    function balanceOf(address token, address account) internal view returns (uint256 balance) {
        (bool success, bytes memory data) = token.staticcall(abi.encodeWithSignature("balanceOf(address)", account));

        require(success && data.length >= 32, "TokenLib: balanceOf failed");
        balance = abi.decode(data, (uint256));
    }

    /**
     * @notice Get token allowance
     * @param token The token address
     * @param owner The owner address
     * @param spender The spender address
     * @return allowance_ The current allowance
     */
    function allowance(address token, address owner, address spender) internal view returns (uint256 allowance_) {
        (bool success, bytes memory data) =
            token.staticcall(abi.encodeWithSignature("allowance(address,address)", owner, spender));

        require(success && data.length >= 32, "TokenLib: allowance failed");
        allowance_ = abi.decode(data, (uint256));
    }
}
