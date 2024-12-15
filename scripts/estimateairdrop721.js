const hre = require("hardhat");
const { ethers } = require("hardhat");
require('dotenv').config();

async function formatGasAndCost(gasEstimate, gasPrice, description) {
    const cost = gasEstimate.mul(gasPrice);
    console.log(`\n${description}:`);
    console.log(`Gas estimate: ${gasEstimate.toString()} units`);
    console.log(`Cost estimate: ${ethers.utils.formatEther(cost)} ETH`);
    console.log(`Cost in USD: $${(parseFloat(ethers.utils.formatEther(cost)) * process.env.ETH_USD_PRICE || 2000).toFixed(2)}`);
    return { gasEstimate, cost };
}

async function estimateAirdropGas() {
    const [deployer] = await ethers.getSigners();
    const balance = await deployer.getBalance();

    console.log("\nAirdrop Account Info:");
    console.log("------------------------");
    console.log("Address:", deployer.address);
    console.log("Balance:", ethers.utils.formatEther(balance), "ETH");

    const gasPrice = await getGasPrice(deployer);

    console.log("\nGas Price Information:");
    console.log("----------------------");
    console.log(`Current gas price: ${ethers.utils.formatUnits(gasPrice, "gwei")} Gwei`);

    const batchSizes = [10, 20, 50, 100];
    const recipients = Array.from({ length: 200 }, () => ethers.Wallet.createRandom().address);
    const amounts = Array.from({ length: 200 }, () => Math.floor(Math.random() * 5) + 1);

    console.log("\nEstimated Gas Costs for Different Batch Sizes:");
    console.log("--------------------------------------------");

    const estimates = {};
    for (const batchSize of batchSizes) {
        const baseGasPerMint = 65000; // Base gas for each mint
        const overheadGas = 100000; // Transaction overhead
        const gasEstimate = ethers.BigNumber.from(baseGasPerMint)
            .mul(batchSize)
            .add(overheadGas);

        estimates[batchSize] = await formatGasAndCost(
            gasEstimate,
            gasPrice,
            `Airdrop to ${batchSize} addresses in single transaction`
        );

        console.log(`Gas per address for ${batchSize} batch: ${gasEstimate.div(batchSize).toString()} units`);
    }

    // Calculate optimal batch size
    let optimalBatchSize = batchSizes[0];
    let lowestGasPerAddress = estimates[batchSizes[0]].gasEstimate.div(batchSizes[0]);

    for (const batchSize of batchSizes) {
        const gasPerAddress = estimates[batchSize].gasEstimate.div(batchSize);
        if (gasPerAddress.lt(lowestGasPerAddress)) {
            lowestGasPerAddress = gasPerAddress;
            optimalBatchSize = batchSize;
        }
    }

    console.log("\nOptimal Batch Configuration:");
    console.log("---------------------------");
    console.log(`Optimal batch size: ${optimalBatchSize} addresses per transaction`);
    console.log(`Estimated gas per address: ${lowestGasPerAddress.toString()} units`);

    // Calculate total cost for 200 addresses
    const numberOfBatches = Math.ceil(200 / optimalBatchSize);
    const totalGasEstimate = estimates[optimalBatchSize].gasEstimate.mul(numberOfBatches);

    console.log("\nTotal Airdrop Cost Estimation (200 addresses):");
    console.log("------------------------------------------");
    console.log(`Number of transactions needed: ${numberOfBatches}`);
    const totalEstimate = await formatGasAndCost(
        totalGasEstimate,
        gasPrice,
        "Total cost for all 200 addresses"
    );

    // Safety margin
    const safetyMarginETH = totalEstimate.cost.mul(15).div(10);
    console.log("\nRecommended Safety Margin:");
    console.log("-------------------------");
    console.log(`Recommended to have at least: ${ethers.utils.formatEther(safetyMarginETH)} ETH`);
    console.log("(150% of estimated total cost)");

    // Balance check
    if (balance.lt(safetyMarginETH)) {
        console.warn("\n⚠️ WARNING: Account balance may be insufficient including safety margin!");
        console.warn("Consider adding more funds to the deployer account.");
    } else {
        console.log("\n✅ Account balance is sufficient for airdrop with safety margin.");
    }

    console.log("\nTransaction Batching Strategy:");
    console.log("--------------------------");
    console.log(`Total number of addresses: 200`);
    console.log(`Recommended batch size: ${optimalBatchSize}`);
    console.log(`Number of transactions needed: ${numberOfBatches}`);
    console.log(`Estimated time between transactions: 1-2 minutes`);
    console.log(`Estimated total time: ${numberOfBatches * 2} minutes (maximum)`);

    console.log("\nNote: These are estimated costs. Actual costs may vary depending on:");
    console.log("- Network conditions");
    console.log("- Contract complexity");
    console.log("- Gas price fluctuations");
    console.log("- Current network congestion");
    console.log("\nIt's recommended to test with a small batch on testnet first.");
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