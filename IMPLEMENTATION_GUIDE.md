# CPPay Smart Contract Implementation Guide
## For Frontend & Backend Developers

**Version:** 1.0  
**Date:** October 13, 2025  
**Network:** Lisk L2 (EVM Compatible)

---

## Table of Contents
1. [Quick Start](#quick-start)
2. [Architecture Overview](#architecture-overview)
3. [Contract Addresses](#contract-addresses)
4. [Core Workflows](#core-workflows)
5. [API Reference](#api-reference)
6. [Integration Examples](#integration-examples)
7. [Error Handling](#error-handling)
8. [Gas Optimization](#gas-optimization)

---

## Quick Start

### Installation
```bash
npm install ethers@^6.0.0
```

### Initialize Contract Instance
```typescript
import { ethers } from 'ethers';

// Connect to Lisk L2
const provider = new ethers.JsonRpcProvider('https://rpc.lisk.com');
const signer = new ethers.Wallet(PRIVATE_KEY, provider);

// Factory contract (deploy once)
const factory = new ethers.Contract(FACTORY_ADDRESS, FACTORY_ABI, signer);

// User's Diamond wallet
const userWallet = new ethers.Contract(DIAMOND_ADDRESS, DIAMOND_ABI, signer);
```

---

## Architecture Overview

### Diamond Proxy Pattern (EIP-2535)
Each user gets their own **upgradeable smart contract wallet** (Diamond proxy). All logic is in separate **Facets** that the Diamond delegates to.

```
User Address
    ↓
Diamond Proxy (User's Wallet)
    ↓ (delegates to)
┌─────────────────────────────────────┐
│  Facets (Shared Logic Contracts)   │
├─────────────────────────────────────┤
│ • ConfigFacet                       │
│ • EscrowFacet                       │
│ • SessionKeyFacet                   │
│ • GuardianFacet                     │
│ • PaymasterFacet                    │
│ • SubscriptionFacet                 │
│ • SwapFacet                         │
│ • SwapEscrowFacet                   │
│ • ImportFacet                       │
└─────────────────────────────────────┘
```

**Key Concept:** One Diamond per user, many facets shared across all users.

---

## Contract Addresses

### Lisk L2 Mainnet (TBD after deployment)
```typescript
export const ADDRESSES = {
  FACTORY: '0x...', // CPPayFactory
  CNGN: '0x...', // CNGN token
  ENTRY_POINT: '0x...', // ERC-4337 EntryPoint
  TREASURY: '0x...', // CPPay treasury
};
```

### Lisk L2 Testnet
```typescript
export const TESTNET_ADDRESSES = {
  FACTORY: '0x...',
  CNGN: '0x...',
  ENTRY_POINT: '0x...',
  TREASURY: '0x...',
};
```

---

## Core Workflows

### 1. Create New Wallet

**Backend Flow:**
```typescript
// User signs up → Backend creates Diamond wallet
async function createWallet(userAddress: string) {
  const factory = new ethers.Contract(FACTORY_ADDRESS, FACTORY_ABI, signer);
  
  // Prepare facet cuts (which functions to enable)
  const facetCuts = await prepareFacetCuts();
  
  // Deploy Diamond for user
  const tx = await factory.createWallet(
    userAddress,
    facetCuts,
    '0x' // no init data
  );
  
  const receipt = await tx.wait();
  
  // Extract Diamond address from event
  const event = receipt.logs.find(log => 
    log.topics[0] === ethers.id('WalletCreated(address,address,uint256)')
  );
  
  const diamondAddress = ethers.AbiCoder.defaultAbiCoder().decode(
    ['address', 'address', 'uint256'],
    event.data
  )[1];
  
  // Store in database
  await db.wallets.create({
    userId: user.id,
    address: diamondAddress,
    createdAt: new Date()
  });
  
  return diamondAddress;
}
```

**Frontend:**
```typescript
// After signup, poll backend for wallet creation
const response = await api.post('/wallets/create');
const { diamondAddress } = response.data;

// Save to local storage
await SecureStore.setItemAsync('walletAddress', diamondAddress);
```

---

### 2. Import Existing Wallet

**User Flow:** User has seed phrase → wants to use CPPay

**Frontend:**
```typescript
async function importWallet(seedPhrase: string) {
  // Derive address from seed phrase
  const wallet = ethers.Wallet.fromPhrase(seedPhrase);
  const importedAddress = wallet.address;
  
  // Send to backend
  const response = await api.post('/wallets/import', {
    importedAddress,
    walletType: 0 // 0=EOA, 1=SmartWallet, 2=Hardware
  });
  
  const { diamondAddress } = response.data;
  
  // Store encrypted private key locally
  const encrypted = await encryptPrivateKey(wallet.privateKey, userPIN);
  await SecureStore.setItemAsync('encryptedKey', encrypted);
  await SecureStore.setItemAsync('walletAddress', diamondAddress);
  await SecureStore.setItemAsync('importedAddress', importedAddress);
  
  return { diamondAddress, importedAddress };
}
```

**Backend:**
```typescript
async function importWallet(userAddress: string, importedAddress: string, walletType: number) {
  // Create Diamond
  const diamondAddress = await createWallet(userAddress);
  
  // Link imported address (requires owner signature)
  const diamond = new ethers.Contract(diamondAddress, DIAMOND_ABI, signer);
  
  // Note: This call will fail from backend because backend isn't the owner
  // User must call linkImportedAddress from frontend after creation
  
  return { diamondAddress };
}
```

**Important:** User must call `linkImportedAddress` themselves:
```typescript
// Frontend after import
const diamond = new ethers.Contract(diamondAddress, DIAMOND_ABI, userSigner);
await diamond.linkImportedAddress(importedAddress, 0); // walletType 0 = EOA
```

---

### 3. Lock CNGN for Bill Payment (Fiat Off-Ramp)

**User Flow:** User pays ₦5,000 bill → Lock CNGN → Backend confirms payment → Release CNGN to merchant

**Frontend:**
```typescript
async function payBill(amount: string, billType: string) {
  const amountCNGN = ethers.parseUnits(amount, 18); // CNGN has 18 decimals
  const serviceCode = ethers.keccak256(ethers.toUtf8Bytes(billType));
  const refId = ethers.keccak256(ethers.toUtf8Bytes(`REF-${Date.now()}`));
  
  const diamond = new ethers.Contract(walletAddress, DIAMOND_ABI, signer);
  
  // Approve Diamond to spend CNGN (if not already approved)
  const cngn = new ethers.Contract(CNGN_ADDRESS, ERC20_ABI, signer);
  await cngn.approve(walletAddress, ethers.MaxUint256);
  
  // Lock CNGN in escrow
  const tx = await diamond.lockCNGN(amountCNGN, serviceCode, refId);
  await tx.wait();
  
  // Notify backend
  await api.post('/bills/pay', {
    refId: ethers.hexlify(refId),
    amount,
    billType,
    txHash: tx.hash
  });
  
  return refId;
}
```

**Backend:**
```typescript
// Listen for CNGNLocked event
diamond.on('CNGNLocked', async (user, amount, serviceCode, refId, event) => {
  console.log(`User ${user} locked ${ethers.formatUnits(amount, 18)} CNGN for ${ethers.hexlify(refId)}`);
  
  // Process bill payment with third-party provider
  const success = await processWithProvider(refId, amount);
  
  if (success) {
    // Complete escrow → sends CNGN to merchant
    await diamond.completeEscrow(refId);
  } else {
    // Refund user
    await diamond.refundCNGN(refId);
  }
});
```

---

### 4. Create Session Key (One-Tap Transactions)

**User Flow:** User creates session key → Can transact without signing each time

**Frontend:**
```typescript
async function createSessionKey(duration: number = 86400) { // 24 hours default
  const sessionKeyWallet = ethers.Wallet.createRandom();
  const sessionKeyAddress = sessionKeyWallet.address;
  
  // Define allowed functions
  const allowedSelectors = [
    ethers.id('lockCNGN(uint256,bytes32,bytes32)').slice(0, 10),
    ethers.id('swapExactTokensForTokens(address,address,uint256,uint256,address)').slice(0, 10)
  ];
  
  const maxAmount = ethers.parseEther('0.01'); // Max 0.01 ETH worth per tx
  
  const diamond = new ethers.Contract(walletAddress, DIAMOND_ABI, signer);
  const tx = await diamond.createSessionKey(
    sessionKeyAddress,
    duration, // seconds
    maxAmount,
    allowedSelectors
  );
  
  const receipt = await tx.wait();
  
  // Extract keyId from event
  const event = receipt.logs.find(log => 
    log.topics[0] === ethers.id('SessionKeyCreated(address,bytes32,uint256)')
  );
  const keyId = event.topics[2];
  
  // Store session key securely
  await SecureStore.setItemAsync('sessionKeyId', keyId);
  await SecureStore.setItemAsync('sessionKeyPrivate', sessionKeyWallet.privateKey);
  
  return { keyId, sessionKeyAddress };
}
```

**Using Session Key:**
```typescript
// Sign transaction with session key instead of user's main key
const sessionKeyPrivate = await SecureStore.getItemAsync('sessionKeyPrivate');
const sessionSigner = new ethers.Wallet(sessionKeyPrivate, provider);

const diamond = new ethers.Contract(walletAddress, DIAMOND_ABI, sessionSigner);
await diamond.lockCNGN(amount, serviceCode, refId); // No user prompt!
```

---

### 5. Swap Tokens (On-Chain DEX)

**User Flow:** User swaps USDT → CNGN

**Frontend:**
```typescript
async function swapTokens(
  tokenIn: string, // USDT address
  tokenOut: string, // CNGN address
  amountIn: string
) {
  const amountInWei = ethers.parseUnits(amountIn, 6); // USDT has 6 decimals
  const minAmountOut = calculateMinOut(amountInWei, slippage); // 0.5% slippage
  
  const diamond = new ethers.Contract(walletAddress, DIAMOND_ABI, signer);
  
  // Approve token spending
  const tokenInContract = new ethers.Contract(tokenIn, ERC20_ABI, signer);
  await tokenInContract.approve(walletAddress, amountInWei);
  
  // Execute swap
  const tx = await diamond.swapExactTokensForTokens(
    tokenIn,
    tokenOut,
    amountInWei,
    minAmountOut,
    walletAddress // recipient
  );
  
  await tx.wait();
  return tx.hash;
}
```

---

### 6. Add Social Recovery Guardians

**User Flow:** User adds trusted contacts who can recover account if lost

**Frontend:**
```typescript
async function addGuardian(guardianAddress: string) {
  const diamond = new ethers.Contract(walletAddress, DIAMOND_ABI, signer);
  const tx = await diamond.addGuardian(guardianAddress);
  await tx.wait();
  
  // Recommend 3-5 guardians
  const guardians = await diamond.getGuardians();
  return guardians;
}
```

**Recovery Flow (if user loses access):**
```typescript
// Guardian 1 initiates recovery
const diamond1 = new ethers.Contract(walletAddress, DIAMOND_ABI, guardian1Signer);
await diamond1.initiateRecovery(newOwnerAddress);

// Guardian 2 votes
const diamond2 = new ethers.Contract(walletAddress, DIAMOND_ABI, guardian2Signer);
await diamond2.voteRecovery(newOwnerAddress);

// Wait 3 days (recovery delay)
await sleep(3 * 24 * 60 * 60 * 1000);

// Execute recovery
await diamond1.executeRecovery(newOwnerAddress);
```

---

## API Reference

### ConfigFacet

#### `initializeApp(address treasury, address entryPoint, address cngn)`
**Purpose:** Initialize Diamond storage (called once after deployment)  
**Access:** Owner only  
**Gas:** ~70,000

**Example:**
```typescript
await diamond.initializeApp(TREASURY_ADDRESS, ENTRY_POINT_ADDRESS, CNGN_ADDRESS);
```

#### `getTreasury() → address`
**Purpose:** Get treasury address  
**Gas:** ~2,400

#### `getCNGN() → address`
**Purpose:** Get CNGN token address  
**Gas:** ~2,400

---

### EscrowFacet

#### `lockCNGN(uint256 amount, bytes32 serviceCode, bytes32 refId)`
**Purpose:** Lock CNGN for bill payment  
**Access:** Anyone  
**Emits:** `CNGNLocked(address user, uint256 amount, bytes32 serviceCode, bytes32 refId)`  
**Gas:** ~145,000

**Parameters:**
- `amount`: Amount in wei (18 decimals)
- `serviceCode`: keccak256 of bill type (e.g., "ELECTRIC", "DATA")
- `refId`: Unique reference ID for this transaction

**Example:**
```typescript
const amount = ethers.parseUnits('5000', 18); // 5000 CNGN
const serviceCode = ethers.keccak256(ethers.toUtf8Bytes('ELECTRIC_BILL'));
const refId = ethers.keccak256(ethers.toUtf8Bytes(`REF-${Date.now()}`));

await diamond.lockCNGN(amount, serviceCode, refId);
```

#### `refundCNGN(bytes32 refId)`
**Purpose:** Refund locked CNGN to user  
**Access:** Owner only (backend)  
**Gas:** ~32,000

#### `completeEscrow(bytes32 refId)`
**Purpose:** Release CNGN to treasury (payment successful)  
**Access:** Owner only (backend)  
**Gas:** ~47,000

---

### SessionKeyFacet

#### `createSessionKey(address key, uint256 duration, uint256 maxAmount, bytes4[] calldata allowedFunctions) → bytes32 keyId`
**Purpose:** Create time-limited key for gasless transactions  
**Access:** Owner only  
**Returns:** Session key ID  
**Gas:** ~220,000

**Parameters:**
- `key`: Address of session key
- `duration`: Validity period in seconds (e.g., 86400 = 24 hours)
- `maxAmount`: Max value per transaction
- `allowedFunctions`: Array of function selectors this key can call

**Example:**
```typescript
const sessionKey = ethers.Wallet.createRandom();
const duration = 86400; // 24 hours
const maxAmount = ethers.parseEther('0.01');
const selectors = [
  ethers.id('lockCNGN(uint256,bytes32,bytes32)').slice(0, 10)
];

const keyId = await diamond.createSessionKey(
  sessionKey.address,
  duration,
  maxAmount,
  selectors
);
```

#### `revokeSessionKey(bytes32 keyId)`
**Purpose:** Revoke session key before expiry  
**Access:** Owner only  
**Gas:** ~45,000

#### `isValidSessionKey(bytes32 keyId, bytes4 selector, uint256 gasLimit) → bool`
**Purpose:** Check if session key is valid for a function call  
**Access:** View function  
**Gas:** Free (view)

---

### GuardianFacet

#### `addGuardian(address guardian)`
**Purpose:** Add trusted contact for social recovery  
**Access:** Owner only  
**Gas:** ~45,000

**Example:**
```typescript
await diamond.addGuardian('0x123...'); // Friend's address
```

#### `removeGuardian(address guardian)`
**Purpose:** Remove guardian  
**Access:** Owner only  
**Gas:** ~30,000

#### `initiateRecovery(address newOwner)`
**Purpose:** Guardian starts account recovery process  
**Access:** Guardian only  
**Gas:** ~50,000

#### `voteRecovery(address newOwner)`
**Purpose:** Guardian votes for recovery (need 2/3 majority)  
**Access:** Guardian only  
**Gas:** ~45,000

#### `executeRecovery(address newOwner)`
**Purpose:** Execute recovery after delay (3 days) and votes  
**Access:** Guardian only  
**Gas:** ~60,000

#### `getGuardians() → address[]`
**Purpose:** Get list of guardians  
**Access:** View function  
**Gas:** Free (view)

---

### PaymasterFacet

**Gas Sponsorship Rules:**
1. **Transaction Limit:** Only transactions costing < ₦10,000 (~0.005 ETH) are sponsored
2. **Daily Limit:** Maximum 10 sponsored transactions per day
3. **User Pays:** If transaction ≥ ₦10,000 OR daily limit exceeded, user pays with chosen token

#### `setMonthlyLimit(address user, uint256 newLimit)`
**Purpose:** Set monthly gas sponsorship limit (secondary check)  
**Access:** Owner only  
**Default:** 0.05 ETH (~₦100,000)  
**Gas:** ~50,000

#### `getGasUsage(address user) → (uint256 limit, uint256 used, uint256 lastReset, uint256 dailyCount, uint256 lastDailyReset)`
**Purpose:** Check user's gas sponsorship status  
**Access:** View function  
**Returns:**
- `limit`: Monthly gas limit
- `used`: Gas used this month
- `lastReset`: Last monthly reset timestamp
- `dailyCount`: Transactions sponsored today
- `lastDailyReset`: Last daily reset timestamp  
**Gas:** Free (view)

**Example:**
```typescript
const (limit, used, lastReset, dailyCount, lastDailyReset) = await diamond.getGasUsage(userAddress);
console.log(`Sponsored today: ${dailyCount}/10`);
console.log(`Remaining: ${10 - dailyCount} transactions`);
```

#### `getRemainingDailyTransactions(address user) → uint256`
**Purpose:** Get number of sponsored transactions remaining today  
**Access:** View function  
**Returns:** Number of transactions remaining (0-10)  
**Gas:** Free (view)

**Example:**
```typescript
const remaining = await diamond.getRemainingDailyTransactions(userAddress);
if (remaining === 0) {
  // User must pay with their own tokens
  console.log("Daily limit reached. Please pay with your tokens.");
} else {
  console.log(`You have ${remaining} free transactions remaining today`);
}
```

---

### SubscriptionFacet

#### `claimTrial()`
**Purpose:** Claim 7-day free trial (Tier 1)  
**Access:** Anyone (once per address)  
**Gas:** ~90,000

**Example:**
```typescript
await diamond.claimTrial();
```

#### `setTier(address user, uint8 tier)`
**Purpose:** Upgrade user tier (backend only)  
**Access:** Owner only  
**Gas:** ~95,000

**Tiers:**
- 0: FREE
- 1: TRIAL (7 days)
- 2: BASIC
- 3: PREMIUM

#### `getTier(address user) → uint8`
**Purpose:** Get user's current tier  
**Access:** View function  
**Gas:** Free (view)

---

### SwapFacet

#### `swapExactTokensForTokens(address tokenIn, address tokenOut, uint256 amountIn, uint256 minAmountOut, address recipient) → uint256[] amounts`
**Purpose:** Swap ERC20 → ERC20 via DEX  
**Access:** Anyone  
**Gas:** ~150,000

**Example:**
```typescript
const usdt = '0x...';
const cngn = '0x...';
const amountIn = ethers.parseUnits('100', 6); // 100 USDT
const minOut = ethers.parseUnits('95000', 18); // Min 95,000 CNGN (5% slippage)

await diamond.swapExactTokensForTokens(usdt, cngn, amountIn, minOut, walletAddress);
```

#### `swapExactNativeForTokens(address tokenOut, uint256 minAmountOut, address recipient) → uint256[] amounts`
**Purpose:** Swap ETH → ERC20  
**Access:** Anyone (send ETH in transaction)  
**Gas:** ~140,000

#### `getAmountsOut(address tokenIn, address tokenOut, uint256 amountIn) → uint256[]`
**Purpose:** Calculate expected output amount  
**Access:** View function  
**Gas:** Free (view)

---

### SwapEscrowFacet

#### `depositAndLock(address token, uint256 amount, bytes32 refId)`
**Purpose:** Deposit crypto for off-chain swap to CNGN  
**Access:** Anyone  
**Gas:** ~120,000

**Example:**
```typescript
// User deposits USDT, backend swaps to CNGN off-chain, then fulfills
const refId = ethers.keccak256(ethers.toUtf8Bytes(`SWAP-${Date.now()}`));
await diamond.depositAndLock(USDT_ADDRESS, ethers.parseUnits('100', 6), refId);
```

#### `fulfillSwapToCNGN(bytes32 refId, uint256 amountCNGN)`
**Purpose:** Backend fulfills swap by sending CNGN  
**Access:** Owner only (backend)  
**Gas:** ~80,000

---

### ImportFacet

#### `linkImportedAddress(address importedAddress, uint8 walletType)`
**Purpose:** Link imported EOA to Diamond  
**Access:** Owner only  
**Gas:** ~75,000

**Parameters:**
- `importedAddress`: Address derived from seed phrase
- `walletType`: 0=EOA, 1=SmartWallet, 2=Hardware

**Example:**
```typescript
const imported = '0xabc...'; // From seed phrase
await diamond.linkImportedAddress(imported, 0); // 0 = EOA
```

#### `getImportInfo() → (bool isImported, address importedAddress)`
**Purpose:** Check if wallet was imported  
**Access:** View function  
**Gas:** Free (view)

#### `isAuthorizedSigner(address signer) → bool`
**Purpose:** Check if address can sign for this Diamond  
**Returns:** True for owner or imported address  
**Access:** View function  
**Gas:** Free (view)

---

## Integration Examples

### Complete User Journey

```typescript
// 1. User signs up
const user = await auth.signup(email, password);

// 2. Backend creates wallet
const { diamondAddress } = await api.post('/wallets/create', {
  userAddress: user.address
});

// 3. User claims trial
const diamond = new ethers.Contract(diamondAddress, DIAMOND_ABI, signer);
await diamond.claimTrial();

// 4. User creates session key for one-tap
const { keyId } = await createSessionKey(86400); // 24 hours

// 5. User pays bill (no signature needed - uses session key!)
await payBillWithSessionKey(5000, 'ELECTRIC');

// 6. User swaps USDT to CNGN
await swapTokens(USDT_ADDRESS, CNGN_ADDRESS, '100');

// 7. User adds guardians for recovery
await addGuardian(friend1Address);
await addGuardian(friend2Address);
await addGuardian(friend3Address);
```

---

## Error Handling

### Common Errors

#### `LibDiamond: Must be contract owner`
**Cause:** Function requires owner privileges  
**Fix:** Ensure signer is the Diamond owner

```typescript
// Check owner first
const owner = await diamond.owner();
if (owner !== signerAddress) {
  throw new Error('Not authorized');
}
```

#### `UnsupportedToken(address token)`
**Cause:** Token not whitelisted  
**Fix:** Add token to supported list

```typescript
await diamond.setSupportedToken(tokenAddress, true);
```

#### `GasLimitExceeded(uint256 attempted, uint256 remaining)`
**Cause:** User exceeded monthly gas sponsorship  
**Fix:** Wait for monthly reset or upgrade tier

```typescript
const { limit, used, lastReset } = await diamond.getGasUsage(userAddress);
if (used >= limit) {
  // Notify user to upgrade or wait
  throw new Error(`Gas limit exceeded. Used: ${used}, Limit: ${limit}`);
}
```

#### `SessionKeyExpired(bytes32 keyId)`
**Cause:** Session key past expiry  
**Fix:** Create new session key

```typescript
await revokeSessionKey(oldKeyId);
const { keyId: newKeyId } = await createSessionKey(86400);
```

---

## Gas Optimization

### Estimated Gas Costs

| Function | Gas | Cost (at 20 gwei) | Cost (₦) |
|---|---|---|---|
| `createWallet` | 1,987,870 | 0.0398 ETH | ₦79,600 |
| `lockCNGN` | 143,194 | 0.0029 ETH | ₦5,800 |
| `createSessionKey` | 220,886 | 0.0044 ETH | ₦8,800 |
| `swapTokens` | ~150,000 | 0.003 ETH | ₦6,000 |
| `completeEscrow` | 46,958 | 0.0009 ETH | ₦1,800 |
| `claimTrial` | 91,485 | 0.0018 ETH | ₦3,600 |

### Optimization Tips

1. **Batch Operations:** Use `batchExecute` to combine multiple calls
2. **Session Keys:** Users pay gas once for session key, then gasless txs
3. **Gas Sponsorship:** Paymaster covers up to ₦10,000/month for eligible users
4. **Approve Once:** `approve(MaxUint256)` so users don't approve every time

---

## Event Listening

### Subscribe to Events (Backend)

```typescript
const diamond = new ethers.Contract(DIAMOND_ADDRESS, DIAMOND_ABI, provider);

// Bill payment locked
diamond.on('CNGNLocked', async (user, amount, serviceCode, refId) => {
  console.log(`Escrow created: ${ethers.formatUnits(amount, 18)} CNGN`);
  await processBillPayment(refId);
});

// Session key created
diamond.on('SessionKeyCreated', (user, keyId, expiry) => {
  console.log(`Session key ${keyId} valid until ${new Date(expiry * 1000)}`);
});

// Guardian added
diamond.on('GuardianAdded', (guardian, timestamp) => {
  console.log(`New guardian: ${guardian}`);
  await notifyUser(`Guardian ${guardian} added to your account`);
});
```

---

## Testing

### Local Testing with Anvil

```bash
# Start local node
anvil

# Deploy contracts
forge script script/DeployCPPayComplete.s.sol --rpc-url http://localhost:8545 --broadcast

# Run tests
forge test -vvv
```

### Frontend Testing
```typescript
// Use testnet addresses
const TESTNET_FACTORY = '0x...';
const TESTNET_CNGN = '0x...';

// Connect to Lisk testnet
const provider = new ethers.JsonRpcProvider('https://rpc-testnet.lisk.com');

// Test user flow
await testCreateWallet();
await testClaimTrial();
await testPayBill();
```

---

## Security Considerations

### Frontend
- **Never** expose private keys in code
- Store encrypted keys with user PIN/biometric
- Validate all addresses before transactions
- Show transaction preview before signing
- Implement rate limiting on session keys

### Backend
- Keep owner private key in HSM/KMS
- Use multi-sig for treasury operations
- Monitor escrow events for fraud
- Implement withdrawal limits
- Log all admin actions

---

## Support

### Documentation
- **Architecture:** See `SC ARCHITECTURE.md`
- **Flows:** See `CPPAY-FLOW.md`
- **PRD:** See `PRDCPPay.md`

### Contact
- **Smart Contract Issues:** [GitHub Issues](https://github.com/CP-Pay/smart-contract/issues)
- **Integration Help:** dev@cppay.io
- **Security:** security@cppay.io

---

**END OF IMPLEMENTATION GUIDE**
