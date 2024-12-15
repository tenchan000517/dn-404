const hre = require("hardhat");

async function main() {
    const contractAddress = "0x934E48a71C80424261038cD7d96Ff5389eA27713";
    
    // コントラクトの検証に必要なコンストラクタ引数
    const constructorArgs = [
        "0xDC68E2aF8816B3154c95dab301f7838c7D83A0Ba",  // initialSupplyOwner
        "0xdbaa28cbe70af04ebfb166b1a3e8f8034e5b9fc7",  // contractAllowListProxy
        "0xDC68E2aF8816B3154c95dab301f7838c7D83A0Ba",  // initialWithdrawAddress - デプロイ時のアドレスを入れてください
        "0x1234567890abcdef1234567890abcdef12345678"    // initialForwarder
    ];

    console.log("Starting contract verification...");
    console.log("Contract address:", contractAddress);
    console.log("Constructor arguments:", constructorArgs);

    try {
        await hre.run("verify:verify", {
            address: contractAddress,
            constructorArguments: constructorArgs,
        });
        console.log("Verification successful!");
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