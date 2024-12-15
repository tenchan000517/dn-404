const hre = require("hardhat");
const { ethers } = require("hardhat");

async function estimateDeploymentGas() {
  const [deployer] = await ethers.getSigners();

  console.log("Account balance:", ethers.utils.formatEther(await deployer.getBalance()), "ETH");
  console.log("Deploying with account:", deployer.address);

  // コントラクトのFactoryを取得
  const ContractFactory = await ethers.getContractFactory("MAVILLAIN");
  const MirrorFactory = await ethers.getContractFactory("MUTANT_ALIENS_VILLAIN");

  // デプロイメントトランザクションのガスの見積もり
  const deployTransaction = await ContractFactory.getDeployTransaction(
    deployer.address, // initialSupplyOwner 
    "0xdbaa28cbe70af04ebfb166b1a3e8f8034e5b9fc7", // contractAllowListProxy
    deployer.address, // initialWithdrawAddress
    "0x1234567890abcdef1234567890abcdef12345678" // initialForwarder
  );

  const mirrorDeployTransaction = await MirrorFactory.getDeployTransaction(
    deployer.address, // deployer
    "0xdbaa28cbe70af04ebfb166b1a3e8f8034e5b9fc7", // cal
    deployer.address // defaultRoyaltyReceiver
  );

  const gasEstimate = await deployer.estimateGas(deployTransaction);
  const mirrorGasEstimate = await deployer.estimateGas(mirrorDeployTransaction);
  const gasPrice = await deployer.getGasPrice();

  const deploymentCost = gasEstimate.mul(gasPrice);
  const mirrorDeploymentCost = mirrorGasEstimate.mul(gasPrice);
  const totalCost = deploymentCost.add(mirrorDeploymentCost);

  console.log(`Gas price: ${ethers.utils.formatUnits(gasPrice, "gwei")} Gwei`);
  console.log(`MAVILLAIN gas estimate: ${gasEstimate.toString()}`);
  console.log(`MAVILLAIN deployment cost: ${ethers.utils.formatEther(deploymentCost)} ETH`);
  console.log(`Mirror gas estimate: ${mirrorGasEstimate.toString()}`);
  console.log(`Mirror deployment cost: ${ethers.utils.formatEther(mirrorDeploymentCost)} ETH`);
  console.log(`Total deployment cost: ${ethers.utils.formatEther(totalCost)} ETH`);
}

estimateDeploymentGas()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });