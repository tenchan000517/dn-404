const hre = require("hardhat");
const { ethers } = require("hardhat");
require('dotenv').config();

async function formatGasAndCost(gasEstimate, gasPrice, description) {
    const cost = gasEstimate.mul(gasPrice);
    console.log(`\n${description} Deployment Estimates:`);
    console.log(`Gas estimate: ${gasEstimate.toString()} units`);
    console.log(`Cost estimate: ${ethers.utils.formatEther(cost)} ETH`);
    console.log(`Cost in USD: $${(parseFloat(ethers.utils.formatEther(cost)) * process.env.ETH_USD_PRICE || 2000).toFixed(2)}`);
    return cost;
}

async function estimateDeploymentGas() {
    // Get deployer account
    const [deployer] = await ethers.getSigners();
    const balance = await deployer.getBalance();

    console.log("\nDeployment Account Info:");
    console.log("------------------------");
    console.log("Address:", deployer.address);
    console.log("Balance:", ethers.utils.formatEther(balance), "ETH");

    // Get contract configuration from environment variables
    const config = {
        name: process.env.TOKEN_NAME || "Custom ERC1155",
        symbol: process.env.TOKEN_SYMBOL || "CERC",
        withdrawAddress: process.env.WITHDRAW_ADDRESS || deployer.address,
        maxSupply: process.env.MAX_SUPPLY || 100,
        cost: process.env.MINT_COST ? ethers.utils.parseEther(process.env.MINT_COST) : ethers.utils.parseEther("0"),
        maxMintAmountPerTransaction: process.env.MAX_MINT_PER_TX || 5,
        merkleRoot: process.env.MERKLE_ROOT || "0x0000000000000000000000000000000000000000000000000000000000000000",
        paused: false,
        onlyAllowlisted: false,
        isSBT: process.env.IS_SBT === "true" || false,
        publicSaleMaxMintAmountPerAddress: process.env.MAX_MINT_PER_ADDRESS || 5,
        useInterfaceMetadata: false,
        useBaseURI: true,
        baseURI: process.env.BASE_URI || "ipfs://YOUR_IPFS_CID/",
        baseExtension: ".json",
        royaltyReceiver: process.env.ROYALTY_RECEIVER || deployer.address,
        royaltyFeeNumerator: process.env.ROYALTY_FEE || 1000
    };

    // Get contract factory
    const CustomERC1155 = await ethers.getContractFactory("CustomERC1155");

    // Get deployment transaction
    const deployTransaction = await CustomERC1155.getDeployTransaction(config);

    // Get gas estimates
    const gasEstimate = await deployer.estimateGas(deployTransaction);
    const gasPrice = await getGasPrice(deployer);

    console.log("\nGas Price Information:");
    console.log("----------------------");
    console.log(`Current gas price: ${ethers.utils.formatUnits(gasPrice, "gwei")} Gwei`);

    // Calculate and display deployment costs
    const deploymentCost = await formatGasAndCost(gasEstimate, gasPrice, "Contract");

    // Calculate post-deployment operation costs
    const contract = CustomERC1155.attach("0x0000000000000000000000000000000000000000"); // Dummy address for estimation

    console.log("\nPost-Deployment Operation Estimates:");
    console.log("-----------------------------------");

    // Prepare token configs for phase setup
    const tokenConfigs = [{
        tokenId: 1,
        maxSupply: config.maxSupply
    }];

    // Estimate setPhaseTokenConfigs cost
    const setPhaseGas = await contract.estimateGas.setPhaseTokenConfigs(
        0, // phaseId
        tokenConfigs,
        config.cost,
        config.maxMintAmountPerTransaction,
        config.merkleRoot
    ).catch(() => ethers.BigNumber.from("150000")); // Increased fallback estimate

    await formatGasAndCost(setPhaseGas, gasPrice, "Set Initial Phase");

    // Estimate setPaused cost
    const setPausedGas = await contract.estimateGas.setPaused(false)
        .catch(() => ethers.BigNumber.from("50000")); // Fallback estimate

    await formatGasAndCost(setPausedGas, gasPrice, "Unpause Contract");

    // Total cost estimation
    const totalGas = gasEstimate.add(setPhaseGas).add(setPausedGas);
    const totalCost = await formatGasAndCost(totalGas, gasPrice, "Total (including post-deployment)");

    // Safety margin
    console.log("\nRecommended Safety Margin:");
    console.log("-------------------------");
    console.log(`Recommended to have at least: ${ethers.utils.formatEther(totalCost.mul(12).div(10))} ETH`);
    console.log("(120% of estimated total cost)");

    // Balance check
    if (balance.lt(totalCost.mul(12).div(10))) {
        console.warn("\n⚠️ WARNING: Account balance may be insufficient including safety margin!");
        console.warn("Consider adding more funds to the deployer account.");
    } else {
        console.log("\n✅ Account balance is sufficient for deployment with safety margin.");
    }
}

async function getGasPrice(deployer) {
    if (process.env.GAS_PRICE) {
        return ethers.utils.parseUnits(process.env.GAS_PRICE, "gwei");
    }
    return await deployer.getGasPrice();
}

// Execute estimation
estimateDeploymentGas()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error("\nGas estimation failed:");
        console.error(error);
        process.exit(1);
    });