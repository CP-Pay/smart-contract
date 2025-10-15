# CPPay Smart Contract - Quick Reference

**For developers who want to get started fast** ⚡

---

## 🚀 One-Minute Setup

```bash
# Clone and build
git clone <repo>
cd smart-contract
forge install
forge build

# Run tests
forge test

# Deploy to testnet
forge script script/DeployCPPayComplete.s.sol \
  --rpc-url $LISK_RPC_URL \
  --broadcast
```

---

## 📋 Contract Addresses (After Deployment)

### Lisk L2 Testnet
```javascript
// Update these after deployment
const FACTORY = "0x...";
const CNGN = "0x...";
const ENTRY_POINT = "0x...";
const TREASURY = "0x...";
```

---

## 💻 Frontend Quick Start

### 1. Install ethers.js
```bash
npm install ethers
```

### 2. Connect to User's Wallet
```typescript
import { ethers } from 'ethers';

// Connect via MetaMask
const provider = new ethers.BrowserProvider(window.ethereum);
const signer = await provider.getSigner();

// Load user's Diamond wallet
const diamond = new ethers.Contract(
  USER_DIAMOND_ADDRESS,
  DIAMOND_ABI,
  signer
);
```

### 3. Common Operations

#### Create New Wallet
```typescript
const factory = new ethers.Contract(FACTORY, FACTORY_ABI, signer);
const tx = await factory.createWallet(userAddress, facetCuts, initData);
const receipt = await tx.wait();
const walletAddress = receipt.logs[0].address; // Extract from event
```

#### Pay a Bill
```typescript
// Lock CNGN for bill payment
await diamond.lockCNGN(
  ethers.parseUnits("5000", 18),              // 5000 CNGN
  ethers.keccak256(ethers.toUtf8Bytes("ELECTRIC")),
  "REF-12345"
);
```

#### Create Session Key (One-Tap)
```typescript
const selectors = [
  diamond.interface.getFunction("lockCNGN").selector,
  diamond.interface.getFunction("swap").selector
];

await diamond.createSessionKey(
  sessionKeyAddress,
  86400,                          // 24 hours
  ethers.parseEther("0.01"),      // 0.01 ETH gas limit
  selectors
);
```

#### Swap Tokens
```typescript
await diamond.swap(
  tokenInAddress,
  tokenOutAddress,
  ethers.parseUnits("100", 18),   // 100 tokens
  ethers.parseUnits("95", 18),    // Min 95 out (5% slippage)
  deadline
);
```

#### Import Existing Wallet
```typescript
// User imports their EOA
await diamond.linkImportedAddress(
  eoaAddress,
  0  // 0 = EOA, 1 = Smart Wallet
);
```

#### Add Guardian
```typescript
await diamond.addGuardian(guardianAddress);
```

---

## 🔧 Backend Quick Start

### Monitor Events
```typescript
// Listen for bill payments
diamond.on('CNGNLocked', async (user, amount, serviceCode, refId, event) => {
  console.log(`New bill payment: ${refId}, Amount: ${ethers.formatUnits(amount, 18)} CNGN`);
  
  // Process with bill provider
  const success = await processBillWithProvider(refId);
  
  // Complete or refund on-chain
  if (success) {
    await diamond.completeEscrow(refId);
  } else {
    await diamond.refundCNGN(refId);
  }
});

// Listen for session key creation
diamond.on('SessionKeyCreated', async (owner, keyId, sessionKey, event) => {
  console.log(`Session key created: ${keyId}`);
  // Store in database for tracking
});

// Listen for guardian votes
diamond.on('RecoveryInitiated', async (guardian, newOwner, event) => {
  console.log(`Recovery vote from ${guardian} for ${newOwner}`);
  // Alert admins if needed
});
```

---

## 📦 All 13 Facets Reference

