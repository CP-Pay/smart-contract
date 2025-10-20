import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

/**
 * Ignition deployment module for the BillPaymentAdapter contract.
 */
const BillPaymentAdapterModule = buildModule("BillPaymentAdapterModule", (m) => {
  const deployer = m.getAccount(0);
  const admin = m.getParameter("admin", deployer);

  const billPaymentAdapter = m.contract("BillPaymentAdapter", [admin]);

  return { billPaymentAdapter };
});

export default BillPaymentAdapterModule;
