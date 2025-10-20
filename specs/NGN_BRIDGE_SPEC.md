# NGNBridge Specification

_Date: 2025-10-17_

## 1. Purpose
Implement an on-chain contract (`NGNBridge.sol`) to mint/burn cNGN stablecoin representations in sync with off-chain fiat events logged by the Fiat Service. The bridge must ensure only authorized controllers can initiate conversions, emit auditable events, and support reconciliation workflows.

## 2. Functional Requirements
- `mint` cNGN when fiat deposits confirmed (Paystack/Monnify events).
- `burn` cNGN when users withdraw to bank accounts.
- Enforce per-transaction and per-day limits aligned with KYC tier policies.
- Ensure bridging operations are idempotent (use unique reference IDs).
- Integrate with policy modules to restrict operations if user flagged.
- Provide event feed for Observer daemon to reconcile on/off-chain states.

## 3. Actors & Roles
- **Fiat Controller**: off-chain service (Fiat Service) authorized to call mint/burn functions after verifying fiat events.
- **Paymaster Controller**: may query bridge data for sponsorship adjustments.
- **Guardian/Owner**: admin controlling role assignments, pausing contract.

## 4. State Variables
- `address cngnToken` (ERC-20 token address or minted within contract via ERC20PresetMinterBurner).
- `mapping(bytes32 => bool) processedRefs` (track unique references to prevent replay).
- `mapping(address => uint256)` dailyMinted / dailyBurned (per user per day if needed).
- `mapping(address => bool)` blockedAccounts (safety control).
- `uint64 lastReset` (timestamp for daily counters).
- `uint256 dailyMintLimit`, `dailyBurnLimit` (in kobo or token units).

## 5. Core Functions
- `mint(address beneficiary, uint256 amount, string calldata ref, bytes calldata metadata)`
  - Only callable by Fiat Controller role.
  - Verify ref not processed; ensure amount <= daily limit for beneficiary (based on KYC tier provided in metadata or on-chain lookup).
  - Mint cNGN to beneficiary; mark `processedRefs`.
  - Emit `Minted(beneficiary, amount, ref, metadataHash)`.
- `burn(address beneficiary, uint256 amount, string calldata ref, bytes calldata metadata)`
  - Called when fiat withdrawal executed.
  - Transfer cNGN from beneficiary via allowance (require user approval), burn tokens.
  - Enforce daily burn limits; mark reference.
  - Emit `Burned(beneficiary, amount, ref, metadataHash)`.
- `setDailyLimits(uint256 mintLimit, uint256 burnLimit)` — owner/controller sets.
- `setBlocked(address account, bool blocked)` — block suspicious accounts.
- `pause()` / `unpause()` — emergency control.
- Internal `_resetDailyIfNeeded(address account)` to reset counters per day.

## 6. Event Schema
- `event Minted(address indexed beneficiary, uint256 amount, string ref, bytes32 metadataHash)`
- `event Burned(address indexed beneficiary, uint256 amount, string ref, bytes32 metadataHash)`
- `event AccountBlocked(address indexed account, bool blocked)`
- `event DailyLimitsUpdated(uint256 mintLimit, uint256 burnLimit)`

## 7. Security Considerations
- Role-based access control via `AccessControl` (roles: DEFAULT_ADMIN, FIAT_CONTROLLER, PAUSER).
- Replay protection through `processedRefs` (hash unique references from fiat service).
- Prevent double counting of daily limits by resetting counters at midnight UTC.
- Validate metadata hash if containing sensitive info; off-chain service stores details in Postgres.
- Optionally integrate on-chain proof (EIP-712 signed instructions) to avoid direct role trust.

## 8. Interaction with Off-Chain Systems
- Fiat Service obtains confirmation from Paystack/Monnify -> calls `mint` with unique reference.
- For withdrawals, fiat service verifies cNGN burn succeeded before initiating bank transfer.
- Observer monitors `Minted`/`Burned` events, compares with Postgres ledger (
`fiat_transactions` table) to ensure 1:1 parity.

## 9. Testing Strategy
- Unit tests for mint/burn logic, replay prevention, daily limit resets.
- Integration tests with mocked Fiat Controller using Foundry/Hardhat.
- KYC tier enforcement tests by stubbing `getUserTier(address)` (either direct mapping or external call).

## 10. Open Questions
- Should cNGN token be upgradeable or separate contract minted via bridge? (likely separate ERC20 contract with bridge as minter).
- Source of KYC tier data: on-chain mapping vs off-chain signature? (decision pending backend design).

Spec will be updated after alignment with compliance and fiat provider requirements.
