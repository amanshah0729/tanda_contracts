import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("TandaFactoryModule", (m) => {
  // USDC token address on World Chain
  // This is the native USDC contract address (works for both USDC.e bridged and native USDC)
  // Source: https://www.circle.com/multi-chain-usdc/world-chain
  const usdcTokenAddress = "0x79A02482A880bCE3F13e09Da970dC34db4CD24d1";
  
  // Deploy TandaFactory
  const factory = m.contract("TandaFactory", [usdcTokenAddress]);

  return { factory };
});
