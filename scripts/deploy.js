const hre = require("hardhat");

async function main() {
  console.log("Deploying Crowdfund contract to Core Testnet...");

  // Get the contract factory
  const Crowdfund = await hre.ethers.getContractFactory("Crowdfund");

  // Deploy the contract
  console.log("Deploying contract...");
  const crowdfund = await Crowdfund.deploy();

  // Wait for deployment to complete
  await crowdfund.waitForDeployment();

  const contractAddress = await crowdfund.getAddress();
  console.log("Crowdfund contract deployed to:", contractAddress);

  // Save deployment info
  const fs = require('fs');
  const deploymentInfo = {
    contractAddress: contractAddress,
    network: hre.network.name,
    deployedAt: new Date().toISOString(),
    deployer: (await hre.ethers.getSigners())[0].address
  };

  fs.writeFileSync(
    'deployment-info.json',
    JSON.stringify(deploymentInfo, null, 2)
  );

  console.log("Deployment info saved to deployment-info.json");
  console.log("Contract deployed by:", deploymentInfo.deployer);
  console.log("Network:", hre.network.name);

  // Verify contract if on testnet/mainnet
  if (hre.network.name !== "hardhat" && hre.network.name !== "localhost") {
    console.log("Waiting for block confirmations...");
    await crowdfund.deploymentTransaction().wait(6);
    
    try {
      console.log("Verifying contract...");
      await hre.run("verify:verify", {
        address: contractAddress,
        constructorArguments: [],
      });
      console.log("Contract verified successfully!");
    } catch (error) {
      console.log("Contract verification failed:", error.message);
    }
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("Deployment failed:", error);
    process.exit(1);
  });