const hre = require("hardhat");
const { ethers } = require("hardhat");

async function estimateDeploymentGas() {
    const [deployer] = await ethers.getSigners();

    console.log("Account balance:", ethers.utils.formatEther(await deployer.getBalance()), "ETH");
    console.log("Deploying with account:", deployer.address);

    // Get contract factory
    const ContractFactory = await ethers.getContractFactory("TESTJAMDAO");

    // Estimate deployment transaction gas
    const deployTransaction = await ContractFactory.getDeployTransaction();
    const gasEstimate = await deployer.estimateGas(deployTransaction);
    const gasPrice = await deployer.getGasPrice();

    const deploymentCost = gasEstimate.mul(gasPrice);

    console.log(`Gas price: ${ethers.utils.formatUnits(gasPrice, "gwei")} Gwei`);
    console.log(`TESTJAMDAO gas estimate: ${gasEstimate.toString()}`);
    console.log(`TESTJAMDAO deployment cost: ${ethers.utils.formatEther(deploymentCost)} ETH`);

    // Estimate post-deployment setup costs
    const mockContract = await ContractFactory.deploy();
    
    // Estimate gas for common setup functions
    console.log("\nEstimating setup costs:");
    
    const setBaseURIGas = await mockContract.estimateGas.setBaseURI("https://example.com/");
    console.log(`setBaseURI gas estimate: ${setBaseURIGas.toString()}`);
    
    const setPauseGas = await mockContract.estimateGas.setPause(false);
    console.log(`setPause gas estimate: ${setPauseGas.toString()}`);
    
    const setCostGas = await mockContract.estimateGas.setCost(ethers.utils.parseEther("0.1"));
    console.log(`setCost gas estimate: ${setCostGas.toString()}`);

    const totalSetupGas = setBaseURIGas.add(setPauseGas).add(setCostGas);
    const totalSetupCost = totalSetupGas.mul(gasPrice);

    console.log(`\nTotal setup gas estimate: ${totalSetupGas.toString()}`);
    console.log(`Total setup cost: ${ethers.utils.formatEther(totalSetupCost)} ETH`);

    const totalCost = deploymentCost.add(totalSetupCost);
    console.log(`\nTotal deployment + setup cost: ${ethers.utils.formatEther(totalCost)} ETH`);
}

estimateDeploymentGas()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });