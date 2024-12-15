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
        initialTokenSupply: hre.ethers.utils.parseEther("16000"),
        initialSupplyOwner: "0x1eF7c1596d893eb46826557841c5c7579eFE0fbb",
        contractAllowListProxy: "0xdbaa28cbe70af04ebfb166b1a3e8f8034e5b9fc7",
        initialWithdrawAddress: deployer.address,
        initialForwarder: "0x1234567890abcdef1234567890abcdef12345678"
    };

    console.log("\nDeploying MAVILLAIN Contract...");
    const MAVILLAIN = await hre.ethers.getContractFactory("MAVILLAIN");
    const contract = await MAVILLAIN.deploy(
        config.initialTokenSupply,
        config.initialSupplyOwner,
        config.contractAllowListProxy,
        config.initialWithdrawAddress,
        config.initialForwarder
    );

    await contract.deployed();
    console.log("MAVILLAIN deployed to:", contract.address);

    const mirrorAddress = await contract.mirror();
    console.log("MUTANT_ALIENS_VILLAIN deployed to:", mirrorAddress);

    console.log("\nWaiting for deployment to be confirmed...");
    await contract.deployTransaction.wait(5);

    console.log("\nVerifying contracts...");
    try {
        await hre.run("verify:verify", {
            address: contract.address,
            constructorArguments: [
                config.initialTokenSupply,
                config.initialSupplyOwner,
                config.contractAllowListProxy,
                config.initialWithdrawAddress,
                config.initialForwarder
            ],
        });
        console.log("MAVILLAIN verification successful");

        await hre.run("verify:verify", {
            address: mirrorAddress,
            constructorArguments: [
                deployer.address,
                config.contractAllowListProxy,
                config.initialWithdrawAddress
            ],
        });
        console.log("Mirror contract verification successful");
    } catch (error) {
        console.error("Verification error:", error);
    }

    logDeployment(hre.network.name, "MAVILLAIN", contract.address);
    logDeployment(hre.network.name, "MUTANT_ALIENS_VILLAIN", mirrorAddress);

    console.log("\nDeployment Summary:");
    console.log("--------------------");
    console.log("MAVILLAIN Address:", contract.address);
    console.log("Mirror Address:", mirrorAddress);
    console.log("Network:", hre.network.name);
    console.log("Initial Supply Owner:", config.initialSupplyOwner);
    console.log("Initial Supply Amount:", hre.ethers.utils.formatEther(config.initialTokenSupply));
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });