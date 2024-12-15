const hre = require("hardhat");
const fs = require('fs');
const path = require('path');

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
    const polygonscanUrl = `https://${network === 'polygon' ? '' : network + '.'}polygonscan.com/address/${contractAddress}`;

    // ネットワークごとのログ
    const networkLogPath = path.join(logDir, `network_logs_${network}.txt`);
    const networkLogEntry = `\n# Date: ${date}\nContract Name: ${contractName}\nContract Address: ${contractAddress}\nPolygonscan URL: ${polygonscanUrl}\n`;

    // 時系列ログ
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
    console.log("Account balance:", hre.ethers.utils.formatEther(balance), "MATIC");

    // TESTDN404のデプロイ
    const TESTDN404 = await hre.ethers.getContractFactory("TESTDN404v2");
    
    // コンストラクタ引数を設定
    const name = "TESTDN404928";
    const symbol = "TDN";
    const allowlistRoot = []; // この値は適切なMerkleツリーのルートに置き換えてください
    const publicPrice = hre.ethers.utils.parseEther("0"); // 例: 0.1 MATIC
    const allowlistPrice = hre.ethers.utils.parseEther("0"); // 例: 0.08 MATIC
    const initialTokenSupply = hre.ethers.utils.parseEther("10"); // 10 トークン
    const initialSupplyOwner = deployer.address;
    // const contractAllowListProxy = "0x1234567890123456789012345678901234567890"; // この値は適切なアドレスに置き換えてください

    const contract = await TESTDN404.deploy(
        name,
        symbol,
        allowlistRoot,
        publicPrice,
        allowlistPrice,
        initialTokenSupply,
        initialSupplyOwner,
        contractAllowListProxy
    );

    await contract.deployed();
    console.log("TESTDN404v2 deployed to:", contract.address);

    // ExtendedDN404Mirrorのアドレスを取得
    const mirrorAddress = await contract.mirror();
    console.log("ExtendedDN404Mirror deployed to:", mirrorAddress);

    // ログに記録
    logDeployment(hre.network.name, "TESTDN404v2", contract.address);
    logDeployment(hre.network.name, "ExtendedDN404Mirror", mirrorAddress);

    // 検証プロセスを追加
    console.log("Waiting for a while before verification...");
    await new Promise(resolve => setTimeout(resolve, 60000)); // 60秒待機

    try {
        // TESTDN404の検証
        await hre.run("verify:verify", {
            address: contract.address,
            constructorArguments: [
                name,
                symbol,
                allowlistRoot,
                publicPrice,
                allowlistPrice,
                initialTokenSupply,
                initialSupplyOwner,
                contractAllowListProxy
            ],
        });
        console.log("TESTDN404v2 Verification successful");

        // ExtendedDN404Mirrorの検証
        await hre.run("verify:verify", {
            address: mirrorAddress,
            constructorArguments: [deployer.address],
        });
        console.log("ExtendedDN404Mirror Verification successful");
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