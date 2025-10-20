import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

/**
 * Deployment module for all CPPay contracts
 * 
 * To deploy all contracts:
 * npx hardhat ignition deploy ignition/modules/DeployAll.ts --network lisk --deployment-id cppay-full-deployment
 * 
 * To verify individual contracts:
 * npx hardhat verify --network lisk <PAYMASTER_ADDRESS> <ENTRY_POINT_ADDRESS>
 * npx hardhat verify --network lisk <SESSION_KEY_MODULE_ADDRESS>
 */
const DeployAllModule = buildModule("DeployAllModule", (m) => {
  // EntryPoint address for Account Abstraction
  // Common EntryPoint v0.6: 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789
  const entryPointAddress = m.getParameter(
    "entryPoint",
    "0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789"
  );

  const adminAccount = m.getParameter("admin", m.getAccount(0));

  // Deploy SessionKeyModule
  const sessionKeyModule = m.contract("SessionKeyModule");

  // Deploy CPPayPaymaster
  const paymaster = m.contract("CPPayPaymaster", [entryPointAddress]);

  // Deploy SwapRouter
  const swapRouter = m.contract("SwapRouter", [adminAccount]);

  // Deploy BillPaymentAdapter
  const billPaymentAdapter = m.contract("BillPaymentAdapter", [adminAccount]);

  return { 
    sessionKeyModule,
    paymaster,
    swapRouter,
    billPaymentAdapter,
  };
});

export default DeployAllModule;
