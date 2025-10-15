# CPPay Production Setup Guide

## Overview
This guide provides the complete setup process for deploying and integrating CPPay smart contracts in production.

## Critical Components

### 1. Smart Contracts
- **CPPayDiamond**: Main account contract (ERC-4337 compliant)
- **CPPayFactory**: Factory for creating new Diamond accounts
- **Facets**: Modular functionality (Account, Paymaster, Config, Guardian, etc.)

### 2. Initialization Requirements

All Diamond wallets require proper initialization to function correctly:

#### A. Core Initialization (InitDiamond)
```solidity
InitDiamond.init(
    owner,        // Wallet owner address
    entryPoint,   // ERC-4337 EntryPoint address (0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789 on mainnet)
    treasury,     // Protocol treasury address
    cngn          // CNGN token address
);
```

This initializes:
- Diamond ownership
- App storage (treasury, entryPoint, CNGN)
- Account storage
- Paymaster storage (EntryPoint reference)
- Utility storage (owner as first admin)

#### B. Alternative: Individual Facet Initialization

If not using InitDiamond, initialize each facet separately:

```solidity
// 1. Config Facet
ConfigFacet.initializeApp(treasury, entryPoint, cngn);

// 2. Paymaster Facet
PaymasterFacet.initializePaymaster(entryPoint);

// 3. Utility Facet (optional, for admin features)
UtilityFacet.initializeUtility(); // Sets contract owner as first admin
```

## Deployment Sequence

### Step 1: Deploy Core Contracts

```bash
# Deploy all facets
forge script script/DeployCPPayComplete.s.sol:DeployCPPayComplete --rpc-url $RPC_URL --broadcast --verify

# Or manually:
# 1. Deploy facets (DiamondCutFacet, DiamondLoupeFacet, AccountFacet, etc.)
# 2. Deploy InitDiamond
# 3. Deploy CPPayFactory
```

### Step 2: Verify Deployment

```solidity
// Check factory
address factory = <DEPLOYED_FACTORY_ADDRESS>;
assert(CPPayFactory(factory).owner() == deployer);
assert(CPPayFactory(factory).entryPoint() == ENTRYPOINT);
assert(CPPayFactory(factory).treasury() == TREASURY);

// Check facets are deployed
assert(accountFacet.code.length > 0);
assert(paymasterFacet.code.length > 0);
// ... etc
```

### Step 3: Create User Wallets

```solidity
// Prepare facet cuts (which facets to include)
IDiamondCut.FacetCut[] memory cuts = prepareFacetCuts();

// Option A: Standard wallet
address userWallet = factory.createWallet(userAddress, cuts, "");

// Option B: Imported wallet (from seed phrase)
address importedWallet = factory.createImportedWallet(
    userAddress,
    importedEOAAddress,
    walletType,  // 0=EOA, 1=SmartWallet, 2=Hardware
    cuts,
    ""
);

// Option C: Deterministic wallet (CREATE2)
bytes32 salt = keccak256(abi.encodePacked(userAddress, nonce));
address predictedAddress = factory.computeAddress(userAddress, cuts, salt);
address deterministicWallet = factory.createWalletDeterministic(userAddress, cuts, salt);
assert(deterministicWallet == predictedAddress);
```

### Step 4: Initialize Created Wallet

**CRITICAL**: After creating a wallet, it MUST be initialized before use.

```solidity
// Get the wallet address
address wallet = factory.createWallet(user, cuts, "");

// Initialize with InitDiamond (if included in facet cuts)
bytes memory initData = abi.encodeWithSelector(
    InitDiamond.init.selector,
    user,
    entryPoint,
    treasury,
    cngn
);

// OR initialize via ConfigFacet
ConfigFacet(wallet).initializeApp(treasury, entryPoint, cngn);
PaymasterFacet(wallet).initializePaymaster(entryPoint);
```

## Gas Sponsorship System

### Configuration

The Paymaster automatically sponsors transactions based on these rules:

```solidity
// Constants (in PaymasterFacet.sol)
MAX_DAILY_SPONSORED_TXS = 10;           // Max sponsored txs per day
SPONSORED_TX_THRESHOLD = 0.005 ether;   // ~₦10,000 at ₦2M/ETH

// Reset time
DAILY_RESET_TIME = midnight UTC (0:00)
```

### Sponsorship Rules

A transaction is sponsored if ALL conditions are met:
1. **Transaction cost < ₦10,000** (< 0.005 ETH)
2. **Daily limit not exceeded** (< 10 transactions today)
3. **Not after midnight** (resets daily)

### Frontend Integration

```typescript
// Check if user can get sponsored transaction
const remaining = await paymasterFacet.getRemainingDailyTransactions(userAddress);

if (remaining > 0) {
  // User has sponsored transactions available
  console.log(`${remaining} sponsored transactions remaining today`);
}

// Get detailed gas usage
const [totalUsed, limit, remaining, dailyCount, lastReset] = 
  await paymasterFacet.getGasUsage(userAddress);

// Build UserOperation with paymaster
const userOp = {
  sender: userAddress,
  nonce: await entryPoint.getNonce(userAddress, 0),
  initCode: "0x",
  callData: encodedCallData,
  callGasLimit: 100000,
  verificationGasLimit: 100000,
  preVerificationGas: 21000,
  maxFeePerGas: await getGasPrice(),
  maxPriorityFeePerGas: await getGasPrice(),
  paymasterAndData: paymasterAddress + "0".repeat(40), // Paymaster address
  signature: "0x" // Add signature
};

// Submit to EntryPoint
await entryPoint.handleOps([userOp], beneficiary);
```

## Backend Integration Points

### 1. Wallet Creation

```typescript
// Backend API endpoint: POST /api/wallets/create
async function createWallet(userAddress: string) {
  // Prepare facet cuts (standard set)
  const cuts = await prepareFacetCuts();
  
  // Create wallet via factory
  const tx = await factory.createWallet(userAddress, cuts, "0x");
  const receipt = await tx.wait();
  
  // Extract wallet address from WalletCreated event
  const event = receipt.events.find(e => e.event === "WalletCreated");
  const walletAddress = event.args.diamond;
  
  // Initialize wallet
  await initializeWallet(walletAddress, userAddress);
  
  // Store in database
  await db.wallets.create({
    userAddress,
    walletAddress,
    createdAt: Date.now(),
    status: 'active'
  });
  
  return { walletAddress };
}
```

### 2. Transaction Monitoring

```typescript
// Listen for gas sponsorship events
paymasterFacet.on("GasSponsored", (user, amount, txHash) => {
  console.log(`Sponsored ${amount} for ${user} in ${txHash}`);
  
  // Update analytics
  await analytics.recordSponsoredTx(user, amount);
});

// Monitor daily limits
async function checkDailyLimits() {
  const users = await db.users.getActive();
  
  for (const user of users) {
    const remaining = await paymasterFacet.getRemainingDailyTransactions(user.address);
    
    if (remaining === 0) {
      // Notify user they've hit the limit
      await notifications.send(user, "Daily sponsored transaction limit reached");
    }
  }
}
```

### 3. Admin Operations

```typescript
// Treasury management
await factory.setTreasury(newTreasuryAddress); // Only owner

// Emergency pause
const utilityFacet = UtilityFacet__factory.connect(walletAddress, admin);
await utilityFacet.pause(); // Only admin

// Blacklist malicious user
await utilityFacet.blacklistUser(maliciousAddress); // Only admin

// Resume operations
await utilityFacet.unpause(); // Only admin
```

## Security Considerations

### 1. Access Control
- **Owner**: Full control over Diamond (set via LibDiamond)
- **Admin**: Can pause, blacklist users (set via UtilityFacet)
- **EntryPoint**: Only authorized caller for paymaster operations

### 2. Initialization Guards
- All initialization functions have `initialized` checks
- Can only be called once
- Must be called by authorized address (owner/admin)

### 3. Daily Limits
- 10 sponsored transactions per user per day
- Resets at midnight UTC
- Cannot be bypassed without contract upgrade

### 4. Emergency Procedures

```solidity
// 1. Pause all operations
UtilityFacet.pause();

// 2. Request emergency withdrawal (48-hour delay)
UtilityFacet.requestEmergencyWithdrawal();

// 3. After delay, execute withdrawal
UtilityFacet.executeEmergencyWithdrawal();
```

## Testing Checklist

Before production deployment:

- [ ] All facets deployed and verified
- [ ] Factory initialized with correct parameters
- [ ] Test wallet creation and initialization
- [ ] Verify gas sponsorship works (< ₦10,000)
- [ ] Verify gas sponsorship rejects (> ₦10,000)
- [ ] Test daily limit enforcement
- [ ] Test daily limit reset
- [ ] Verify admin functions (pause/unpause)
- [ ] Test emergency withdrawal flow
- [ ] Verify EntryPoint integration
- [ ] Load test with multiple concurrent users

## Common Issues & Solutions

### Issue: "Paymaster: not EntryPoint"
**Solution**: Ensure PaymasterFacet is initialized with `initializePaymaster(entryPoint)`

### Issue: "Utility: not admin"
**Solution**: Initialize UtilityFacet with `initializeUtility()` to set owner as first admin

### Issue: "Diamond: Function does not exist"
**Solution**: Ensure all required facets are added via DiamondCut before calling functions

### Issue: Gas sponsorship not working
**Solution**: 
1. Check transaction cost is < 0.005 ETH
2. Check user hasn't exceeded 10 daily transactions
3. Verify paymaster has sufficient balance
4. Ensure EntryPoint is correctly set

## Support & Resources

- **Documentation**: `/docs`
- **Test Suite**: `forge test`
- **Coverage Report**: `forge coverage --ir-minimum`
- **Gas Report**: `forge test --gas-report`

## Contact

For production deployment support:
- Technical: dev@cppay.com
- Security: security@cppay.com
