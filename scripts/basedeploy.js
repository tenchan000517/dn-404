const hre = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);

  const tokenName = "MyToken";
  const tokenSymbol = "MTK";
  const initialSupply = 1000000; // 1,000,000 tokens

  const MyToken = await ethers.getContractFactory("MyToken");
  const myToken = await MyToken.deploy(tokenName, tokenSymbol, initialSupply);

  await myToken.deployed();

  console.log("Token deployed to:", myToken.address);
  console.log("Token Name:", await myToken.name());
  console.log("Token Symbol:", await myToken.symbol());
  console.log("Total Supply:", ethers.utils.formatUnits(await myToken.totalSupply(), 18));
  console.log("Owner Balance:", ethers.utils.formatUnits(await myToken.balanceOf(deployer.address), 18));

  // 検証用のパラメータを出力
  console.log("\nVerification parameters:");
  console.log("npx hardhat verify --network base-sepolia", myToken.address, tokenName, tokenSymbol, initialSupply);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });