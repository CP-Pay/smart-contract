import { ethers } from "hardhat";

async function main() {
  console.log("🧪 Testing Diamond Deployment...\n");
  
  // Address from the deployment
  const diamondAddress = "0x8A791620dd6260079BF849Dc5567aDC3F2FdC318";
  
  const [deployer] = await ethers.getSigners();
  console.log("Testing with account:", await deployer.getAddress());
  
  // Test ERC20 functionality
  console.log("📝 Testing ERC20 Functions...");
  const erc20 = await ethers.getContractAt("ERC20Facet", diamondAddress);
  
  try {
    const name = await erc20.name();
    const symbol = await erc20.symbol();
    const totalSupply = await erc20.totalSupply();
    
    console.log("   ✅ Name:", name);
    console.log("   ✅ Symbol:", symbol);
    console.log("   ✅ Total Supply:", ethers.formatEther(totalSupply));
  } catch (error) {
    console.log("   ❌ ERC20 Error:", error);
  }
  
  // Test Diamond Loupe functionality
  console.log("\n🔍 Testing Diamond Loupe Functions...");
  const loupe = await ethers.getContractAt("DiamondLoupeFacet", diamondAddress);
  
  try {
    const facets = await loupe.facets();
    console.log("   ✅ Number of Facets:", facets.length);
    
    facets.forEach((facet: any, index: number) => {
      console.log(`   📦 Facet ${index + 1}: ${facet.facetAddress} (${facet.functionSelectors.length} functions)`);
    });
  } catch (error) {
    console.log("   ❌ Loupe Error:", error);
  }
  
  // Test Contract Management functionality
  console.log("\n📋 Testing Contract Management Functions...");
  const contractMgmt = await ethers.getContractAt("ContractManagementFacet", diamondAddress);
  
  try {
    // Initialize contract management
    await contractMgmt.initializeContractManagement();
    console.log("   ✅ Contract Management Initialized");
    
    // Check if paused
    const isPaused = await contractMgmt.isContractManagementPaused();
    console.log("   ✅ Is Paused:", isPaused);
    
    // Verify deployer
    await contractMgmt.verifyUser(await deployer.getAddress());
    console.log("   ✅ User Verified");
    
    const isVerified = await contractMgmt.isUserVerified(await deployer.getAddress());
    console.log("   ✅ User Verification Status:", isVerified);
  } catch (error) {
    console.log("   ❌ Contract Management Error:", error);
  }
  
  // Test Document Management functionality
  console.log("\n📄 Testing Document Management Functions...");
  const docMgmt = await ethers.getContractAt("DocumentManagementFacet", diamondAddress);
  
  try {
    // Initialize document management
    await docMgmt.initializeDocumentManagement();
    console.log("   ✅ Document Management Initialized");
    
    // Check if paused
    const isPaused = await docMgmt.isDocumentManagementPaused();
    console.log("   ✅ Is Paused:", isPaused);
  } catch (error) {
    console.log("   ❌ Document Management Error:", error);
  }
  
  // Test creating a simple contract
  console.log("\n📝 Testing Contract Creation...");
  try {
    const buyer = "0x70997970C51812dc3A010C7d01b50e0d17dc79C8"; // Second hardhat account
    
    // Verify buyer first
    await contractMgmt.verifyUser(buyer);
    
    const tx = await contractMgmt.createContract(
      buyer,
      "Test Trade Contract",
      "A simple test contract for verification",
      ethers.parseEther("1"), // 1 ETH
      Math.floor(Date.now() / 1000) + 86400, // Delivery in 1 day
      Math.floor(Date.now() / 1000) + 172800, // Payment in 2 days
      "FOB Shanghai",
      "Wire Transfer",
      "Electronics Components",
      100,
      "pieces",
      ethers.parseEther("0.01"), // 0.01 ETH per piece
      "USD",
      "CN",
      "US"
    );
    
    await tx.wait();
    console.log("   ✅ Contract Created - Transaction:", tx.hash);
    
    // Get contract details
    const contractDetails = await contractMgmt.getContract(1);
    console.log("   ✅ Contract Details:");
    console.log("      - Seller:", contractDetails[0]);
    console.log("      - Buyer:", contractDetails[1]);
    console.log("      - Value:", ethers.formatEther(contractDetails[2]));
    console.log("      - Status:", contractDetails[3]);
    
  } catch (error) {
    console.log("   ❌ Contract Creation Error:", error);
  }
  
  console.log("\n🎉 Testing completed!");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
