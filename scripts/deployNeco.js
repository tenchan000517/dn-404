const hre = require("hardhat");
const fs = require('fs');
const path = require('path');

// ログを保存するためのディレクトリの作成
const createLogDirectory = () => {
    const logDir = path.join(__dirname, 'logs');
    if (!fs.existsSync(logDir)) {
        fs.mkdirSync(logDir, { recursive: true });
    }
    return logDir;
};

// デプロイ情報を記録する関数
const logDeployment = (network, contractName, contractAddress) => {
    const logDir = createLogDirectory();
    const date = new Date().toISOString();
    const etherscanUrl = `https://${network === 'mainnet' ? '' : network + '.'}etherscan.io/address/${contractAddress}`;

    const networkLogPath = path.join(logDir, `network_logs_${network}.txt`);
    const networkLogEntry = `\n# Date: ${date}\nContract Name: ${contractName}\nContract Address: ${contractAddress}\nEtherscan URL: ${etherscanUrl}\n`;

    const chronologicalLogPath = path.join(logDir, 'chronological_logs.txt');
    const chronologicalLogEntry = `${date} - ${network} - ${contractName} - ${contractAddress}\n`;

    try {
        fs.appendFileSync(networkLogPath, networkLogEntry);
        console.log(`ネットワークログを ${networkLogPath} に追加しました。`);

        fs.appendFileSync(chronologicalLogPath, chronologicalLogEntry);
        console.log(`時系列ログを ${chronologicalLogPath} に追加しました。`);
    } catch (error) {
        console.error('ログの書き込み中にエラーが発生しました:', error);
    }
};

async function main() {
    const [deployer] = await hre.ethers.getSigners();

    console.log("Deploying contracts with the account:", deployer.address);
    const balance = await deployer.getBalance();
    console.log("Account balance:", hre.ethers.utils.formatEther(balance), "ETH");

    // NecogeneDN404のデプロイ
    const NecogeneDN404 = await hre.ethers.getContractFactory("NecogeneDN404");

    const name = "NecogeneNFT";
    const symbol = "NEC";
    const allowlistRoot = "0x0000000000000000000000000000000000000000000000000000000000000000"; // 仮のMerkleルート
    const publicPrice = hre.ethers.utils.parseEther("0.1"); // 例: 0.1 ETH
    const allowlistPrice = hre.ethers.utils.parseEther("0.05"); // 例: 0.05 ETH
    const initialTokenSupply = 1000;
    const initialSupplyOwner = deployer.address;

    const contract = await NecogeneDN404.deploy(
        name,
        symbol,
        allowlistRoot,
        publicPrice,
        allowlistPrice,
        initialTokenSupply,
        initialSupplyOwner
    );

    await contract.deployed();
    console.log("NecogeneDN404 deployed to:", contract.address);

    // デプロイ結果をログに記録
    logDeployment(hre.network.name, "NecogeneDN404", contract.address);

    // 60秒待機してから検証プロセスを実行
    console.log("Waiting for a while before verification...");
    await new Promise(resolve => setTimeout(resolve, 60000)); // 60秒待機

    try {
        // NecogeneDN404の検証
        await hre.run("verify:verify", {
            address: contract.address,
            constructorArguments: [
                name,
                symbol,
                allowlistRoot,
                publicPrice,
                allowlistPrice,
                initialTokenSupply,
                initialSupplyOwner
            ],
        });
        console.log("NecogeneDN404 Verification successful");
    } catch (error) {
        console.error("Verification failed:", error);
    }
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
