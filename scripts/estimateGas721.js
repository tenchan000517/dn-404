const hre = require("hardhat");
const { ethers } = require("hardhat");

async function estimateDeploymentGas() {
    const [deployer] = await ethers.getSigners();

    console.log("Account balance:", ethers.utils.formatEther(await deployer.getBalance()), "ETH");
    console.log("Deploying with account:", deployer.address);

    // Get gas price
    const gasPrice = await deployer.getGasPrice();
    console.log(`\nCurrent gas price: ${ethers.utils.formatUnits(gasPrice, "gwei")} Gwei`);

    // Approximate deployment gas based on contract size
    // Using a conservative estimate for a large contract
    const deploymentGas = ethers.BigNumber.from("4500000"); // Conservative estimate for large contracts
    const deploymentCost = deploymentGas.mul(gasPrice);

    console.log(`\nDeployment Estimates:`);
    console.log(`----------------------`);
    console.log(`Estimated deployment gas: ~${deploymentGas.toString()}`);
    console.log(`Estimated deployment cost: ~${ethers.utils.formatEther(deploymentCost)} ETH`);

    // Common function call estimates
    console.log(`\nCommon Function Call Estimates:`);
    console.log(`-----------------------------`);

    const functionEstimates = {
        setBaseURI: 50000,
        setPause: 30000,
        setCost: 35000,
        setMaxSupply: 35000,
        setPublicSaleMaxMintAmountPerAddress: 35000,
        grantRole: 50000
    };

    let totalSetupGas = ethers.BigNumber.from(0);

    for (const [funcName, gasEstimate] of Object.entries(functionEstimates)) {
        const cost = ethers.BigNumber.from(gasEstimate).mul(gasPrice);
        console.log(`${funcName}:`);
        console.log(`  Gas estimate: ~${gasEstimate}`);
        console.log(`  Cost estimate: ~${ethers.utils.formatEther(cost)} ETH`);
        totalSetupGas = totalSetupGas.add(gasEstimate);
    }

    const totalSetupCost = totalSetupGas.mul(gasPrice);

    console.log(`\nTotal Estimates:`);
    console.log(`----------------`);
    console.log(`Total setup gas estimate: ~${totalSetupGas.toString()}`);
    console.log(`Total setup cost estimate: ~${ethers.utils.formatEther(totalSetupCost)} ETH`);

    const totalCost = deploymentCost.add(totalSetupCost);
    console.log(`\nTotal deployment + setup cost estimate: ~${ethers.utils.formatEther(totalCost)} ETH`);
    
    console.log(`\nRecommended safety margin (150%):`);
    console.log(`Recommended to have: ${ethers.utils.formatEther(totalCost.mul(150).div(100))} ETH`);

    console.log(`\nNote: These are conservative estimates. Actual gas costs may vary based on:`);
    console.log(`- Network conditions`);
    console.log(`- Gas price fluctuations`);
    console.log(`- Contract state and input parameters`);
    console.log(`- Actual contract size and complexity`);
}

estimateDeploymentGas()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });