import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

/**
 * Deployment module for SessionKeyModule contract
 * 
 * To deploy:
 * npx hardhat ignition deploy ignition/modules/SessionKeyModule.ts --network lisk --deployment-id cppay-sessionkey-deployment
 * 
 * To verify:
 * npx hardhat verify --network lisk <CONTRACT_ADDRESS>
 */
const SessionKeyModuleModule = buildModule("SessionKeyModuleModule", (m) => {
  // Deploy the SessionKeyModule contract
  const sessionKeyModule = m.contract("SessionKeyModule");

  return { sessionKeyModule };
});

export default SessionKeyModuleModule;
