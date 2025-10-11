# CPPay Smart Contract Deployment Guide

## Prerequisites

1. **Install Foundry**
```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

2. **Clone and Setup**
```bash
cd /home/bilal/bilal_projects/CPPay/smart-contract
forge install
cp .env.example .env
```

3. **Configure Environment**
Edit `.env` with your actual values:
- Replace `PRIVATE_KEY` with deployer wallet private key
- Add RPC URLs from Alchemy/Infura
- Add block explorer API keys

## Build & Test

```bash
# Build contracts
forge build

# Run tests
forge test -vvv

# Generate gas report
forge test --gas-report

# Check coverage
forge coverage
```

## Local Deployment (Anvil)

```bash
# Terminal 1: Start local node
anvil

# Terminal 2: Deploy
forge script script/DeployCPPay.s.sol:DeployCPPay \
  --rpc-url http://localhost:8545 \
  --broadcast
```

## Testnet Deployment

### Ethereum Sepolia
```bash
forge script script/DeployCPPay.s.sol:DeployCPPay \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  --verify \
  --etherscan-api-key $ETHERSCAN_API_KEY
```

### BSC Testnet
```bash
forge script script/DeployCPPay.s.sol:DeployCPPay \
  --rpc-url $BSC_TESTNET_RPC_URL \
  --broadcast \
  --verify \
  --etherscan-api-key $BSCSCAN_API_KEY
```

### Polygon Mumbai
```bash
forge script script/DeployCPPay.s.sol:DeployCPPay \
  --rpc-url $POLYGON_MUMBAI_RPC_URL \
  --broadcast \
  --verify \
  --etherscan-api-key $POLYGONSCAN_API_KEY
```

## Mainnet Deployment

⚠️ **CRITICAL: Double-check everything before mainnet deployment!**

```bash
# Dry run first
forge script script/DeployCPPay.s.sol:DeployCPPay \
  --rpc-url $MAINNET_RPC_URL

# Actual deployment
forge script script/DeployCPPay.s.sol:DeployCPPay \
  --rpc-url $MAINNET_RPC_URL \
  --broadcast \
  --verify \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --legacy
```

## Post-Deployment Steps

### 1. Initialize Account Facet
```solidity
// Using cast
cast send <DIAMOND_ADDRESS> \
  "initialize(address,address)" \
  <OWNER_ADDRESS> \
  <ENTRYPOINT_ADDRESS> \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY
```

### 2. Initialize Paymaster
```solidity
cast send <DIAMOND_ADDRESS> \
  "initializePaymaster(address,address)" \
  <ENTRYPOINT_ADDRESS> \
  <PAYMASTER_OWNER> \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY
```

### 3. Fund Paymaster
```bash
cast send <DIAMOND_ADDRESS> \
  "deposit()" \
  --value 1ether \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY
```

### 4. Set User Tiers
```bash
# Basic tier (tier 1)
cast send <DIAMOND_ADDRESS> \
  "setUserTier(address,uint8,bool)" \
  <USER_ADDRESS> \
  1 \
  true \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY
```

### 5. Add Guardians (For Recovery)
```bash
cast send <DIAMOND_ADDRESS> \
  "addGuardian(address)" \
  <GUARDIAN_ADDRESS> \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY

# Set threshold
cast send <DIAMOND_ADDRESS> \
  "setThreshold(uint256)" \
  2 \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY
```

## Verification

### Verify Diamond
```bash
forge verify-contract \
  --chain-id 11155111 \
  --num-of-optimizations 200 \
  --watch \
  --constructor-args $(cast abi-encode "constructor((address,uint8,bytes4[])[],address)" "[]" "<OWNER>") \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --compiler-version v0.8.20 \
  <DIAMOND_ADDRESS> \
  contracts/CPPayDiamond.sol:CPPayDiamond
```

### Verify Facets
```bash
# DiamondCutFacet
forge verify-contract <FACET_ADDRESS> \
  contracts/facets/DiamondCutFacet.sol:DiamondCutFacet \
  --chain-id 11155111 \
  --etherscan-api-key $ETHERSCAN_API_KEY
```

## Interaction Examples

### Execute Transaction
```bash
cast send <DIAMOND_ADDRESS> \
  "execute(address,uint256,bytes)" \
  <TARGET_ADDRESS> \
  0 \
  "0x" \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY
```

### Create Session Key
```bash
cast send <DIAMOND_ADDRESS> \
  "createSession(address,uint256,uint256,bytes4[])" \
  <SESSION_KEY_ADDRESS> \
  86400 \
  1000000000000000000 \
  "[0x12345678]" \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY
```

### Query Diamond Info
```bash
# Get all facets
cast call <DIAMOND_ADDRESS> "facets()" --rpc-url $SEPOLIA_RPC_URL

# Get owner
cast call <DIAMOND_ADDRESS> "owner()" --rpc-url $SEPOLIA_RPC_URL

# Get guardians
cast call <DIAMOND_ADDRESS> "getGuardians()" --rpc-url $SEPOLIA_RPC_URL
```

## Upgrading Diamond

### Add New Facet
```bash
# 1. Deploy new facet
forge create contracts/facets/NewFacet.sol:NewFacet \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY

# 2. Prepare diamondCut call
# 3. Execute via DiamondCutFacet
cast send <DIAMOND_ADDRESS> \
  "diamondCut((address,uint8,bytes4[])[],address,bytes)" \
  "[(FACET_ADDRESS,0,[SELECTORS])]" \
  "0x0000000000000000000000000000000000000000" \
  "0x" \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY
```

## Monitoring

### Events to Monitor
- `AccountInitialized`
- `GuardianAdded`
- `RecoveryInitiated`
- `SessionCreated`
- `GasSponsored`
- `DiamondCut`

### Using cast to watch events
```bash
cast logs --address <DIAMOND_ADDRESS> \
  --rpc-url $SEPOLIA_RPC_URL \
  --from-block latest
```

## Troubleshooting

### Issue: "Function does not exist"
- Ensure facet is properly added via DiamondCut
- Check function selector is registered

### Issue: "Not authorized"
- Verify caller has correct role (owner, admin, guardian)
- Check account initialization

### Issue: Gas estimation failed
- Ensure sufficient funds in paymaster
- Check user tier is enabled
- Verify daily limits not exceeded

## Security Checklist

- [ ] All facets deployed and verified
- [ ] Owner is multisig wallet
- [ ] Guardians configured correctly
- [ ] Paymaster funded adequately
- [ ] Admin roles assigned securely
- [ ] Emergency pause tested
- [ ] Recovery flow tested
- [ ] Session key limits verified
- [ ] All tests passing
- [ ] Code audit completed (for mainnet)

## Support

For issues or questions:
- GitHub Issues: https://github.com/CP-Pay/smart-contract/issues
- Discord: [Your Discord]
- Email: dev@cppay.com
