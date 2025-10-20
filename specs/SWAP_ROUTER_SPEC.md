# SwapRouter Specification

_Date: 2025-10-17_

## 1. Objective
Provide an on-chain routing contract that interfaces with external aggregators (0x/1inch) to execute token swaps (crypto↔crypto, crypto↔cNGN) within controlled parameters. SwapRouter ensures users obtain quotes via backend but execution occurs trustlessly on-chain with slippage guards.

## 2. Requirements
- Accept swap instructions from SmartAccount or approved modules.
- Enforce maximum slippage (basis points) and deadline.
- Support swapping to/from cNGN by interacting with NGNBridge or direct token pair.
- Emit swap events for reconciliation (used by Swap Service to match backend records).
- Integrate allowlist for target aggregator addresses to avoid arbitrary call injection.

## 3. Interfaces
- Accept data from off-chain aggregator (call data + allowance target + min return).
- Expose `swap(SwapRequest calldata request)` called by SmartAccount or bundler.
- `SwapRequest` struct fields:
  - `address fromToken`
  - `address toToken`
  - `uint256 amountIn`
  - `uint256 minAmountOut`
  - `uint256 deadline`
  - `address callTarget` (aggregator contract)
  - `bytes callData`
  - `uint16 slippageBps`
  - `bytes32 refId`

## 4. Flow
1. SmartAccount obtains quote via backend (0x/1inch API) -> receives call data.
2. SmartAccount invokes `SwapRouter.swap(request)`.
3. Router verifies `callTarget` is whitelisted, `deadline` not expired, `amountIn` approved.
4. Router executes external call (low-level) to aggregator with provided calldata.
5. After call returns, check received token balance >= `minAmountOut`.
6. Emit `SwapExecuted(refId, fromToken, toToken, amountIn, amountOut, caller)`.

## 5. Storage
- `mapping(address => bool) public approvedTargets`.
- `mapping(bytes32 => bool) public processedRefs` for idempotency.
- Optional `address feeRecipient`, `uint16 feeBps` to collect protocol fee (future).

## 6. Security Considerations
- Ensure `processedRefs` prevents re-execution of same swap.
- Pre-approve aggregator target for tokens or require the SmartAccount to set allowances.
- Validate return success; revert on failure.
- Use try/catch to handle aggregator reverts and bubble error message.
- Guard against sandwich attacks by setting conservative `minAmountOut` via backend.

## 7. Events
- `event SwapExecuted(bytes32 indexed refId, address indexed sender, address fromToken, address toToken, uint256 amountIn, uint256 amountOut)`
- `event TargetUpdated(address target, bool approved)`

## 8. Testing
- Unit tests mocking aggregator calls; ensure slippage enforcement and deadline expiry.
- Integration tests with Hardhat for 0x API on Base testnet.
- Negative tests for unauthorized target, expired deadline, insufficient output.

## 9. Open Questions
- Should router take custody of funds or rely on SmartAccount allowances? (Prefer direct call pattern via `transferFrom`).
- Multi-hop support needed? (If aggregator handles, router stays simple.)

Specs will refine once backend aggregator integration is finalized.
