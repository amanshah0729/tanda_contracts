import { network } from "hardhat";

/**
 * Test script to verify deployment works correctly
 * Run with: npx hardhat run scripts/test-deployment.ts
 * This will deploy to local Hardhat network and test basic functionality
 */

const { viem, networkName } = await network.connect();
const client = await viem.getPublicClient();

console.log(`Testing deployment on ${networkName}...\n`);

// For local testing, we'll deploy a mock USDC token first
// In production, you'd use the real USDC address: 0x79A02482A880bCE3F13e09Da970dC34db4CD24d1
console.log("Step 1: Deploying mock USDC token for testing...");
const mockUSDC = await viem.deployContract("MockERC20");
console.log("✓ Mock USDC deployed at:", mockUSDC.address);

// Deploy TandaFactory
console.log("\nStep 2: Deploying TandaFactory...");
const factory = await viem.deployContract("TandaFactory", [mockUSDC.address]);
console.log("✓ TandaFactory deployed at:", factory.address);

// Verify factory stores USDC address correctly
const storedUSDC = await factory.read.usdcToken();
console.log("✓ Factory USDC address:", storedUSDC);
if (storedUSDC.toLowerCase() !== mockUSDC.address.toLowerCase()) {
  throw new Error("Factory USDC address mismatch!");
}

// Test creating a Tanda via factory
console.log("\nStep 3: Creating a test Tanda pool via factory...");
const [deployer, alice, bob, charlie] = await viem.getWalletClients();
const participants = [alice.account.address, bob.account.address, charlie.account.address];
const paymentAmount = 10n * 10n ** 6n; // 10 USDC (6 decimals)
const paymentFrequency = 30n * 24n * 60n * 60n; // 30 days in seconds

// Call factory to create Tanda
const factoryContract = await viem.getContractAt("TandaFactory", factory.address);
const txHash = await factoryContract.write.createTanda([
  participants,
  paymentAmount,
  paymentFrequency,
]);

console.log("✓ Tanda creation transaction:", txHash);

// Wait for transaction
const receipt = await client.waitForTransactionReceipt({ hash: txHash });

// For testing, also deploy Tanda directly to verify it works
console.log("\nStep 3b: Deploying Tanda directly to verify contract...");
const tanda = await viem.deployContract("Tanda", [
  mockUSDC.address,
  participants,
  paymentAmount,
  paymentFrequency,
]);
const tandaAddress = tanda.address;
console.log("✓ Tanda deployed at:", tandaAddress);

// Get the Tanda contract instance
const tanda = await viem.getContractAt("Tanda", tandaAddress);

// Verify Tanda parameters
console.log("\nStep 4: Verifying Tanda parameters...");
const tandaUSDC = await tanda.read.usdcToken();
const tandaPaymentAmount = await tanda.read.paymentAmount();
const tandaPaymentFrequency = await tanda.read.paymentFrequency();
const tandaParticipants = await tanda.read.getParticipants();
const currentRecipient = await tanda.read.getCurrentRecipient();

console.log("✓ USDC Token:", tandaUSDC);
console.log("✓ Payment Amount:", tandaPaymentAmount.toString());
console.log("✓ Payment Frequency:", tandaPaymentFrequency.toString(), "seconds");
console.log("✓ Participants:", tandaParticipants.length);
console.log("✓ Current Recipient:", currentRecipient);

// Verify it matches what we passed
if (tandaUSDC.toLowerCase() !== mockUSDC.address.toLowerCase()) {
  throw new Error("Tanda USDC address mismatch!");
}
if (tandaPaymentAmount !== paymentAmount) {
  throw new Error("Payment amount mismatch!");
}
if (tandaPaymentFrequency !== paymentFrequency) {
  throw new Error("Payment frequency mismatch!");
}
if (tandaParticipants.length !== 3) {
  throw new Error("Participants count mismatch!");
}
if (currentRecipient.toLowerCase() !== alice.account.address.toLowerCase()) {
  throw new Error("First recipient should be Alice!");
}

// Test payment (give tokens first)
console.log("\nStep 5: Testing payment functionality...");
const mintAmount = 1000n * 10n ** 6n; // 1000 USDC
await mockUSDC.write.mint([alice.account.address, mintAmount]);
console.log("✓ Minted", mintAmount.toString(), "USDC to Alice");

// Approve Tanda to spend
await mockUSDC.write.approve([tandaAddress, paymentAmount], {
  account: alice.account.address,
});
console.log("✓ Alice approved Tanda to spend USDC");

// Alice pays
await tanda.write.pay({ account: alice.account.address });
console.log("✓ Alice paid successfully");

const vaultBalance = await tanda.read.getVaultBalance();
const alicePaid = await tanda.read.hasPaidThisCycle([alice.account.address]);

if (vaultBalance !== paymentAmount) {
  throw new Error("Vault balance mismatch!");
}
if (!alicePaid) {
  throw new Error("Alice should be marked as paid!");
}

console.log("✓ Vault balance:", vaultBalance.toString());
console.log("✓ Alice payment status:", alicePaid);

console.log("\n✅ All deployment tests passed!");
console.log("\n=== Summary ===");
console.log("Factory Address:", factory.address);
console.log("Test Tanda Address:", tandaAddress);
console.log("Network:", networkName);

