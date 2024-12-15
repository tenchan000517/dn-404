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

    // Deploy TESTJAMDAO
    console.log("\nDeploying TESTJAMDAO Contract...");
    const TESTJAMDAO = await hre.ethers.getContractFactory("TESTJAMDAO");
    const contract = await TESTJAMDAO.deploy();

    await contract.deployed();
    console.log("TESTJAMDAO deployed to:", contract.address);

    console.log("\nWaiting for deployment to be confirmed...");
    await contract.deployTransaction.wait(5);

    console.log("\nVerifying contract...");
    try {
        await hre.run("verify:verify", {
            address: contract.address,
            constructorArguments: [],
        });
        console.log("Contract verification successful");
    } catch (error) {
        console.error("Verification error:", error);
    }

    logDeployment(hre.network.name, "TESTJAMDAO", contract.address);

    console.log("\nDeployment Summary:");
    console.log("--------------------");
    console.log("TESTJAMDAO Address:", contract.address);
    console.log("Network:", hre.network.name);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });