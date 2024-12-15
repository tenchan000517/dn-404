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

async function main() {
    const [deployer] = await hre.ethers.getSigners();

    console.log("Deploying contracts with the account:", deployer.address);
    const balance = await deployer.getBalance();
    console.log("Account balance:", hre.ethers.utils.formatEther(balance), "ETH");

    const config = {
        initialMaxSupply: "200000000",
        initialSupply: "200000000", // 2億トークン
        // テストネット用初期供給アドレス
        initialSupplyAddress: "0x33fb3aD653B212a7FE898F5a31295dd25cCbd5aC",
        // メインネット用初期供給アドレス (コメントアウト)
        // initialSupplyAddress: "0x33fb3aD653B212a7FE898F5a31295dd25cCbd5aC",
    };

    console.log("\nDeploying POPOPO Token Contract...");
    const POPOPO = await ethers.getContractFactory("POPOPO");

    const contract = await POPOPO.deploy(
        hre.ethers.utils.parseEther(config.initialMaxSupply),
        hre.ethers.utils.parseEther(config.initialSupply),
        config.initialSupplyAddress
    );

    await contract.deployed();
    console.log("POPOPO token deployed to:", contract.address);

    console.log("\nWaiting for deployment to be confirmed...");
    await contract.deployTransaction.wait(5);

    console.log("\nVerifying contract...");
    try {
        await hre.run("verify:verify", {
            address: contract.address,
            constructorArguments: [
                hre.ethers.utils.parseEther(config.initialMaxSupply),
                hre.ethers.utils.parseEther(config.initialSupply),
                config.initialSupplyAddress
            ],
        });
        console.log("Contract verification successful");
    } catch (error) {
        console.error("Verification error:", error);
    }

    // 追加のセットアップ操作
    console.log("\nPerforming additional setup...");
    try {
        // オプション: 必要に応じて追加のMINTER_ROLEを付与
        // const additionalMinter = "0x...";
        // await contract.grantMinterRole(additionalMinter);
        
        // トークンの詳細情報を取得
        const decimals = await contract.decimals();
        const totalSupply = await contract.totalSupply();
        const maxSupply = await contract.maxSupply();
        
        console.log("\nToken Details:");
        console.log("Decimals:", decimals.toString());
        console.log("Total Supply:", hre.ethers.utils.formatEther(totalSupply));
        console.log("Max Supply:", hre.ethers.utils.formatEther(maxSupply));
    } catch (error) {
        console.error("Setup error:", error);
    }

    logDeployment(hre.network.name, "POPOPO", contract.address);

    console.log("\nDeployment Summary:");
    console.log("--------------------");
    console.log("POPOPO Token Address:", contract.address);
    console.log("Network:", hre.network.name);
    console.log("Initial Max Supply:", config.initialMaxSupply);
    console.log("Initial Supply:", config.initialSupply);
    console.log("Initial Supply Address:", config.initialSupplyAddress);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });