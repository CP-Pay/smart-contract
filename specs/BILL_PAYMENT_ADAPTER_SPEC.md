# BillPaymentAdapter Specification

_Date: 2025-10-17_

## 1. Purpose
Bridge on-chain payment intents to off-chain bill payment providers (Reloadly, telco APIs). The adapter records payment instructions and emits events consumed by the BillPay Service, ensuring a verifiable linkage between user UserOperations and fiat/telco execution.

## 2. Functionality
- Accept payment intent from SmartAccount or approved module with necessary metadata (provider code, amount, beneficiary).
- Lock required funds (cNGN or stablecoin) until off-chain execution completes.
- Emit events for off-chain service to pick up and process payment.
- Support confirmation once payment executed; release funds to provider wallet or refund on failure.

## 3. Contract Design
- Users interact via `initiatePayment(PaymentRequest calldata req)`.
- Adapter holds funds in escrow (ERC-20 transfer to contract) until `completePayment` or `refundPayment` called by controller.
- Roles: `PAYMENT_PROCESSOR` (BillPay Service) authorized to finalize/refund payments.
- Payment states stored on-chain for audit trail.

## 4. Data Structures
```
enum PaymentStatus { Pending, Completed, Refunded, Cancelled }

struct PaymentRequest {
    bytes32 refId;
    address payer;
    address asset; // token (cNGN/USDC)
    uint256 amount;
    string providerCode;
    string beneficiaryId; // phone/meter/card number
    string metadataURI; // optional pointer to IPFS/JSON data
    uint256 deadline;
}

struct PaymentRecord {
    PaymentStatus status;
    address payer;
    address asset;
    uint256 amount;
    string providerCode;
    string beneficiaryId;
    uint256 createdAt;
    uint256 completedAt;
}
```

Storage: `mapping(bytes32 => PaymentRecord) public payments;`

## 5. Workflow
1. User obtains quote off-chain, then calls `initiatePayment(req)`.
   - Verifies `deadline`.
   - Transfers `amount` from payer to adapter (requires approval).
   - Records payment as `Pending`; emit `PaymentInitiated(refId, payer, asset, amount, providerCode, beneficiaryId)`.
2. BillPay Service listens to event, executes off-chain transaction.
3. On success, service calls `completePayment(refId, bytes calldata processorData)`.
   - Marks status Completed, stores timestamp.
   - Optionally forwards funds to provider wallet if on-chain settlement is needed (for example, paying a telco that accepts stablecoin).
   - Emit `PaymentCompleted(refId, processorDataHash)`.
4. On failure, service calls `refundPayment(refId, string reason)`.
   - Transfers funds back to payer.
   - Emit `PaymentRefunded(refId, reason)`.

## 6. Security / Edge Cases
- Reentrancy guard on state-changing functions.
- Prevent duplicate refs with `processedRefs` mapping.
- Only `PAYMENT_PROCESSOR` role can complete/refund.
- Allow owner to pause initiation in emergencies.
- If payment pending beyond SLA (deadline), payer can invoke `cancelExpiredPayment` to reclaim funds.

## 7. Events
- `PaymentInitiated(bytes32 indexed refId, address indexed payer, address asset, uint256 amount, string providerCode, string beneficiaryId)`
- `PaymentCompleted(bytes32 indexed refId, bytes32 processorDataHash)`
- `PaymentRefunded(bytes32 indexed refId, string reason)`
- `PaymentCancelled(bytes32 indexed refId)`

## 8. Testing
- Unit tests for initiate/complete/refund/cancel flows, deadline expiry, duplicate refs.
- Integration tests with simulated off-chain consumer to ensure event-driven reconciliation.

## 9. Questions
- Should escrow funds remain in adapter or immediately transferred to provider wallet pending off-chain ack? (current design holds until completion.)
- Metadata storage: on-chain strings vs off-chain references; final decision pending compliance requirements.

Spec subject to adjustment once BillPay Service API is finalized.
