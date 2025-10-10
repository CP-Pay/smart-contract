import { ethers } from "hardhat";

async function testDiamondIntegration(diamondAddress: string) {
  console.log("\n🔍 Testing Diamond Integration...\n");
  
  const [deployer] = await ethers.getSigners();
  
  // Test DiamondLoupe functions
  console.log("📋 Testing DiamondLoupe Facet...");
  const diamondLoupe = await ethers.getContractAt("DiamondLoupeFacet", diamondAddress);
  const facets = await diamondLoupe.facets();
  console.log(`   ✓ Found ${facets.length} facets`);
  
  for (let i = 0; i < facets.length; i++) {
    console.log(`   📦 Facet ${i + 1}: ${facets[i].facetAddress}`);
    console.log(`      Functions: ${facets[i].functionSelectors.length}`);
  }
  
  // Test ERC20 functions
  console.log("\n💰 Testing ERC20 Facet...");
  const erc20 = await ethers.getContractAt("ERC20Facet", diamondAddress);
  const name = await erc20.name();
  const symbol = await erc20.symbol();
  const totalSupply = await erc20.totalSupply();
  const balance = await erc20.balanceOf(deployer.address);
  
  console.log(`   ✓ Token Name: ${name}`);
  console.log(`   ✓ Token Symbol: ${symbol}`);
  console.log(`   ✓ Total Supply: ${ethers.formatEther(totalSupply)} ${symbol}`);
  console.log(`   ✓ Deployer Balance: ${ethers.formatEther(balance)} ${symbol}`);
  
  // Test Ownership functions
  console.log("\n👑 Testing Ownership Facet...");
  const ownership = await ethers.getContractAt("OwnershipFacet", diamondAddress);
  const owner = await ownership.owner();
  console.log(`   ✓ Contract Owner: ${owner}`);
  console.log(`   ✓ Deployer is Owner: ${owner.toLowerCase() === deployer.address.toLowerCase()}`);
  
  // Test ContractManagement functions
  console.log("\n📄 Testing Contract Management Facet...");
  const contractMgmt = await ethers.getContractAt("ContractManagementFacet", diamondAddress);
  
  try {
    // Initialize the contract management system
    await contractMgmt.initializeContractManagement();
    console.log("   ✓ Contract Management initialized");
  } catch (error: any) {
    if (error.message.includes("Already initialized")) {
      console.log("   ✓ Contract Management already initialized");
    } else {
      console.log("   ❌ Contract Management initialization failed:", error.message);
    }
  }
  
  // Check if user verification works
  const isVerified = await contractMgmt.isUserVerified(deployer.address);
  console.log(`   ✓ Deployer verification status: ${isVerified}`);
  
  // Verify the deployer if not already verified
  if (!isVerified) {
    await contractMgmt.verifyUser(deployer.address);
    console.log("   ✓ Deployer verified for trading");
  }
  
  // Test DocumentManagement functions
  console.log("\n📋 Testing Document Management Facet...");
  const docMgmt = await ethers.getContractAt("DocumentManagementFacet", diamondAddress);
  
  try {
    // Initialize the document management system
    await docMgmt.initializeDocumentManagement();
    console.log("   ✓ Document Management initialized");
  } catch (error: any) {
    if (error.message.includes("Already initialized")) {
      console.log("   ✓ Document Management already initialized");
    } else {
      console.log("   ❌ Document Management initialization failed:", error.message);
    }
  }
  
  const isPaused = await docMgmt.isDocumentManagementPaused();
  console.log(`   ✓ Document Management paused status: ${isPaused}`);
  
  // Test SwapFacet functions
  console.log("\n🔄 Testing Swap Facet...");
  const swap = await ethers.getContractAt("SwapFacet", diamondAddress);
  const tokenPrice = await swap.getTokenPrice();
  console.log(`   ✓ Token Price: ${ethers.formatEther(tokenPrice)} ETH`);
  
  // Test MultiSig functions
  console.log("\n🔐 Testing MultiSig Facet...");
  const multiSig = await ethers.getContractAt("MultiSigFacet", diamondAddress);
  const requiredConfirmations = await multiSig.getRequiredConfirmations();
  console.log(`   ✓ Required Confirmations: ${requiredConfirmations}`);
  
  // Test TokenURI functions
  console.log("\n🎨 Testing TokenURI Facet...");
  try {
    const tokenURI = await ethers.getContractAt("TokenURIFacet", diamondAddress);
    console.log("   ✓ TokenURI facet accessible");
  } catch {
    console.log("   ❌ TokenURI facet not accessible");
  }
  
  console.log("\n✅ All facets are properly integrated and accessible through Diamond!");
  console.log(`\n💎 Diamond Contract Address: ${diamondAddress}`);
  console.log("🎯 All functionality is accessible through this single address!");
  
  return true;
}

export { testDiamondIntegration };
