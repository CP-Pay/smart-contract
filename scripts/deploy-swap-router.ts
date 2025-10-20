import { ethers, ignition } from "hardhat";
import SwapRouterModule from "../ignition/modules/SwapRouterModule";

async function main() {
  const [defaultAdmin] = await ethers.getSigners();
  const adminAddress = process.env.SWAP_ROUTER_ADMIN ?? defaultAdmin.address;

  if (!adminAddress) {
    throw new Error("Admin address is required. Provide SWAP_ROUTER_ADMIN or configure an account in Hardhat.");
  }

  const deployment = await ignition.deploy(SwapRouterModule, {
    deploymentId: "cppay-swap-router-script",
    parameters: {
      SwapRouterModule: {
        admin: adminAddress,
      },
    },
  });

  const swapRouterAddress = await deployment.swapRouter.getAddress();
  console.log("SwapRouter deployed to:", swapRouterAddress);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
