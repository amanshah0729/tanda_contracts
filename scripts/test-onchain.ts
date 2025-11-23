import { network } from "hardhat";

/**
 * Test script to verify deployed contract on-chain
 * Usage: npx hardhat run scripts/test-onchain.ts --network worldchain
 */

const { viem, networkName } = await network.connect();
const client = await viem.getPublicClient();

// Your deployed TandaFactory address
const FACTORY_ADDRESS = "0x2aef2dadd6d888c58fdf57d20721d49ea25d9583" as `0x${string}`;

console.log(`Testing TandaFactory on ${networkName}...\n`);
console.log("Factory Address:", FACTORY_ADDRESS);

// Get the factory contract instance
const factory = await viem.getContractAt("TandaFactory", FACTORY_ADDRESS);

// Test 1: Verify factory is deployed and readable
console.log("\n=== Test 1: Verify Factory Deployment ===");
try {
  const usdcTokenAddress = await factory.read.usdcToken();
  console.log("✓ Factory is deployed and readable");
  console.log("✓ USDC Token Address:", usdcTokenAddress);
  
  // Verify it matches expected World Chain USDC address
  const expectedUSDC = "0x79A02482A880bCE3F13e09Da970dC34db4CD24d1";
  if (usdcTokenAddress.toLowerCase() === expectedUSDC.toLowerCase()) {
    console.log("✓ USDC address matches expected World Chain address");
  } else {
    console.log("⚠ USDC address doesn't match expected address");
    console.log("  Expected:", expectedUSDC);
    console.log("  Got:", usdcTokenAddress);
  }
} catch (error: any) {
  console.error("✗ Failed to read factory:", error.message);
  process.exit(1);
}

// Test 2: Get deployer info
console.log("\n=== Test 2: Deployer Info ===");
const [deployer] = await viem.getWalletClients();
const deployerAddress = deployer.account.address;
const balance = await client.getBalance({ address: deployerAddress });
console.log("Deployer Address:", deployerAddress);
console.log("Deployer Balance:", (Number(balance) / 1e18).toFixed(4), "ETH");

// Test 3: Check if we can read contract code
console.log("\n=== Test 3: Contract Code Verification ===");
try {
  const code = await client.getBytecode({ address: FACTORY_ADDRESS });
  if (code && code !== "0x") {
    console.log("✓ Contract has code deployed");
    console.log("✓ Code length:", code.length, "characters");
  } else {
    console.error("✗ No code found at address - contract may not be deployed");
    process.exit(1);
  }
} catch (error: any) {
  console.error("✗ Failed to verify contract code:", error.message);
}

// Test 4: Actually create a Tanda via factory
console.log("\n=== Test 4: Create Tanda via Factory ===");
try {
  // Use deployer address as participants (for testing - in production use real addresses)
  // You can modify these to use actual participant addresses
  const participants = [
    deployerAddress,
    deployerAddress, // Using same address twice for testing - replace with real addresses
    deployerAddress  // Using same address three times for testing - replace with real addresses
  ];
  
  const paymentAmount = 10n * 10n ** 6n; // 10 USDC (6 decimals)
  const paymentFrequency = 30n * 24n * 60n * 60n; // 30 days in seconds
  
  console.log("Creating Tanda with:");
  console.log("  Participants:", participants.length, "addresses");
  console.log("  Payment Amount:", paymentAmount.toString(), "(10 USDC)");
  console.log("  Payment Frequency:", paymentFrequency.toString(), "seconds (30 days)");
  
  // First, simulate to get the return value (the Tanda address)
  // Note: CREATE uses nonce, so the address is deterministic - this should match!
  console.log("Simulating Tanda creation to get address...");
  const simulateResult = await client.simulateContract({
    address: FACTORY_ADDRESS,
    abi: factory.abi,
    functionName: "createTanda",
    args: [participants, paymentAmount, paymentFrequency],
    account: deployerAddress,
  });
  
  // Get the return value (Tanda address) from simulation
  const simulatedTandaAddress = simulateResult.result as `0x${string}`;
  console.log("✓ Simulation successful");
  console.log("📋 Predicted Tanda address:", simulatedTandaAddress);
  
  // Now actually create the Tanda
  console.log("\nExecuting Tanda creation transaction...");
  const txHash = await factory.write.createTanda([
    participants,
    paymentAmount,
    paymentFrequency,
  ]);
  
  console.log("✓ Transaction sent:", txHash);
  console.log("Waiting for confirmation...");
  
  // Wait for transaction
  const receipt = await client.waitForTransactionReceipt({ hash: txHash });
  console.log("✓ Transaction confirmed in block:", receipt.blockNumber);
  
  // Try to read the TandaCreated event from the block
  console.log("\nReading events from transaction...");
  let createdTandaAddress: `0x${string}`;
  
  try {
    const events = await client.getContractEvents({
      address: FACTORY_ADDRESS,
      abi: factory.abi,
      eventName: "TandaCreated",
      fromBlock: receipt.blockNumber,
      toBlock: receipt.blockNumber,
    });
    
    if (events.length > 0) {
      const lastEvent = events[events.length - 1];
      const eventTandaAddress = (lastEvent.args as any).tandaAddress as `0x${string}`;
      console.log("✓ Found TandaCreated event!");
      console.log("📋 Tanda address from event:", eventTandaAddress);
      // Use the event address if found
      createdTandaAddress = eventTandaAddress;
    } else {
      console.log("⚠ No TandaCreated event found, using simulated address");
      // Fall back to simulated address (should match due to CREATE determinism)
      createdTandaAddress = simulatedTandaAddress;
    }
  } catch (e: any) {
    console.log("⚠ Could not read events:", e.message);
    console.log("📋 Using simulated address:", simulatedTandaAddress);
    createdTandaAddress = simulatedTandaAddress;
  }
  
  if (receipt.status !== "success") {
    throw new Error("Transaction failed!");
  }
  
  console.log("\n=== Test 5: Verify Created Tanda ===");
  console.log("📋 Tanda Contract Address:", createdTandaAddress);
  
  // Verify the Tanda contract exists and is readable
  const tandaCode = await client.getBytecode({ address: createdTandaAddress });
  if (tandaCode && tandaCode !== "0x") {
    console.log("✓ Tanda contract has code deployed");
  } else {
    console.error("✗ Tanda contract has no code - creation may have failed");
    process.exit(1);
  }
  
  // Get Tanda contract instance and verify parameters
  const tanda = await viem.getContractAt("Tanda", createdTandaAddress);
  const tandaUSDC = await tanda.read.usdcToken();
  const tandaPaymentAmount = await tanda.read.paymentAmount();
  const tandaPaymentFrequency = await tanda.read.paymentFrequency();
  const tandaParticipants = await tanda.read.getParticipants();
  const currentRecipient = await tanda.read.getCurrentRecipient();
  
  console.log("\n✓ Tanda Contract Verification:");
  console.log("  Address:", createdTandaAddress);
  console.log("  USDC Token:", tandaUSDC);
  console.log("  Payment Amount:", tandaPaymentAmount.toString());
  console.log("  Payment Frequency:", tandaPaymentFrequency.toString());
  console.log("  Participants:", tandaParticipants.length);
  console.log("  Current Recipient:", currentRecipient);
  
  // Verify values match
  if (tandaPaymentAmount !== paymentAmount) {
    throw new Error("Payment amount mismatch!");
  }
  if (tandaPaymentFrequency !== paymentFrequency) {
    throw new Error("Payment frequency mismatch!");
  }
  if (tandaParticipants.length !== participants.length) {
    throw new Error("Participants count mismatch!");
  }
  
  console.log("\n✅ Tanda created successfully and verified!");
  console.log("\n" + "=".repeat(60));
  console.log("📋 SAVE THIS ADDRESS FOR FRONTEND:");
  console.log("   Tanda Address:", createdTandaAddress);
  console.log("   Transaction:", txHash);
  console.log("=".repeat(60));
  
} catch (error: any) {
  console.error("✗ Failed to create Tanda:", error.message);
  console.error("Error details:", error);
  process.exit(1);
}

console.log("\n✅ All on-chain tests passed!");
console.log("\n=== Summary ===");
console.log("Network:", networkName);
console.log("Factory Address:", FACTORY_ADDRESS);
console.log("✓ Factory is working correctly");
console.log("✓ Successfully created and verified a Tanda contract");

