import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

/**
 * Deployment module for CPPayPaymaster contract
 * 
 * To deploy:
 * npx hardhat ignition deploy ignition/modules/CPPayPaymaster.ts --network lisk --deployment-id cppay-paymaster-deployment
 * 
 * To verify:
 * npx hardhat verify --network lisk <CONTRACT_ADDRESS> <ENTRY_POINT_ADDRESS>
 */
const CPPayPaymasterModule = buildModule("CPPayPaymasterModule", (m) => {
  // EntryPoint address - you need to provide the actual EntryPoint address for your network
  // For Lisk Sepolia, you'll need to deploy or use an existing EntryPoint
  // Common EntryPoint v0.6: 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789
  const entryPointAddress = m.getParameter(
    "entryPoint",
    "0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789"
  );

  // Deploy the CPPayPaymaster contract
  const paymaster = m.contract("CPPayPaymaster", [entryPointAddress]);

  return { paymaster };
});

export default CPPayPaymasterModule;
