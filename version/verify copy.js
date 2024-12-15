const hre = require("hardhat");

async function main() {
  const contractAddress = "0xfba3BB65D179F9Dcd51a3b2B71D43ABBd0f6F0C6";  // デプロイされたアドレスに更新
  const tokenName = "MyToken";
  const tokenSymbol = "MTK";
  const initialSupply = "1000000";

  console.log("Verifying contract...");
  try {
    await hre.run("verify:verify", {
      address: contractAddress,
      constructorArguments: [
        tokenName,
        tokenSymbol,
        initialSupply,
      ],
    });
    console.log("Contract verified successfully");
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