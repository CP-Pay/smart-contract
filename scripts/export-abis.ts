import { artifacts } from "hardhat";
import { promises as fs } from "fs";
import path from "path";

const CONTRACTS = [
  { name: "SwapRouter" },
  { name: "BillPaymentAdapter" }
];

async function ensureDirectory(target: string) {
  await fs.mkdir(target, { recursive: true });
}

async function writeAbi(contractName: string, outputDir: string) {
  const artifact = await artifacts.readArtifact(contractName);
  const payload = {
    contractName: artifact.contractName,
    sourceName: artifact.sourceName,
    abi: artifact.abi,
    bytecode: artifact.bytecode,
    deployedBytecode: artifact.deployedBytecode
  };

  const destination = path.join(outputDir, `${contractName}.json`);
  await fs.writeFile(destination, JSON.stringify(payload, null, 2), "utf-8");
  return destination;
}

async function main() {
  const rootDir = path.resolve(__dirname, "..", "..");
  const backendAbiDir = path.resolve(rootDir, "backend", "services", "blockchain", "abis");
  await ensureDirectory(backendAbiDir);

  const outputs: string[] = [];
  for (const { name } of CONTRACTS) {
    const destination = await writeAbi(name, backendAbiDir);
    outputs.push(destination);
  }

  console.log(`Exported ABIs for ${CONTRACTS.length} contracts:`);
  outputs.forEach((file) => console.log(`  - ${file}`));
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
