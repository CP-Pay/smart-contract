// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../libraries/LibAppStorage.sol";
import "../libraries/TokenLib.sol";
import "../libraries/LibDiamond.sol";

/**
 * @title SwapFacet
 * @notice Handles on-chain DEX swaps via AMM routers
 * @dev Integrates with Uniswap V2/V3 style routers on Lisk L2
 */
contract SwapFacet {
    using TokenLib for address;

    error SwapFailed();
    error SlippageExceeded();
    error InvalidPath();
    error InvalidRouter();

    event SwapExecuted(
        address indexed user,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        address router
    );

    /**
     * @notice Swap exact tokens for tokens via DEX router
     * @param router The DEX router address
     * @param path The swap path (tokenIn -> ... -> tokenOut)
     * @param amountIn The input amount
     * @param amountOutMin The minimum output amount (slippage protection)
     * @param to The recipient address
     * @return amountOut The actual output amount
     */
    function swapExactTokensForTokens(
        address router,
        address[] calldata path,
        uint256 amountIn,
        uint256 amountOutMin,
        address to
    ) external returns (uint256 amountOut) {
        if (router == address(0)) revert InvalidRouter();
        if (path.length < 2) revert InvalidPath();
        if (amountIn == 0) revert SwapFailed();

        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();

        // Verify supported tokens
        if (!s.isSupportedToken[path[0]]) {
            revert LibAppStorage.UnsupportedToken(path[0]);
        }
        if (!s.isSupportedToken[path[path.length - 1]]) {
            revert LibAppStorage.UnsupportedToken(path[path.length - 1]);
        }

        // Check balance
        uint256 balance = path[0].balanceOf(address(this));
        if (balance < amountIn) {
            revert LibAppStorage.InsufficientBalance(path[0], amountIn, balance);
        }

        // Approve router
        path[0].safeApprove(router, amountIn);

        // Execute swap
        (bool success, bytes memory data) = router.call(
            abi.encodeWithSignature(
                "swapExactTokensForTokens(uint256,uint256,address[],address,uint256)",
                amountIn,
                amountOutMin,
                path,
                to,
                block.timestamp
            )
        );

        if (!success) revert SwapFailed();

        // Decode amounts array - last element is amountOut
        uint256[] memory amounts = abi.decode(data, (uint256[]));
        amountOut = amounts[amounts.length - 1];

        if (amountOut < amountOutMin) revert SlippageExceeded();

        emit SwapExecuted(msg.sender, path[0], path[path.length - 1], amountIn, amountOut, router);
    }

    /**
     * @notice Swap exact native tokens for tokens
     * @param router The DEX router address
     * @param path The swap path (WETH -> ... -> tokenOut)
     * @param amountOutMin The minimum output amount
     * @param to The recipient address
     * @return amountOut The actual output amount
     */
    function swapExactNativeForTokens(address router, address[] calldata path, uint256 amountOutMin, address to)
        external
        payable
        returns (uint256 amountOut)
    {
        if (router == address(0)) revert InvalidRouter();
        if (path.length < 2) revert InvalidPath();
        if (msg.value == 0) revert SwapFailed();

        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();

        if (!s.isSupportedToken[path[path.length - 1]]) {
            revert LibAppStorage.UnsupportedToken(path[path.length - 1]);
        }

        // Execute swap
        (bool success, bytes memory data) = router.call{value: msg.value}(
            abi.encodeWithSignature(
                "swapExactETHForTokens(uint256,address[],address,uint256)", amountOutMin, path, to, block.timestamp
            )
        );

        if (!success) revert SwapFailed();

        uint256[] memory amounts = abi.decode(data, (uint256[]));
        amountOut = amounts[amounts.length - 1];

        if (amountOut < amountOutMin) revert SlippageExceeded();

        emit SwapExecuted(msg.sender, address(0), path[path.length - 1], msg.value, amountOut, router);
    }

    /**
     * @notice Swap exact tokens for native tokens
     * @param router The DEX router address
     * @param path The swap path (tokenIn -> ... -> WETH)
     * @param amountIn The input amount
     * @param amountOutMin The minimum output amount
     * @param to The recipient address
     * @return amountOut The actual output amount
     */
    function swapExactTokensForNative(
        address router,
        address[] calldata path,
        uint256 amountIn,
        uint256 amountOutMin,
        address to
    ) external returns (uint256 amountOut) {
        if (router == address(0)) revert InvalidRouter();
        if (path.length < 2) revert InvalidPath();
        if (amountIn == 0) revert SwapFailed();

        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();

        if (!s.isSupportedToken[path[0]]) {
            revert LibAppStorage.UnsupportedToken(path[0]);
        }

        uint256 balance = path[0].balanceOf(address(this));
        if (balance < amountIn) {
            revert LibAppStorage.InsufficientBalance(path[0], amountIn, balance);
        }

        // Approve router
        path[0].safeApprove(router, amountIn);

        // Execute swap
        (bool success, bytes memory data) = router.call(
            abi.encodeWithSignature(
                "swapExactTokensForETH(uint256,uint256,address[],address,uint256)",
                amountIn,
                amountOutMin,
                path,
                to,
                block.timestamp
            )
        );

        if (!success) revert SwapFailed();

        uint256[] memory amounts = abi.decode(data, (uint256[]));
        amountOut = amounts[amounts.length - 1];

        if (amountOut < amountOutMin) revert SlippageExceeded();

        emit SwapExecuted(msg.sender, path[0], address(0), amountIn, amountOut, router);
    }

    /**
     * @notice Get expected output amount for a swap (view only)
     * @param router The DEX router address
     * @param amountIn The input amount
     * @param path The swap path
     * @return amounts The expected amounts along the path
     */
    function getAmountsOut(address router, uint256 amountIn, address[] calldata path)
        external
        view
        returns (uint256[] memory amounts)
    {
        if (router == address(0)) revert InvalidRouter();
        if (path.length < 2) revert InvalidPath();

        (bool success, bytes memory data) =
            router.staticcall(abi.encodeWithSignature("getAmountsOut(uint256,address[])", amountIn, path));

        if (!success) revert SwapFailed();

        amounts = abi.decode(data, (uint256[]));
    }
}
