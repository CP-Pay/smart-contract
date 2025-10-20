# SmartAccount v2 Specification

_Date: 2025-10-17_

## 1. Purpose & Scope
Design a modular ERC-4337-compatible smart-account wallet tailored for CPPay’s gas-abstracted, mobile-first experience. The contract must support social login onboarding, session keys, batch execution, tier-based spending policies, and safe integrations with Paymaster v2 and SwapRouter/NGNBridge modules.

## 2. High-Level Requirements
- ERC-4337 account that plugs into EntryPoint v0.6 (or newer) with standardized validation handler.
- Owner management supporting single primary owner plus optional guardians (for social recovery).
- Session key framework enabling delegated approvals with scopes (spending limits, allowed targets).
- Batch execution for multi-call flows (swap + bill pay + record).
- Nonce management segmented by key/per module to prevent replay between channels.
- Hook points for policy modules (e.g., KYC tier, payout caps) without redeploying core account.
- Emits events for observer services (account deployed, session key created/revoked, batch executed).

## 3. Contract Architecture
- `SmartAccount` inherits from minimal AA reference (e.g., LightAccount style) but adds module registry.
- Key components:
  - `OwnerManager`: stores primary owner, guardians, threshold rules.
  - `SessionKeyRegistry`: maps session IDs to policy structs (limits, target selectors, expiration).
  - `ModuleManager`: registers external modules (SwapModule, PolicyModule) with permissioned execution.
  - `SpendingPolicy`: library enforcing tier limits (possibly on-chain checks leveraging Paymaster or off-chain signals).
  - `BatchExecutor`: function enabling array of calls executed atomically.

## 4. State Variables
- `address owner` (primary controller)
- `mapping(address => bool) guardians`
- `uint256 guardianThreshold` (social recovery threshold)
- `mapping(bytes32 => SessionKey)` sessionKeys (keyed by `keccak256(sessionKeyAddr, scopeId)`)
- `mapping(uint256 => uint256)` nonceByKey (keyed by channel – owner, session, module)
- `mapping(bytes4 => bool)` allowedSelectors (optional guard for session scopes)
- `mapping(address => bool)` modules (authorized module contracts)
- `struct SessionKey { address key; uint48 validAfter; uint48 validUntil; uint128 spendLimitWei; bytes4[] selectors; bytes32 scope }`

## 5. Core Functions
- `setOwner(address newOwner)` — only current owner, emits `OwnerChanged`.
- `addGuardian(address guardian)` / `removeGuardian` — owner-managed, emits events.
- `recoverWithGuardians(address newOwner, bytes[] guardianSigs)` — enforces threshold.
- `registerSessionKey(SessionKeyData)` — owner-only, sets spend limits/selectors; emits `SessionKeyRegistered`.
- `revokeSessionKey(bytes32 keyId)` — owner or guardian (if compromised).
- `validateUserOp(UserOperation calldata userOp, bytes32 userOpHash, uint256 missingFunds)` — main AA hook; routes to owner or session key validation based on signature type.
- `executeBatch(Call[] calldata calls)` — exposed via AA; ensures policy checks before execution.
- `executeModule(address module, bytes calldata data)` — only for whitelisted modules; increments module-specific nonce.
- `getNonce(uint192 key)` — override to supply per-channel nonces.

## 6. Session Key Policy Checks
- `maxSpendPerSession` enforced by tracking `sessionUsage[keyId]` and blocking once exceeded.
- Allowed selectors/targets to guard scope (e.g., swap allowances).
- Optionally integrate with Paymaster to fetch daily allowance in NGN equivalent.
- Default session lifetime ≤ 24 hours; enforce `validUntil`.

## 7. Security Considerations
- Nonces separated by channel (owner vs session vs module).
- Reentrancy guard not strictly required for AA, but safe pattern for batch execution.
- Guardian-based recovery must avoid signature replay (include nonce/expiry).
- Module execution restricted; modules must implement interface returning success flag.
- Sanitize external call return data to avoid malicious back data.
- Align with auditing checklist (recovery attack, misconfigured session, DoS).

## 8. External Interfaces
- `ISmartAccountModule` interface for external modules.
- `ISessionKeyValidator` for customizing session key policy evaluation.
- Emits events consumed by Observer service: `SmartAccountInitialized`, `SessionKeyRegistered`, `SessionKeyRevoked`, `BatchExecuted`.

## 9. Upgradeability
- Plan for upgrade path (UUPS or minimal proxy). For initial release, deploy as minimal proxy via factory to support upgrades by redeploying implementation (with owner-signed upgrade transactions).
- Document migration contract should patch existing wallets.

## 10. Testing Strategy
- Foundry/Hardhat tests covering:
  - Owner execution, guardian recovery.
  - Session key validations (valid/invalid, spend limits, selector restrictions).
  - Batch execution with module-specific calls.
  - Replay protection (nonce increments per scope).
  - Fuzz tests for boundary conditions (limit exhaustion, revert scenarios).
- Integration tests with Paymaster & Bundler simulation.

## 11. Open Questions
- Social login guardian mapping: will off-chain auth provider supply guardian addresses dynamically?
- Should session keys support gas sponsorship-specific metadata (e.g., paymaster signature)?
- How will upgrade keys be secured (multisig vs owner-managed)?

This specification will be refined with feedback from security review and contract audit prep.
