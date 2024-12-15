async function main() {
    const [deployer] = await hre.ethers.getSigners();
  
    console.log("Deploying contracts with the account:", deployer.address);
  
    // ContractAllowList をデプロイ
    const ContractAllowList = await hre.ethers.getContractFactory("ContractAllowList");
    const cal = await ContractAllowList.deploy([deployer.address]);
  
    await cal.deployed();
  
    console.log("ContractAllowList deployed to:", cal.address);
  
    // 各レベルにアドレスを追加
    const addressesToAdd = {
      1: ["0x1E0049783F008A0085193E00003D00cd54003c71"],
      2: [
        "0x9A1D00bEd7CD04BCDA516d721A596eb22Aac6834",
        "0x1E0049783F008A0085193E00003D00cd54003c71"
      ],
      3: [
        "0x1E0049783F008A0085193E00003D00cd54003c71",
        "0x9A1D00bEd7CD04BCDA516d721A596eb22Aac6834",
        "0x2f18F339620a63e43f0839Eeb18D7de1e1Be4DfB",
        "0xF849de01B080aDC3A814FaBE1E2087475cF2E354",
        "0x000000000060C4Ca14CfC4325359062ace33Fe3D",
        "0x4feE7B061C97C9c496b01DbcE9CDb10c02f0a0Be"
      ]
    };
  
    // 現在の maxLevel を表示して確認
    const currentMaxLevel = await cal.maxLevel();
    console.log("Current maxLevel is:", currentMaxLevel.toString());
  
    // レベル順に順次追加
    for (const level of Object.keys(addressesToAdd).sort((a, b) => a - b)) {
      const addresses = addressesToAdd[level];
      for (const address of addresses) {
        try {
          await cal.addAllowed(address, level);
          console.log(`Added ${address} to level ${level}`);
        } catch (error) {
          console.error(`Error adding ${address} to level ${level}:`, error.message);
        }
      }
    }
  
    console.log("All addresses added successfully");
  
    // コントラクトを検証
    console.log("Verifying contract...");
    await hre.run("verify:verify", {
      address: cal.address,
      constructorArguments: [[deployer.address]],
    });
  }
  
  main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });
