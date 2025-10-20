# CPPay Paymaster v2 Specification

_Date: 2025-10-17_

## 1. Motivation
Current Paymaster contract enforces a static 1 ETH/day limit without NGN awareness or detailed logging. Paymaster v2 must back CPPay’s ₦1000/day sponsorship model, integrate with on-chain/off-chain accounting, and expose hooks for KYC tier limits, paymaster pause, and health monitoring.

## 2. Key Objectives
- Support NGN-denominated daily limits (~₦1000) with dynamic gas-price conversion to wei.
- Maintain per-user residual budget, leveraging off-chain Paymaster Controller for rate updates.
- Emit granular events for usage tracking (`GasSponsored`, `BudgetUpdated`, `UserTierChanged`).
- Allow Tier 2 users to raise limit to ₦5,000,000/day (converted to wei).
- Integrate optional policy modules (e.g., spending caps per transaction type).
- Ensure compatibility with EntryPoint v0.6 and bundler expectations.

## 3. Architecture Overview
- Contract parameters:
  - `uint256 baseDailyBudgetNgk` (default 1000 * 1e2 to track kobo units).
  - `uint256 priceFeed` or pointer to rate via `IAggregator` (NGN per wei or wei per NGN).
  - `uint256 verifiedMultiplier` (defaults to 5000 for Tier 2 -> ₦5M).
- Storage per user:
  - `uint256 usedWeiToday`.
  - `uint64 lastReset` (epoch seconds).
  - `uint64 dailyBudgetWei` (converted based on latest rate).
  - `bool isTier2` (true when Paymaster Controller sets verification).
- Off-chain Paymaster Controller updates budgets via signed transactions (or owner-only setter).

## 4. Core Functions
- `_validatePaymasterUserOp(UserOperation, bytes32, uint256)`
  - Ensure Paymaster active flag set.
  - Reset user budget if `block.timestamp > lastReset + 1 days`.
  - Retrieve `dailyBudgetWei`; compare with `estimatedCost` (max fee).
  - Revert if exceeding budget; else store context with cost estimate.
- `_postOp(PostOpMode, bytes context, uint256 actualGasCost)`
  - Deduct actual gas cost from `usedWeiToday`.
  - Emit `GasSponsored(user, actualGasCost, remainingWei, block.timestamp)`.
- `updateExchangeRate(uint256 weiPerNaira, uint256 timestamp)`
  - Only Paymaster Controller or owner; adjust base budgets.
  - Recompute `dailyBudgetWei` for future resets.
- `setUserTier(address user, bool isTier2)`
  - Owner/controller sets tier; adjust multiplier.
- `pause()` / `unpause()`
  - Owners control contract activity.

## 5. Events
- `GasSponsored(address indexed user, uint256 gasUsedWei, uint256 remainingWei, uint256 timestamp)`
- `DailyBudgetReset(address indexed user, uint256 newBudgetWei)`
- `ExchangeRateUpdated(uint256 weiPerNaira, uint256 effectiveAt)`
- `UserTierUpdated(address indexed user, uint256 multiplier)`
- `PaymasterPaused(bool isPaused)`

## 6. Security & Validation
- Prevent integer overflow when converting NGN budgets -> wei (use checked math).
- Input validation for `updateExchangeRate` (accept signed data with EIP-712 from controller?).
- Access control via Ownable + dedicated `CONTROLLER_ROLE` (OpenZeppelin AccessControl).
- Ensure `_postOp` cannot underflow when subtracting gas (actualCost <= estimated). If not, clamp to zero.
- Resist manipulation by bundler: `context` must encode user and estimated cost.

## 7. Off-Chain Coordination
- Paymaster Controller service pulls on-chain events and updates `GasSponsorship` table (Postgres) with NGN amounts.
- Reset budgets at midnight UTC and push new budgets via `updateExchangeRate` if rate changed.
- Provide API endpoint to supply paymaster signature for bundler (optional hashed message to verify gas sponsorship).

## 8. Testing Requirements
- Unit tests: budget reset, tier upgrades, pause/unpause, overflow scenarios.
- Property-based tests for fluctuating exchange rates.
- Integration tests with SmartAccount + bundler simulation.
- Gas cost evaluation to ensure Paymaster operations remain affordable.

## 9. Open Questions
- Should exchange-rate updates be on-chain via Chainlink price feed or off-chain signed? (Decision pending.)
- Do we allow user-specific overrides (e.g., promo budgets)? if yes, extend storage with `customBudgetWei`.

This spec will be refined during implementation planning and security review.