| # | Facet | Purpose | Key Functions |
|---|-------|---------|---------------|
| 1 | ConfigFacet | Setup | `initialize()`, `setTreasury()` |
| 2 | EscrowFacet | Bill Payments | `lockCNGN()`, `refundCNGN()`, `completeEscrow()` |
| 3 | SessionKeyFacet | One-Tap UX | `createSessionKey()`, `revokeSessionKey()` |
| 4 | GuardianFacet | Recovery | `addGuardian()`, `initiateRecovery()` |
| 5 | PaymasterFacet | Gas Sponsor | `setMonthlyLimit()`, `validatePaymasterUserOp()` |
| 6 | SubscriptionFacet | User Tiers | `claimTrial()`, `setUserTier()` |
| 7 | SwapFacet | DEX Swaps | `swap()`, `addLiquidity()` |
| 8 | SwapEscrowFacet | Off-chain Swaps | `depositForSwap()`, `fulfillSwap()` |
| 9 | ImportFacet | Wallet Import | `linkImportedAddress()`, `unlinkImportedAddress()` |
| 10 | AccountFacet | ERC-4337 | `execute()`, `executeBatch()` |
| 11 | DiamondCutFacet | Upgrades | `diamondCut()` |
| 12 | DiamondLoupeFacet | Introspection | `facets()`, `facetAddress()` |
| 13 | OwnershipFacet | Ownership | `transferOwnership()` |

---

## 🎯 Common User Flows

### Flow 1: New User Onboarding
```
1. User signs up → Frontend calls factory.createWallet()
2. Diamond proxy created → User gets wallet address
3. User funds wallet → Send CNGN/ETH to Diamond
4. User ready to pay bills
```

### Flow 2: Import Existing Wallet
```
1. User enters seed phrase → Frontend derives private key
2. Frontend derives EOA address
3. Call diamond.linkImportedAddress(eoaAddress, 0)
4. Imported wallet can now sign Diamond transactions
```

### Flow 3: Pay Bill
```
1. User selects bill → Enter amount (e.g., 5000 CNGN)
2. Frontend calls diamond.lockCNGN(amount, "ELECTRIC", refId)
3. Backend listens to CNGNLocked event
4. Backend processes bill with provider
5. Backend calls diamond.completeEscrow(refId) if success
6. User receives confirmation
```

### Flow 4: One-Tap Setup
```
1. User enables one-tap → Frontend generates session key
2. Frontend calls diamond.createSessionKey(sessionKey, 86400, gasLimit, selectors)
3. Session key stored in local storage
4. Next transaction signed with session key (no wallet popup)
5. Session expires after 24 hours
```

### Flow 5: Token Swap
```
1. User wants to swap → Select tokens and amount
2. Frontend calls diamond.swap(tokenIn, tokenOut, amountIn, minAmountOut, deadline)
3. DEX router executes swap
4. User receives output tokens
```

### Flow 6: Social Recovery
```
1. User adds 3 guardians → Call diamond.addGuardian() 3 times
2. User loses access → Guardian 1 calls initiateRecovery(newOwner)
3. Guardian 2 votes → Calls initiateRecovery(newOwner)
4. After 3 days → Anyone calls executeRecovery()
5. Ownership transferred to newOwner
```

---

## ⚡ Gas Costs Cheat Sheet

| Operation | Gas | ETH @ 20 gwei | Naira @ 2M/ETH | Sponsored? |
|-----------|-----|---------------|----------------|------------|
| Create Wallet | ~2M | 0.04 | ₦80,000 | ❌ User pays |
| Lock CNGN | ~143K | 0.003 | ₦6,000 | ✅ Yes (if <10/day) |
| Session Key | ~221K | 0.004 | ₦8,800 | ✅ Yes (if <10/day) |
| Swap | ~150K | 0.003 | ₦6,000 | ✅ Yes (if <10/day) |
| Complete Escrow | ~47K | 0.001 | ₦2,000 | ✅ Yes (if <10/day) |

**💰 Gas Sponsorship Rules:**
- ✅ Transactions < ₦10,000 (~0.005 ETH) are sponsored
- ✅ Maximum 10 sponsored transactions per day
- ❌ Transactions ≥ ₦10,000 paid by user
- ❌ After 10 daily transactions, user pays with chosen token

---

## 🔐 Security Checklist

