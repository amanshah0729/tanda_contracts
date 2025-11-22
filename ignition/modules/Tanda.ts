import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("TandaModule", (m) => {
  const tanda = m.contract("Tanda");



  return { tanda };
});
