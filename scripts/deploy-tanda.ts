import { network } from "hardhat";

const { viem, networkName } = await network.connect();
const client = await viem.getPublicClient();

console.log(`Deploying TandaFactory to ${networkName}...`);

// USDC token address on World Chain
// This is the native USDC contract address (works for both USDC.e bridged and native USDC)
// Source: https://www.circle.com/multi-chain-usdc/world-chain
const usdcTokenAddress = "0x79A02482A880bCE3F13e09Da970dC34db4CD24d1" as `0x${string}`;

console.log("USDC Token Address:", usdcTokenAddress);

// Get deployer address
const [deployer] = await viem.getWalletClients();
console.log("Deploying from:", deployer.account.address);

// Deploy TandaFactory
const factory = await viem.deployContract("TandaFactory", [usdcTokenAddress]);

console.log("TandaFactory deployed at:", factory.address);
console.log("Deployment successful!");
console.log("\n=== Deployment Summary ===");
console.log("Network:", networkName);
console.log("TandaFactory Address:", factory.address);
console.log("USDC Token Address:", usdcTokenAddress);
console.log("\nTo create a Tanda, call:");
console.log(`factory.createTanda(participants, paymentAmount, paymentFrequency)`);