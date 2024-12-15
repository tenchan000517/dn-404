const hre = require("hardhat");
const { ethers } = require("hardhat");
require('dotenv').config();

async function formatGasAndCost(gasEstimate, gasPrice, description) {
    const cost = gasEstimate.mul(gasPrice);
    console.log(`\n${description}:`);
    console.log(`Gas estimate: ${gasEstimate.toString()} units`);
    console.log(`Cost estimate: ${ethers.utils.formatEther(cost)} ETH`);
    console.log(`Cost in USD: $${(parseFloat(ethers.utils.formatEther(cost)) * process.env.ETH_USD_PRICE || 2000).toFixed(2)}`);
    return cost;
}

async function estimateAirdropGas() {
    // Get deployer account
    const [deployer] = await ethers.getSigners();
    const balance = await deployer.getBalance();

    console.log("\nAirdrop Account Info:");
    console.log("------------------------");
    console.log("Address:", deployer.address);
    console.log("Balance:", ethers.utils.formatEther(balance), "ETH");

    // Get gas price
    const gasPrice = await getGasPrice(deployer);

    console.log("\nGas Price Information:");
    console.log("----------------------");
    console.log(`Current gas price: ${ethers.utils.formatUnits(gasPrice, "gwei")} Gwei`);

    // Generate test addresses
    const recipients = Array.from({ length: 100 }, () => {
        const wallet = ethers.Wallet.createRandom();
        return wallet.address;
    });

    // Estimate gas for different batch sizes
    const batchSizes = [10, 20, 50, 100];
    const baseGasPerTransfer = 65000; // ERC1155のエアドロップの基本ガス代
    const overheadGas = 45000; // トランザクションのオーバーヘッドガス

    console.log("\nEstimated Gas Costs for Different Batch Sizes:");
    console.log("--------------------------------------------");

    const estimates = {};
    for (const batchSize of batchSizes) {
        // バッチサイズごとのガス見積もり
        const gasEstimate = ethers.BigNumber.from(baseGasPerTransfer)
            .mul(batchSize)
            .add(overheadGas);

        estimates[batchSize] = await formatGasAndCost(
            gasEstimate,
            gasPrice,
            `Airdrop to ${batchSize} addresses in single transaction`
        );

        console.log(`Gas per address for ${batchSize} batch: ${gasEstimate.div(batchSize).toString()} units`);
    }

    // Calculate optimal batch size based on gas costs
    let optimalBatchSize = batchSizes[0];
    let lowestGasPerAddress = Infinity;

    for (const batchSize of batchSizes) {
        const gasPerAddress = estimates[batchSize].div(batchSize);
        const gasPerAddressNumber = gasPerAddress.div(gasPrice).toNumber();
        if (gasPerAddressNumber < lowestGasPerAddress) {
            lowestGasPerAddress = gasPerAddressNumber;
            optimalBatchSize = batchSize;
        }
    }

    console.log("\nOptimal Batch Configuration:");
    console.log("---------------------------");
    console.log(`Optimal batch size: ${optimalBatchSize} addresses per transaction`);
    console.log(`Estimated gas per address: ${lowestGasPerAddress} units`);

    // Calculate total cost for all 100 addresses using optimal batch size
    const numberOfBatches = Math.ceil(100 / optimalBatchSize);
    const totalGasEstimate = estimates[optimalBatchSize].div(gasPrice).mul(numberOfBatches);
    
    console.log("\nTotal Airdrop Cost Estimation (100 addresses):");
    console.log("------------------------------------------");
    console.log(`Number of transactions needed: ${numberOfBatches}`);
    const totalCost = await formatGasAndCost(
        totalGasEstimate,
        gasPrice,
        "Total cost for all 100 addresses"
    );

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
        console.log("\n✅ Account balance is sufficient for airdrop with safety margin.");
    }

    console.log("\nNote: These are estimated costs. Actual costs may vary depending on:");
    console.log("- Network conditions");
    console.log("- Contract complexity");
    console.log("- Gas price fluctuations");
    console.log("It's recommended to test with a small batch on testnet first.");
}

async function getGasPrice(deployer) {
    if (process.env.GAS_PRICE) {
        return ethers.utils.parseUnits(process.env.GAS_PRICE, "gwei");
    }
    return await deployer.getGasPrice();
}

// Execute estimation
estimateAirdropGas()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error("\nGas estimation failed:");
        console.error(error);
        process.exit(1);
    });