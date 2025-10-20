import { ethers, ignition } from "hardhat";
import BillPaymentAdapterModule from "../ignition/modules/BillPaymentAdapterModule";

async function main() {
  const [defaultAdmin] = await ethers.getSigners();
  const adminAddress = process.env.BILL_PAYMENT_ADAPTER_ADMIN ?? defaultAdmin.address;

  if (!adminAddress) {
    throw new Error("Admin address is required. Provide BILL_PAYMENT_ADAPTER_ADMIN or configure an account in Hardhat.");
  }

  const deployment = await ignition.deploy(BillPaymentAdapterModule, {
    deploymentId: "cppay-bill-payment-adapter-script",
    parameters: {
      BillPaymentAdapterModule: {
        admin: adminAddress,
      },
    },
  });

  const billAdapterAddress = await deployment.billPaymentAdapter.getAddress();
  console.log("BillPaymentAdapter deployed to:", billAdapterAddress);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
