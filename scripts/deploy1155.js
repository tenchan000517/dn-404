const hre = require("hardhat");
const fs = require('fs');
const path = require('path');

// Logging functions
const createLogDirectory = () => {
    const logDir = path.join(__dirname, 'logs');
    if (!fs.existsSync(logDir)) {
        fs.mkdirSync(logDir, { recursive: true });
    }
    return logDir;
};

const logDeployment = (network, contractName, contractAddress) => {
    const logDir = createLogDirectory();
    const date = new Date().toISOString();
    const scanUrl = `https://${network === 'mainnet' ? '' : network + '.'}etherscan.io/address/${contractAddress}`;

    const networkLogPath = path.join(logDir, `network_logs_${network}.txt`);
    const networkLogEntry = `\n# Date: ${date}\nContract Name: ${contractName}\nContract Address: ${contractAddress}\nEtherscan URL: ${scanUrl}\n`;

    const chronologicalLogPath = path.join(logDir, 'chronological_logs.txt');
    const chronologicalLogEntry = `${date} - ${network} - ${contractName} - ${contractAddress}\n`;

    try {
        fs.appendFileSync(networkLogPath, networkLogEntry);
        fs.appendFileSync(chronologicalLogPath, chronologicalLogEntry);
    } catch (error) {
        console.error('Error writing logs:', error);
    }
};

// Transaction confirmation helper
async function executeWithConfirmation(tx, description) {
    console.log(`Executing ${description}...`);
    const transaction = await tx;
    const receipt = await transaction.wait(2);
    if (receipt.status !== 1) {
        throw new Error(`${description} failed`);
    }
    console.log(`${description} successful`);
    return receipt;
}

async function main() {
    const [deployer] = await hre.ethers.getSigners();

    console.log("Deploying contracts with the account:", deployer.address);
    const balance = await deployer.getBalance();
    console.log("Account balance:", hre.ethers.utils.formatEther(balance), "ETH");

    // Contract configuration
    const config = {
        name: process.env.TOKEN_NAME || "Custom ERC1155",
        symbol: process.env.TOKEN_SYMBOL || "CERC",
        withdrawAddress: process.env.WITHDRAW_ADDRESS || deployer.address,
        maxSupply: parseInt(process.env.MAX_SUPPLY || "100"),
        cost: process.env.MINT_COST ? hre.ethers.utils.parseEther(process.env.MINT_COST) : hre.ethers.utils.parseEther("0"),
        maxMintAmountPerTransaction: parseInt(process.env.MAX_MINT_PER_TX || "5"),
        merkleRoot: process.env.MERKLE_ROOT || "0x0000000000000000000000000000000000000000000000000000000000000000",
        paused: false,
        onlyAllowlisted: false,
        isSBT: process.env.IS_SBT === "true" || false,
        publicSaleMaxMintAmountPerAddress: parseInt(process.env.MAX_MINT_PER_ADDRESS || "5"),
        useInterfaceMetadata: false,
        useBaseURI: true,
        baseURI: process.env.BASE_URI || "https://nft-mint.xyz/data/testmetadata/",
        baseExtension: ".json",
        royaltyReceiver: process.env.ROYALTY_RECEIVER || deployer.address,
        royaltyFeeNumerator: parseInt(process.env.ROYALTY_FEE || "1000")
    };

    console.log("\nDeploying CustomERC1155 Contract...");
    console.log("Config validation result:", config);

    const CustomERC1155 = await hre.ethers.getContractFactory("CustomERC1155");
    const contract = await CustomERC1155.deploy(config);

    console.log("\nWaiting for deployment to be confirmed...");
    await contract.deployTransaction.wait(5); // Wait for 5 block confirmations
    console.log("CustomERC1155 deployed to:", contract.address);

    // 検証前に90秒待機を追加
    console.log("\nWaiting 90 seconds before verification...");
    await new Promise(resolve => setTimeout(resolve, 60000));

    console.log("\nVerifying contract...");
    try {
        await hre.run("verify:verify", {
            address: contract.address,
            constructorArguments: [config]
        });
        console.log("Contract verification successful");
    } catch (error) {
        console.error("Verification error:", error.message);
        console.log("You may need to verify the contract manually");
    }

    // ログの記録
    logDeployment(hre.network.name, "CustomERC1155", contract.address);

    // // Post-deployment setup
    // console.log("\nPerforming post-deployment setup...");
    // try {
    //     // Set initial phase
    //     const initialPhase = {
    //         phaseId: 0,
    //         maxSupply: config.maxSupply,
    //         cost: config.cost,
    //         maxMintAmountPerTransaction: config.maxMintAmountPerTransaction,
    //         merkleRoot: config.merkleRoot
    //     };

    //     const setPhaseTransaction = await contract.setPhase(
    //         initialPhase.phaseId,
    //         initialPhase.maxSupply,
    //         initialPhase.cost,
    //         initialPhase.maxMintAmountPerTransaction,
    //         initialPhase.merkleRoot
    //     );
    //     await executeWithConfirmation(setPhaseTransaction, "Initial phase setup");

    //     if (!config.paused) {
    //         const unpauseTransaction = await contract.setPaused(false);
    //         await executeWithConfirmation(unpauseTransaction, "Unpausing contract");
    //     }
    // } catch (error) {
    //     console.error("Post-deployment setup error:", error.message);
    //     throw error;
    // }

    // Print deployment summary
    console.log("\nDeployment Summary:");
    console.log("--------------------");
    console.log("Contract Address:", contract.address);
    console.log("Network:", hre.network.name);
    console.log("Name:", config.name);
    console.log("Symbol:", config.symbol);
    console.log("Withdraw Address:", config.withdrawAddress);
    console.log("Max Supply:", config.maxSupply);
    console.log("Base URI:", config.baseURI);
    console.log("Is SBT:", config.isSBT);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error("\nDeployment failed:", error);
        process.exit(1);
    });