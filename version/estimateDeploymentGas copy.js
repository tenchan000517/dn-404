const hre = require("hardhat");
const { ethers } = hre;
const path = require('path');

async function estimateDeploymentGas() {
  const contractName = "MAVILLAIN"; // コントラクト名
  const mirrorContractName = "MUTANT_ALIENS_VILLAIN"; // ミラーコントラクト名
  const [deployer] = await ethers.getSigners();

  console.log(`Estimating gas for deploying contract: ${contractName} and ${mirrorContractName}`);
  console.log(`Running script from: ${path.resolve(__dirname)}`); // ディレクトリパスの出力
  console.log(`Script file: ${path.basename(__filename)}`); // ファイル名の出力
  console.log("Account balance:", (await deployer.getBalance()).toString());
  console.log(`Deploying contract with account: ${deployer.address}`); // デプロイアカウントのアドレスを出力

  // コントラクトのFactoryを取得
  const ContractFactory = await ethers.getContractFactory(contractName, deployer);
  const MirrorFactory = await ethers.getContractFactory(mirrorContractName, deployer);

  // デプロイメントトランザクションのガスの見積もりを取得
  const deployTransaction = ContractFactory.getDeployTransaction(
    hre.ethers.utils.parseEther("15000"), // initialTokenSupply
    "0x6e723B123e68E7B0A877D905f0848Bf2205C157A", // initialSupplyOwner
    "0xdbaa28cbe70af04ebfb166b1a3e8f8034e5b9fc7", // contractAllowListProxy
    deployer.address, // initialWithdrawAddress
    "0x1234567890abcdef1234567890abcdef12345678" // initialForwarder
  );

  const mirrorDeployTransaction = MirrorFactory.getDeployTransaction(
    deployer.address, // owner
    "0xdbaa28cbe70af04ebfb166b1a3e8f8034e5b9fc7", // contractAllowListProxy
    deployer.address, // initialWithdrawAddress
    // 1000 // initial parameter
  );

  const gasEstimate = await deployer.estimateGas(deployTransaction);
  const mirrorGasEstimate = await deployer.estimateGas(mirrorDeployTransaction);

  // 現在のガス価格を取得
  const gasPrice = await deployer.getGasPrice();

  // デプロイメントのコストを計算
  const deploymentCost = gasEstimate.mul(gasPrice);
  const mirrorDeploymentCost = mirrorGasEstimate.mul(gasPrice);

  const totalDeploymentCost = deploymentCost.add(mirrorDeploymentCost);
  const totalDeploymentCostInEth = ethers.utils.formatEther(totalDeploymentCost);

  console.log(`Current gas price: ${ethers.utils.formatUnits(gasPrice, "gwei")} Gwei`);
  console.log(`Estimated gas limit for MAVILLAIN contract deployment: ${gasEstimate.toString()} wei`);
  console.log(`Estimated MAVILLAIN deployment cost: ${ethers.utils.formatEther(deploymentCost)} ETH`);
  console.log(`Estimated gas limit for Mirror contract deployment: ${mirrorGasEstimate.toString()} wei`);
  console.log(`Estimated Mirror deployment cost: ${ethers.utils.formatEther(mirrorDeploymentCost)} ETH`);
  console.log(`Total estimated deployment cost: ${totalDeploymentCostInEth} ETH`);
}

estimateDeploymentGas()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
