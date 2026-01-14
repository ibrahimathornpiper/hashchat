import { ethers } from "ethers";
import fs from "fs";
import path from "path";
import { fileURLToPath } from 'url';
import dotenv from "dotenv";

dotenv.config({ path: "../wallet_gen/.env" });

const __dirname = path.dirname(fileURLToPath(import.meta.url));

async function main() {
  const { RPC_URL, PRIVATE_KEY } = process.env;
  if (!RPC_URL || !PRIVATE_KEY) throw new Error("Missing Env Config");

  console.log("Connecting to:", RPC_URL);
  const provider = new ethers.JsonRpcProvider(RPC_URL);
  const wallet = new ethers.Wallet(PRIVATE_KEY, provider);

  // Load Artifact
  const artifactPath = path.join(__dirname, "../artifacts/contracts/BurnerChat.sol/BurnerChat.json");
  if (!fs.existsSync(artifactPath)) throw new Error("Artifact not found. Did you compile?");
  
  const artifact = JSON.parse(fs.readFileSync(artifactPath, "utf8"));
  
  console.log("Deploying contract...");
  const factory = new ethers.ContractFactory(artifact.abi, artifact.bytecode, wallet);
  const contract = await factory.deploy();
  
  console.log("Waiting for deployment...");
  await contract.waitForDeployment();
  const address = await contract.getAddress();
  
  console.log("Contract Deployed to:", address);
  fs.writeFileSync(path.join(__dirname, "../../address.txt"), address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
