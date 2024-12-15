// npx hardhat run scripts/simulateTransfers.js
const hre = require("hardhat");
const { ethers } = require("hardhat");
const { BigNumber } = require("ethers");

async function main() {
  console.log("Running improved simulation with Mainnet fork");

  // Hardhatのフォークモードを使用
  await hre.network.provider.request({
    method: "hardhat_reset",
    params: [{
      forking: {
        jsonRpcUrl: hre.config.networks.mainnet.url,
        blockNumber: 12345678 // 特定のブロック番号を指定
      },
    }],
  });

  const [deployer] = await ethers.getSigners();

  // コントラクトのデプロイ
  const DN404 = await ethers.getContractFactory("TESTDN404v2");
  const DN404Mirror = await ethers.getContractFactory("ExtendedDN404Mirror");

  console.log("Deploying contracts...");

  const calAddress = "0x1234567890123456789012345678901234567890";

  const mirror = await DN404Mirror.deploy(deployer.address, calAddress);
  await mirror.deployed();
  console.log("Mirror deployed to:", mirror.address);

  const mintRatio = 1000;
  const requiredNFTs = 500 * 4;
  const initialTokenSupply = BigNumber.from(requiredNFTs).mul(BigNumber.from(10).pow(18)).mul(mintRatio);
  const publicPrice = ethers.utils.parseEther("0.01");
  const allowlistPrice = ethers.utils.parseEther("0.005");

  const dn404 = await DN404.deploy(
    "TestToken",
    "TT",
    ethers.utils.formatBytes32String("0x"),
    publicPrice,
    allowlistPrice,
    initialTokenSupply,
    deployer.address,
    calAddress
  );

  await dn404.deployed();
  console.log("DN404 deployed to:", dn404.address);

  await dn404.toggleLive();
  console.log("Contract set to live state");

  const recipients = [];
  for (let i = 0; i < 1000; i++) {
    const wallet = ethers.Wallet.createRandom();
    recipients.push(wallet.address);
  }

  const transferAmount = ethers.utils.parseEther("500");

  // メインネットの現在のガス価格を取得
  const provider = new ethers.providers.JsonRpcProvider(hre.config.networks.mainnet.url);
  const currentGasPrice = await provider.getGasPrice();
  console.log("Current Mainnet gas price:", ethers.utils.formatUnits(currentGasPrice, "gwei"), "Gwei");

  const gweiValues = [
    currentGasPrice,
    ethers.utils.parseUnits("5", "gwei"),
    ethers.utils.parseUnits("10", "gwei"),
    ethers.utils.parseUnits("50", "gwei")
  ];

  for (const gasPrice of gweiValues) {
    console.log("\n--- Simulation with gas price:", ethers.utils.formatUnits(gasPrice, "gwei"), "Gwei ---");
    await runSimulation(dn404, recipients, transferAmount, gasPrice, deployer);
  }
}

async function runSimulation(dn404, recipients, transferAmount, gasPrice, deployer) {
  let totalGasUsed = BigNumber.from(0);
  let totalCost = BigNumber.from(0);
  let successfulTransfers = 0;
  let failedTransfers = 0;

  const batchSize = 10;
  const totalBatches = Math.ceil(recipients.length / batchSize);

  for (let i = 0; i < recipients.length; i += batchSize) {
    const batch = recipients.slice(i, i + batchSize);
    const promises = batch.map(async (recipient) => {
      try {
        const gasLimit = 300000; // ガス制限を設定
        const tx = await dn404.transfer(recipient, transferAmount, { gasPrice, gasLimit });
        const receipt = await tx.wait();

        const gasUsed = receipt.gasUsed;
        const cost = gasUsed.mul(gasPrice);

        totalGasUsed = totalGasUsed.add(gasUsed);
        totalCost = totalCost.add(cost);
        successfulTransfers++;

        return { success: true, gasUsed, cost };
      } catch (error) {
        failedTransfers++;

        // 失敗したトランザクションのガスコストも計算
        const estimatedGas = await dn404.estimateGas.transfer(recipient, transferAmount).catch(() => BigNumber.from(gasLimit));
        const failedCost = estimatedGas.mul(gasPrice);
        totalGasUsed = totalGasUsed.add(estimatedGas);
        totalCost = totalCost.add(failedCost);

        return { success: false, gasUsed: estimatedGas, cost: failedCost };
      }
    });

    const results = await Promise.all(promises);
    
    // バッチの進捗状況を表示
    const currentBatch = Math.floor(i / batchSize) + 1;
    console.log(`Processed batch ${currentBatch}/${totalBatches}`);
  }

  console.log("\nSimulation Summary:");
  console.log("Total gas used:", totalGasUsed.toString());
  console.log("Total cost:", ethers.utils.formatEther(totalCost), "ETH");
  if (successfulTransfers > 0) {
    console.log("Average gas per successful transfer:", totalGasUsed.div(successfulTransfers).toString());
    console.log("Average cost per successful transfer:", ethers.utils.formatEther(totalCost.div(successfulTransfers)), "ETH");
  }
  console.log("Successful transfers:", successfulTransfers);
  console.log("Failed transfers:", failedTransfers);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });