import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

/**
 * Ignition deployment module for the SwapRouter contract.
 */
const SwapRouterModule = buildModule("SwapRouterModule", (m) => {
  const deployer = m.getAccount(0);
  const admin = m.getParameter("admin", deployer);

  const swapRouter = m.contract("SwapRouter", [admin]);

  return { swapRouter };
});

export default SwapRouterModule;
