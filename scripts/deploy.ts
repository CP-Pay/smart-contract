import { ethers, run, network } from "hardhat";
import * as dotenv from "dotenv";
import { Contract } from "ethers";
import { testDiamondIntegration } from "./test-diamond";

dotenv.config();

// Environment variables with validation
const PRIVATE_KEY = process.env.PRIVATE_KEY;
const LISK_EXPLORER_KEY = process.env.LISK_EXPLORER_KEY;
const LISK_URL_RPC = process.env.LISK_URL_RPC;

// Validate environment variables
if (!PRIVATE_KEY) {
  throw new Error("PRIVATE_KEY is not set in .env file");
}

if (network.name === "lisk" && !LISK_EXPLORER_KEY) {
  console.warn("⚠️  LISK_EXPLORER_KEY is not set. Contract verification will be skipped.");
}

interface DeploymentResult {
  diamond: string;
  facets: {
    DiamondCutFacet: string;
    DiamondLoupeFacet: string;
    OwnershipFacet: string;
    ERC20Facet: string;
    SwapFacet: string;
    MultiSigFacet: string;
    TokenURIFacet: string;
    ContractManagementFacet: string;
    DocumentManagementFacet: string;
    DiamondInit: string;
  };
}

interface InitArgs {
  name: string;
  symbol: string;
  initialSupply: bigint;
  tokenPriceInWei: bigint;
  description: string;
  externalUrl: string;
  backgroundColor: string;
}

async function verify(address: string, constructorArguments: any[]): Promise<void> {
  if (network.name === "hardhat" || network.name === "localhost") {
    return;
  }

  if (!LISK_EXPLORER_KEY) {
    console.log(`⏭️  Skipping verification for ${address} (no API key)`);
    return;
  }

  console.log(`Verifying contract at ${address}...`);
  try {
    await run("verify:verify", {
      address: address,
      constructorArguments: constructorArguments,
    });
    console.log(`✅ Verified: https://sepolia-blockscout.lisk.com/address/${address}`);
  } catch (e: any) {
    if (e.message.toLowerCase().includes("already verified")) {
      console.log(`✅ Already verified: https://sepolia-blockscout.lisk.com/address/${address}`);
    } else {
      console.log(`❌ Verification failed: ${e.message}`);
    }
  }
}

async function main(): Promise<DeploymentResult> {
  const [deployer] = await ethers.getSigners();
  const deployerAddress = await deployer.getAddress();

  console.log("\n╔════════════════════════════════════════════════════════════╗");
  console.log("║         BlockFinax Diamond Token Deployment Script        ║");
  console.log("╚════════════════════════════════════════════════════════════╝\n");

  console.log("📡 Network:", network.name);
  console.log("👤 Deployer:", deployerAddress);
  console.log("💰 Balance:", ethers.formatEther(await ethers.provider.getBalance(deployerAddress)), "ETH");
  console.log("🔑 Using Private Key:", PRIVATE_KEY ? "✓ Loaded" : "✗ Missing");
  console.log("🔐 Explorer API Key:", LISK_EXPLORER_KEY ? "✓ Loaded" : "✗ Missing");
  console.log("🌐 RPC URL:", LISK_URL_RPC || "Default\n");

  console.log("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n");

  // Deploy facets
  console.log("🚀 Deploying Facets...\n");

  console.log("📦 Deploying DiamondCutFacet...");
  const DiamondCutFacet = await ethers.getContractFactory("DiamondCutFacet");
  const diamondCutFacet = await DiamondCutFacet.deploy();
  await diamondCutFacet.waitForDeployment();
  const diamondCutFacetAddress = await diamondCutFacet.getAddress();
  console.log("   ✅ DiamondCutFacet:", diamondCutFacetAddress);

  console.log("📦 Deploying DiamondLoupeFacet...");
  const DiamondLoupeFacet = await ethers.getContractFactory("DiamondLoupeFacet");
  const diamondLoupeFacet = await DiamondLoupeFacet.deploy();
  await diamondLoupeFacet.waitForDeployment();
  const diamondLoupeFacetAddress = await diamondLoupeFacet.getAddress();
  console.log("   ✅ DiamondLoupeFacet:", diamondLoupeFacetAddress);

  console.log("📦 Deploying OwnershipFacet...");
  const OwnershipFacet = await ethers.getContractFactory("OwnershipFacet");
  const ownershipFacet = await OwnershipFacet.deploy();
  await ownershipFacet.waitForDeployment();
  const ownershipFacetAddress = await ownershipFacet.getAddress();
  console.log("   ✅ OwnershipFacet:", ownershipFacetAddress);

  console.log("📦 Deploying ERC20Facet...");
  const ERC20Facet = await ethers.getContractFactory("ERC20Facet");
  const erc20Facet = await ERC20Facet.deploy();
  await erc20Facet.waitForDeployment();
  const erc20FacetAddress = await erc20Facet.getAddress();
  console.log("   ✅ ERC20Facet:", erc20FacetAddress);

  console.log("📦 Deploying SwapFacet...");
  const SwapFacet = await ethers.getContractFactory("SwapFacet");
  const swapFacet = await SwapFacet.deploy();
  await swapFacet.waitForDeployment();
  const swapFacetAddress = await swapFacet.getAddress();
  console.log("   ✅ SwapFacet:", swapFacetAddress);

  console.log("📦 Deploying MultiSigFacet...");
  const MultiSigFacet = await ethers.getContractFactory("MultiSigFacet");
  const multiSigFacet = await MultiSigFacet.deploy();
  await multiSigFacet.waitForDeployment();
  const multiSigFacetAddress = await multiSigFacet.getAddress();
  console.log("   ✅ MultiSigFacet:", multiSigFacetAddress);

  console.log("📦 Deploying TokenURIFacet...");
  const TokenURIFacet = await ethers.getContractFactory("TokenURIFacet");
  const tokenURIFacet = await TokenURIFacet.deploy();
  await tokenURIFacet.waitForDeployment();
  const tokenURIFacetAddress = await tokenURIFacet.getAddress();
  console.log("   ✅ TokenURIFacet:", tokenURIFacetAddress);

  console.log("📦 Deploying ContractManagementFacet...");
  const ContractManagementFacet = await ethers.getContractFactory("ContractManagementFacet");
  const contractManagementFacet = await ContractManagementFacet.deploy();
  await contractManagementFacet.waitForDeployment();
  const contractManagementFacetAddress = await contractManagementFacet.getAddress();
  console.log("   ✅ ContractManagementFacet:", contractManagementFacetAddress);

  console.log("📦 Deploying DocumentManagementFacet...");
  const DocumentManagementFacet = await ethers.getContractFactory("DocumentManagementFacet");
  const documentManagementFacet = await DocumentManagementFacet.deploy();
  await documentManagementFacet.waitForDeployment();
  const documentManagementFacetAddress = await documentManagementFacet.getAddress();
  console.log("   ✅ DocumentManagementFacet:", documentManagementFacetAddress);

  console.log("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n");

  // Deploy Diamond with DiamondCutFacet
  console.log("💎 Deploying Diamond Proxy...");
  const Diamond = await ethers.getContractFactory("Diamond");
  const diamond = await Diamond.deploy(deployerAddress, diamondCutFacetAddress);
  await diamond.waitForDeployment();
  const diamondAddress = await diamond.getAddress();
  console.log("   ✅ Diamond Proxy:", diamondAddress);

  console.log("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n");

  // Prepare facet cuts
  console.log("✂️  Preparing Facet Cuts...\n");
  const FacetCutAction = { Add: 0, Replace: 1, Remove: 2 };

  const cuts = [];

  // DiamondLoupeFacet
  const loupeFacetSelectors = getSelectors(diamondLoupeFacet);
  cuts.push({
    facetAddress: diamondLoupeFacetAddress,
    action: FacetCutAction.Add,
    functionSelectors: loupeFacetSelectors,
  });
  console.log("   ✓ DiamondLoupeFacet -", loupeFacetSelectors.length, "functions");

  // OwnershipFacet
  const ownershipFacetSelectors = getSelectors(ownershipFacet);
  cuts.push({
    facetAddress: ownershipFacetAddress,
    action: FacetCutAction.Add,
    functionSelectors: ownershipFacetSelectors,
  });
  console.log("   ✓ OwnershipFacet -", ownershipFacetSelectors.length, "functions");

  // ERC20Facet
  const erc20FacetSelectors = getSelectors(erc20Facet);
  cuts.push({
    facetAddress: erc20FacetAddress,
    action: FacetCutAction.Add,
    functionSelectors: erc20FacetSelectors,
  });
  console.log("   ✓ ERC20Facet -", erc20FacetSelectors.length, "functions");

  // SwapFacet
  const swapFacetSelectors = getSelectors(swapFacet);
  cuts.push({
    facetAddress: swapFacetAddress,
    action: FacetCutAction.Add,
    functionSelectors: swapFacetSelectors,
  });
  console.log("   ✓ SwapFacet -", swapFacetSelectors.length, "functions");

  // MultiSigFacet
  const multiSigFacetSelectors = getSelectors(multiSigFacet);
  cuts.push({
    facetAddress: multiSigFacetAddress,
    action: FacetCutAction.Add,
    functionSelectors: multiSigFacetSelectors,
  });
  console.log("   ✓ MultiSigFacet -", multiSigFacetSelectors.length, "functions");

  // TokenURIFacet
  const tokenURIFacetSelectors = getSelectors(tokenURIFacet);
  cuts.push({
    facetAddress: tokenURIFacetAddress,
    action: FacetCutAction.Add,
    functionSelectors: tokenURIFacetSelectors,
  });
  console.log("   ✓ TokenURIFacet -", tokenURIFacetSelectors.length, "functions");

  // ContractManagementFacet
  const contractManagementFacetSelectors = getSelectors(contractManagementFacet);
  cuts.push({
    facetAddress: contractManagementFacetAddress,
    action: FacetCutAction.Add,
    functionSelectors: contractManagementFacetSelectors,
  });
  console.log("   ✓ ContractManagementFacet -", contractManagementFacetSelectors.length, "functions");

  // DocumentManagementFacet
  const documentManagementFacetSelectors = getSelectors(documentManagementFacet);
  cuts.push({
    facetAddress: documentManagementFacetAddress,
    action: FacetCutAction.Add,
    functionSelectors: documentManagementFacetSelectors,
  });
  console.log("   ✓ DocumentManagementFacet -", documentManagementFacetSelectors.length, "functions");

  console.log("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n");

  // Deploy DiamondInit
  console.log("🔧 Deploying DiamondInit...");
  const DiamondInit = await ethers.getContractFactory("DiamondInit");
  const diamondInit = await DiamondInit.deploy();
  await diamondInit.waitForDeployment();
  const diamondInitAddress = await diamondInit.getAddress();
  console.log("   ✅ DiamondInit:", diamondInitAddress);

  // Prepare initialization data
  const initArgs: InitArgs = {
    name: "BlockFinax",
    symbol: "BLX",
    initialSupply: ethers.parseEther("1000000"),
    tokenPriceInWei: ethers.parseEther("0.001"),
    description:
      "BlockFinax - A fully upgradeable diamond proxy ERC20 token with trading, contract management, document verification, swap, multisig, and onchain SVG capabilities",
    externalUrl: "https://blockfinax.com",
    backgroundColor: "667eea",
  };

  const functionCall = diamondInit.interface.encodeFunctionData("init", [initArgs]);

  console.log("\n💫 Executing Diamond Cut...");
  // Execute diamond cut to add all facets
  const diamondCut = await ethers.getContractAt("IDiamondCut", diamondAddress);
  const tx = await diamondCut.diamondCut(cuts, diamondInitAddress, functionCall);
  console.log("   ⏳ Transaction hash:", tx.hash);
  await tx.wait();
  console.log("   ✅ Diamond Cut executed successfully!");

  console.log("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n");

  // Verify all contracts
  if (network.name !== "hardhat" && network.name !== "localhost" && LISK_EXPLORER_KEY) {
    console.log("🔍 Verifying Contracts on Blockscout...\n");
    console.log("⏳ Waiting for block confirmations...\n");
    
    await verify(diamondCutFacetAddress, []);
    await verify(diamondLoupeFacetAddress, []);
    await verify(ownershipFacetAddress, []);
    await verify(erc20FacetAddress, []);
    await verify(swapFacetAddress, []);
    await verify(multiSigFacetAddress, []);
    await verify(tokenURIFacetAddress, []);
    await verify(contractManagementFacetAddress, []);
    await verify(documentManagementFacetAddress, []);
    await verify(diamondInitAddress, []);
    await verify(diamondAddress, [deployerAddress, diamondCutFacetAddress]);
    
    console.log("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n");
  }

  // Log deployed and verified contract addresses
  console.log("\n╔════════════════════════════════════════════════════════════╗");
  console.log("║              Deployment Summary                            ║");
  console.log("╚════════════════════════════════════════════════════════════╝\n");

  console.log("💎 DIAMOND PROXY");
  console.log("   Address:", diamondAddress);
  if (network.name === "lisk") {
    console.log("   Explorer: https://sepolia-blockscout.lisk.com/address/" + diamondAddress);
  }

  console.log("\n📋 IMPLEMENTATION CONTRACTS\n");
  
  const contracts = [
    { name: "DiamondCutFacet", address: diamondCutFacetAddress },
    { name: "DiamondLoupeFacet", address: diamondLoupeFacetAddress },
    { name: "OwnershipFacet", address: ownershipFacetAddress },
    { name: "ERC20Facet", address: erc20FacetAddress },
    { name: "SwapFacet", address: swapFacetAddress },
    { name: "MultiSigFacet", address: multiSigFacetAddress },
    { name: "TokenURIFacet", address: tokenURIFacetAddress },
    { name: "ContractManagementFacet", address: contractManagementFacetAddress },
    { name: "DocumentManagementFacet", address: documentManagementFacetAddress },
    { name: "DiamondInit", address: diamondInitAddress },
  ];

  for (const contract of contracts) {
    console.log(`   ${contract.name}`);
    console.log(`   └─ ${contract.address}`);
    if (network.name === "lisk") {
      console.log(`      https://sepolia-blockscout.lisk.com/address/${contract.address}`);
    }
  }

  console.log("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n");
  console.log("✅ Deployment completed successfully!\n");

  // Test Diamond Integration
  await testDiamondIntegration(diamondAddress);

  return {
    diamond: diamondAddress,
    facets: {
      DiamondCutFacet: diamondCutFacetAddress,
      DiamondLoupeFacet: diamondLoupeFacetAddress,
      OwnershipFacet: ownershipFacetAddress,
      ERC20Facet: erc20FacetAddress,
      SwapFacet: swapFacetAddress,
      MultiSigFacet: multiSigFacetAddress,
      TokenURIFacet: tokenURIFacetAddress,
      ContractManagementFacet: contractManagementFacetAddress,
      DocumentManagementFacet: documentManagementFacetAddress,
      DiamondInit: diamondInitAddress,
    },
  };
}

// Helper function to get selectors
function getSelectors(contract: any): string[] {
  const signatures = Object.keys(contract.interface.fragments)
    .filter((key) => {
      const fragment = contract.interface.fragments[key];
      return fragment.type === "function";
    })
    .map((key) => contract.interface.fragments[key].format("sighash"));

  const selectors = signatures.reduce((acc: string[], val: string) => {
    if (val !== "init(bytes)") {
      const selector = contract.interface.getFunction(val)!.selector;
      acc.push(selector);
    }
    return acc;
  }, []);
  return selectors;
}

// Execute deployment
if (require.main === module) {
  main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error("\n❌ Deployment failed:\n");
      console.error(error);
      process.exit(1);
    });
}

export { main, getSelectors };