### Frontend
- [ ] Validate all user inputs
- [ ] Check token approvals before swaps
- [ ] Display gas estimates before transactions
- [ ] Handle session key expiry gracefully
- [ ] Show clear error messages
- [ ] Never expose private keys
- [ ] Use secure random for session keys

### Backend
- [ ] Monitor all contract events
- [ ] Validate bill payment confirmations
- [ ] Track session key usage
- [ ] Alert on guardian recovery attempts
- [ ] Rate limit API endpoints
- [ ] Log all blockchain interactions
- [ ] Implement retry logic for failed txs

---

## 🐛 Common Errors & Fixes

### Error: "Ownable: caller is not the owner"
**Fix**: Ensure you're calling from the Diamond owner's address

### Error: "Session key expired"
**Fix**: Create a new session key (they last 24 hours by default)

### Error: "Insufficient allowance"
**Fix**: User must approve Diamond to spend their tokens first

### Error: "Guardian threshold not met"
**Fix**: Need 2/3 guardians to vote for recovery

### Error: "Daily gas limit exceeded"
**Fix**: User exceeded 10 sponsored transactions today - must pay with their tokens

### Error: "Transaction too expensive for sponsorship"
**Fix**: Transaction costs ≥ ₦10,000 - user must pay with their tokens

### Error: "Escrow already completed"
**Fix**: Cannot refund or complete an already finalized escrow

---

## 📞 Need Help?

1. **Read the full guide**: [IMPLEMENTATION_GUIDE.md](IMPLEMENTATION_GUIDE.md)
2. **Check architecture**: [SC ARCHITECTURE.md](SC%20ARCHITECTURE.md)
3. **See flows**: [CPPAY-FLOW.md](CPPAY-FLOW.md)
4. **Open issue**: GitHub Issues
5. **Email**: dev@cppay.io

---

## 🧪 Testing Commands

```bash
# Run all tests
forge test

# Run specific test
forge test --match-test testLockCNGN -vv

# Gas report
forge test --gas-report

# Coverage
forge coverage

# Local deployment
anvil  # Terminal 1
forge script script/DeployCPPayComplete.s.sol --rpc-url http://localhost:8545 --broadcast  # Terminal 2
```

---

## 📝 Quick Deployment

```bash
# 1. Setup .env
cat > .env << EOF
PRIVATE_KEY=0x...
LISK_RPC_URL=https://rpc.sepolia-api.lisk.com
LISK_API_KEY=...
EOF

# 2. Deploy
forge script script/DeployCPPayComplete.s.sol \
  --rpc-url $LISK_RPC_URL \
  --broadcast \
  --verify

# 3. Extract addresses from logs
# Look for "Factory deployed at: 0x..."
```

---

## 🎨 Event Names Reference

**Listen to these events in your backend:**

```typescript
// Bill Payments
"CNGNLocked(address indexed user, uint256 amount, bytes32 serviceCode, string refId)"
"CNGNRefunded(address indexed user, uint256 amount, string refId)"
"EscrowCompleted(string refId)"

// Session Keys
"SessionKeyCreated(address indexed owner, uint256 keyId, address sessionKey)"
"SessionKeyRevoked(address indexed owner, uint256 keyId)"

// Guardians
"GuardianAdded(address indexed guardian)"
"GuardianRemoved(address indexed guardian)"
"RecoveryInitiated(address indexed guardian, address indexed newOwner)"
"RecoveryExecuted(address indexed oldOwner, address indexed newOwner)"

// Swaps
"SwapExecuted(address indexed user, address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut)"
"SwapDeposited(address indexed user, address tokenIn, uint256 amount)"
"SwapFulfilled(address indexed user, address tokenOut, uint256 amount)"

// Subscriptions
"TrialClaimed(address indexed user)"
"UserTierUpdated(address indexed user, uint8 tier)"

// Import
"ImportedAddressLinked(address indexed diamond, address indexed imported, uint8 walletType)"
"ImportedAddressUnlinked(address indexed diamond)"
```

---

**That's it! You're ready to integrate with CPPay smart contracts** 🎉

For detailed examples and advanced usage, see [IMPLEMENTATION_GUIDE.md](IMPLEMENTATION_GUIDE.md)
