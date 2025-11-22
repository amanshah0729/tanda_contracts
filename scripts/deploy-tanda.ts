import { network } from "hardhat";

const { viem, networkName } = await network.connect();
const client = await viem.getPublicClient();

console.log(`Deploying Counter to ${networkName}...`);

const counter = await viem.deployContract("Counter");

console.log("Counter address:", counter.address);

console.log("Calling counter.incBy(5)");
const tx = await counter.write.incBy([5n]);

console.log("Waiting for the counter.incBy(5) tx to confirm");
await client.waitForTransactionReceipt({ hash: tx, confirmations: 1 });

console.log("Deployment successful!");