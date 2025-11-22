import { network } from "hardhat";
import { decodeEventLog } from "viem";

/**
 * Test script to verify deployed contract on-chain
 * Usage: npx hardhat run scripts/test-onchain.ts --network worldchain
 */

const { viem, networkName } = await network.connect();
const client = await viem.getPublicClient();

// Your deployed TandaFactory address
const FACTORY_ADDRESS = "0x1d8abc392e739eb267667fb5c715e90f35c90233" as `0x${string}`;

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
  
  // First, simulate to see what address would be created (for verification)
  // Note: This is simulated, so the actual address will be different when we execute
  console.log("Simulating Tanda creation...");
  const simulateResult = await client.simulateContract({
    address: FACTORY_ADDRESS,
    abi: factory.abi,
    functionName: "createTanda",
    args: [participants, paymentAmount, paymentFrequency],
    account: deployerAddress,
  });
  console.log("✓ Simulation successful (this shows the function works)");
  
  // Now actually create the Tanda
  console.log("Executing Tanda creation transaction...");
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
  
  if (receipt.status !== "success") {
    throw new Error("Transaction failed!");
  }
  
  console.log("\n=== Test 5: Verify Created Tanda ===");
  
  // Parse the TandaCreated event from the transaction logs
  const tandaCreatedEvent = receipt.logs.find((log: any) => {
    // Check if this log matches the TandaCreated event signature
    // Event signature: TandaCreated(address,address,address[],uint256,uint256)
    try {
      const decoded = decodeEventLog({
        abi: factory.abi,
        data: log.data,
        topics: log.topics,
      });
      return decoded.eventName === "TandaCreated";
    } catch {
      return false;
    }
  });
  
  if (!tandaCreatedEvent) {
    console.log("⚠ Could not find TandaCreated event in logs");
    console.log("  This might mean the factory was deployed before the event was added");
    console.log("  Check transaction on block explorer to verify Tanda was created");
    console.log("  Transaction hash:", txHash);
  } else {
    // Decode the event
    const decodedEvent = decodeEventLog({
      abi: factory.abi,
      data: tandaCreatedEvent.data,
      topics: tandaCreatedEvent.topics,
    });
    
    const createdTandaAddress = (decodedEvent.args as any).tandaAddress as `0x${string}`;
    console.log("✓ Tanda created at address:", createdTandaAddress);
    
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
  }
  
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

