const { ethers } = require("hardhat");

async function main() {
  console.log("Starting deployment cost estimation for POPOPO token...");
  
  const maxSupply = BigInt("200000000000000000000000000"); // 200M with 18 decimals
  
  try {
    const POPOPO = await ethers.getContractFactory("contracts/ERC20.sol:POPOPO");
    const deployTx = await POPOPO.getDeployTransaction(maxSupply);
    const deploymentBytecode = deployTx.data;
    
    // Estimate gas
    const gasEstimate = await ethers.provider.estimateGas({
      data: deploymentBytecode,
      value: BigInt(0)
    });
    const deploymentGasEstimate = BigInt(gasEstimate.toString());

    // Get gas price
    const feeData = await ethers.provider.getFeeData();
    const baseGasPrice = BigInt(feeData.gasPrice.toString());
    console.log(`Raw base gas price: ${baseGasPrice.toString()} wei`);
    
    // Add 20% buffer to gas price
    const currentGasPrice = (baseGasPrice * BigInt(120)) / BigInt(100);

    // Calculate total gas cost in wei
    const deploymentCost = currentGasPrice * deploymentGasEstimate;
    
    // Convert to ETH (1 ETH = 10^18 wei)
    // Use string manipulation to maintain precision
    const weiString = deploymentCost.toString().padStart(19, '0');
    const ethInteger = weiString.slice(0, -18) || '0';
    const ethDecimal = weiString.slice(-18);
    const costInEth = parseFloat(ethInteger + '.' + ethDecimal);
    const costInUSD = costInEth * 2500;

    // Add 10% buffer to total cost
    const bufferedCostInEth = costInEth * 1.1;
    const bufferedCostInUSD = bufferedCostInEth * 2500;

    // Calculate gas price in gwei (1 gwei = 10^9 wei)
    const gasPriceInGwei = Number(currentGasPrice) / 1e9;

    console.log("\nToken Configuration:");
    console.log("------------------------");
    console.log(`Initial Supply: 200,000,000 tokens`);
    console.log(`Max Supply: 200,000,000 tokens`);
    
    console.log("\nDeployment Cost Estimation (with safety buffer):");
    console.log("------------------------");
    console.log(`Estimated Gas Units: ${deploymentGasEstimate.toString()}`);
    console.log(`Current Gas Price (with buffer): ${gasPriceInGwei.toFixed(4)} gwei`);
    console.log(`Base Estimated Cost: ${costInEth.toFixed(6)} ETH ($${costInUSD.toFixed(2)})`);
    console.log(`Recommended minimum balance: ${bufferedCostInEth.toFixed(6)} ETH ($${bufferedCostInUSD.toFixed(2)})`);
    
    console.log("\nSafety Margins Included:");
    console.log("- 20% gas price buffer");
    console.log("- 10% total cost buffer");
    console.log("- Full constructor execution cost");

    console.log("\nDebug Information:");
    console.log("------------------------");
    console.log(`Base Gas Price (wei): ${baseGasPrice.toString()}`);
    console.log(`Buffered Gas Price (wei): ${currentGasPrice.toString()}`);
    console.log(`Total Gas Cost (wei): ${deploymentCost.toString()}`);

  } catch (error) {
    console.error("Error during estimation:", error);
    throw error;
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});