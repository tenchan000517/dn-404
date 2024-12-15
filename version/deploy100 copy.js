const hre = require("hardhat");
const { ethers } = require("hardhat");

async function main() {
    const [deployer] = await hre.ethers.getSigners();

    console.log("Deploying contracts with the account:", deployer.address);
    const balance = await deployer.getBalance();
    console.log("Account balance:", hre.ethers.utils.formatEther(balance), "ETH");

    // Contract Parameters
    const config = {
        name: "MUTANT ALIENS VILLAIN",
        symbol: "MAV",
        allowlistRoot: ethers.utils.hexZeroPad("0x844459eb1c44a2786fe7106fd8f50dd045e2d69483e20029ab29be9393098578", 32),
        publicPrice: ethers.utils.parseEther("0.01"),
        allowlistPrice: ethers.utils.parseEther("0"),
        initialTokenSupply: ethers.utils.parseEther("15000"),
        initialSupplyOwner: "0x6e723B123e68E7B0A877D905f0848Bf2205C157A",
        contractAllowListProxy: "0xdbaa28cBe70aF04EbFB166b1A3E8F8034e5B9FC7",
        initialWithdrawAddress: deployer.address
    };

    console.log("\nDeploying MAVILLAIN Contract...");
    const MAVILLAIN = await hre.ethers.getContractFactory("MAVILLAIN");
    const contract = await MAVILLAIN.deploy(
        config.name,
        config.symbol,
        config.allowlistRoot,
        config.publicPrice,
        config.allowlistPrice,
        config.initialTokenSupply,
        config.initialSupplyOwner,
        config.contractAllowListProxy,
        config.initialWithdrawAddress
    );

    await contract.deployed();
    console.log("MAVILLAIN deployed to:", contract.address);

    const mirrorAddress = await contract.mirror();
    console.log("ExtendedDN404Mirror deployed to:", mirrorAddress);

    // Wait for deployment to be confirmed
    console.log("\nWaiting for block confirmations...");
    await contract.deployTransaction.wait(5);

    console.log("\nPerforming initial configuration...");
    try {
        // Basic settings
        const tx1 = await contract.setMaxSupply(20000);
        await tx1.wait();
        console.log("Max supply set to 20,000");

        const tx2 = await contract.setMintRatio(1000);
        await tx2.wait();
        console.log("Mint ratio set to 1000");

        const tx3 = await contract.setMaxPerWallet(2000);
        await tx3.wait();
        console.log("Global max per wallet set to 2000");

        // Configure OG/Allowlist phase
        const tx4 = await contract.configurePhase(
            1, // OGList
            ethers.utils.parseEther("0"),
            400,
            config.allowlistRoot,
            { gasLimit: 500000 }
        );
        await tx4.wait();
        console.log("Allowlist phase configured");

        // Configure Public phase
        const tx5 = await contract.configurePhase(
            4, // Public
            ethers.utils.parseEther("0.01"),
            1000,
            ethers.utils.hexZeroPad("0x0", 32),
            { gasLimit: 500000 }
        );
        await tx5.wait();
        console.log("Public sale configured");

        // Configure initial phase
        const tx6 = await contract.setPhase(1, { gasLimit: 300000 }); // Start with OGList phase
        await tx6.wait();
        console.log("Initial phase set to OGList");

        // Enable contract
        const tx7 = await contract.toggleLive({ gasLimit: 300000 });
        await tx7.wait();
        console.log("Contract enabled");

        // Wait a bit before verification
        await new Promise(resolve => setTimeout(resolve, 30000));

        // Verify contracts
        console.log("\nVerifying contracts...");
        await hre.run("verify:verify", {
            address: contract.address,
            constructorArguments: [
                config.name,
                config.symbol,
                config.allowlistRoot,
                config.publicPrice,
                config.allowlistPrice,
                config.initialTokenSupply,
                config.initialSupplyOwner,
                config.contractAllowListProxy,
                config.initialWithdrawAddress
            ],
        });

        console.log("\nVerifying Mirror contract...");
        await hre.run("verify:verify", {
            address: mirrorAddress,
            constructorArguments: [
                deployer.address,
                config.contractAllowListProxy,
                config.initialWithdrawAddress,
                1000
            ],
        });

    } catch (error) {
        console.error("Configuration error:", error);
        if (error.data) {
            const iface = new ethers.utils.Interface(["function Error(string)"]);
            try {
                const decodedError = iface.parseError(error.data);
                console.error("Decoded error:", decodedError);
            } catch (e) {
                console.error("Raw error data:", error.data);
            }
        }
        throw error;
    }

    console.log("\nDeployment Summary:");
    console.log("--------------------");
    console.log("MAVILLAIN Address:", contract.address);
    console.log("Mirror Address:", mirrorAddress);
    console.log("Network:", hre.network.name);
    console.log("Max Supply: 20,000");
    console.log("Initial Supply:", ethers.utils.formatEther(config.initialTokenSupply));
    console.log("Initial Supply Owner:", config.initialSupplyOwner);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });