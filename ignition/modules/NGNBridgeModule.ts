import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const NGNBridgeModule = buildModule("NGNBridgeModule", (m) => {
  const admin = m.getAccount(0);

  const token = m.contract("CNGNToken", [admin]);
  const bridge = m.contract("NGNBridge", [token, admin]);

  m.call(token, "grantBridge", [bridge]);

  return { token, bridge };
});

export default NGNBridgeModule;
