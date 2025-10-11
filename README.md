# CPPay Smart Contracts

Web2-Level UX for Crypto Payments with Account Abstraction using Diamond Standard (EIP-2535)

## Overview

CPPay implements a modular, upgradeable smart contract system using the Diamond Standard (EIP-2535) combined with Account Abstraction (ERC-4337) to enable:

- ✅ Smart contract wallets for each user
- ✅ Gasless transactions via paymaster
- ✅ Social recovery through guardians
- ✅ Session keys for seamless flows
- ✅ Batch operations
- ✅ Pay-with-any-token functionality
- ✅ Modular, upgradeable architecture

## Architecture

```
CPPayDiamond (Main Contract)
├── DiamondCutFacet (Upgrade management)
├── DiamondLoupeFacet (Introspection)
├── OwnershipFacet (Ownership management)
├── AccountFacet (ERC-4337 Account Abstraction)
├── GuardianFacet (Social recovery)
├── SessionKeyFacet (Temporary permissions)
├── PaymasterFacet (Gas sponsorship)
└── UtilityFacet (Admin & emergency functions)
```

## Setup

```bash
# Install dependencies
forge install

# Build contracts
forge build

# Run tests
forge test

# Deploy to local network
forge script script/DeployCPPay.s.sol:DeployCPPay --rpc-url http://localhost:8545 --broadcast

# Deploy to testnet (e.g., Sepolia)
forge script script/DeployCPPay.s.sol:DeployCPPay --rpc-url $SEPOLIA_RPC_URL --broadcast --verify
```

## Environment Variables

Create a `.env` file:

```env
PRIVATE_KEY=your_private_key_here
SEPOLIA_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/YOUR_KEY
ETHERSCAN_API_KEY=your_etherscan_api_key
```

## Core Facets

### 1. AccountFacet
ERC-4337 compliant account abstraction implementation:
- `initialize(owner, entryPoint)` - Set up user wallet
- `validateUserOp()` - Validate user operations
- `execute()` - Execute single transaction
- `executeBatch()` - Execute multiple transactions
- `setExecutor()` - Approve session keys

### 2. GuardianFacet
Social recovery system:
- `addGuardian()` - Add trusted guardian
- `removeGuardian()` - Remove guardian
- `setThreshold()` - Set required guardian votes
- `initiateRecovery()` - Guardian votes for recovery
- `executeRecovery()` - Execute ownership transfer
- `cancelRecovery()` - Cancel active recovery

### 3. SessionKeyFacet
Temporary permission system:
- `createSession()` - Create time-limited session
- `executeWithSession()` - Execute using session key
- `revokeSession()` - Revoke session manually
- `isSessionValid()` - Check session status

### 4. PaymasterFacet
Gas sponsorship:
- `initializePaymaster()` - Set up paymaster
- `validatePaymasterUserOp()` - Validate & sponsor gas
- `setUserTier()` - Set sponsorship tier
- `deposit()` - Fund paymaster
- `withdraw()` - Withdraw funds

### 5. UtilityFacet
Administrative functions:
- `pause()` / `unpause()` - Emergency pause
- `addAdmin()` - Add admin role
- `blacklistUser()` - Block malicious users
- `requestEmergencyWithdrawal()` - Emergency fund recovery

## Testing

```bash
# Run all tests
forge test

# Run specific test
forge test --match-test testAccountInitialization

# Run with gas report
forge test --gas-report

# Run with coverage
forge coverage
```

## Security Features

1. **Diamond Storage Pattern**: Prevents storage collisions
2. **Access Control**: Owner, admin, and guardian roles
3. **Time Locks**: 48-hour delay for recovery
4. **Pause Mechanism**: Emergency pause functionality
5. **Blacklist System**: Block malicious actors
6. **Upgradeability**: Add/remove facets without migration

## Deployment Addresses

### Ethereum Sepolia
- Diamond: `TBD`
- AccountFacet: `TBD`
- GuardianFacet: `TBD`
- SessionKeyFacet: `TBD`
- PaymasterFacet: `TBD`

### BSC Testnet
- Diamond: `TBD`

### Polygon Mumbai
- Diamond: `TBD`

## License

MIT License - see LICENSE file for details

## Contributing

Contributions welcome! Please open an issue or submit a PR.

## Resources

- [EIP-2535 Diamond Standard](https://eips.ethereum.org/EIPS/eip-2535)
- [ERC-4337 Account Abstraction](https://eips.ethereum.org/EIPS/eip-4337)
- [Diamond-3 Reference](https://github.com/mudgen/diamond-3)
