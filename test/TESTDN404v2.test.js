const { expect } = require("chai");
const { ethers } = require("hardhat");
const { MerkleTree } = require("merkletreejs");
const keccak256 = require("keccak256");

describe("TESTDN404v2", function () {
    let owner;
    let addr1;
    let addr2;
    let addr3;
    let addr4;
    let addrs;
    let contract;
    let merkleTree;
    let merkleTreeWL1;
    let merkleTreeWL2;

    // セールフェーズのenum値
    const SalePhase = {
        NotStarted: 0,
        OGList: 1,
        WL1: 2,
        WL2: 3,
        Public: 4,
        Ended: 5
    };

    // テスト用の定数
    const INITIAL_SUPPLY = ethers.BigNumber.from("0");
    const PUBLIC_PRICE = ethers.utils.parseEther("0.1");
    const ALLOWLIST_PRICE = ethers.utils.parseEther("0.08");
    const MAX_SUPPLY = 100;
    const ZERO_ADDRESS = ethers.constants.AddressZero;
    const ONE_DAY = 86400;

    beforeEach(async function () {
        [owner, addr1, addr2, addr3, addr4, ...addrs] = await ethers.getSigners();

        // OGリストのマークルツリー作成 - 修正版
        const ogAddresses = [addr1, addr2].map(addr => addr.address);
        const ogLeaves = ogAddresses.map(addr => ethers.utils.keccak256(
            ethers.utils.solidityPack(['address'], [addr])
        ));
        merkleTree = new MerkleTree(ogLeaves, keccak256, { sortPairs: true });

        // WL1のマークルツリー作成 - 修正版
        const wl1Addresses = [addr2, addr3].map(addr => addr.address);
        const wl1Leaves = wl1Addresses.map(addr => ethers.utils.keccak256(
            ethers.utils.solidityPack(['address'], [addr])
        ));
        merkleTreeWL1 = new MerkleTree(wl1Leaves, keccak256, { sortPairs: true });

        // WL2のマークルツリー作成 - 修正版
        const wl2Addresses = [addr3, addr4].map(addr => addr.address);
        const wl2Leaves = wl2Addresses.map(addr => ethers.utils.keccak256(
            ethers.utils.solidityPack(['address'], [addr])
        ));
        merkleTreeWL2 = new MerkleTree(wl2Leaves, keccak256, { sortPairs: true });

        // デプロイ引数を明示的に定義
        const deployArgs = {
            name: "TestToken",
            symbol: "TT",
            allowlistRoot: merkleTree.getHexRoot(),
            publicPrice: PUBLIC_PRICE,
            allowlistPrice: ALLOWLIST_PRICE,
            initialSupply: INITIAL_SUPPLY,
            initialSupplyOwner: owner.address,
            contractAllowListProxy: ZERO_ADDRESS,
            allowlistEndTime: Math.floor(Date.now() / 1000) + ONE_DAY
        };

        // コントラクトのデプロイ
        const ContractFactory = await ethers.getContractFactory("TESTDN404v2");
        contract = await ContractFactory.deploy(
            deployArgs.name,
            deployArgs.symbol,
            deployArgs.allowlistRoot,
            deployArgs.publicPrice,
            deployArgs.allowlistPrice,
            deployArgs.initialSupply,
            deployArgs.initialSupplyOwner,
            deployArgs.contractAllowListProxy,
            deployArgs.allowlistEndTime
        );
        await contract.deployed();

        // コントラクトを有効化
        await contract.toggleLive();
    });

    describe("セールフェーズの設定と管理", function () {
        it("各フェーズの設定が正しく行えること", async function () {
            const now = Math.floor(Date.now() / 1000);

            // OGリストフェーズの設定
            await contract.setSaleConfig(
                SalePhase.OGList,
                now,
                now + 86400,
                ethers.utils.parseEther("0.08"),
                2,
                merkleTree.getHexRoot()
            );

            // 設定の確認
            const ogConfig = await contract.getSaleConfig(SalePhase.OGList);
            expect(ogConfig.startTime).to.equal(now);
            expect(ogConfig.endTime).to.equal(now + 86400);
            expect(ogConfig.price).to.equal(ethers.utils.parseEther("0.08"));
            expect(ogConfig.maxPerWallet).to.equal(2);
            expect(ogConfig.merkleRoot).to.equal(merkleTree.getHexRoot());
        });

        it("フェーズの切り替えが正しく行えること", async function () {
            await contract.setPhase(SalePhase.OGList);
            expect(await contract.currentPhase()).to.equal(SalePhase.OGList);

            await contract.setPhase(SalePhase.WL1);
            expect(await contract.currentPhase()).to.equal(SalePhase.WL1);
        });

        it("無効な時間設定でrevertすること", async function () {
            const now = Math.floor(Date.now() / 1000);
            await expect(
                contract.setSaleConfig(
                    SalePhase.OGList,
                    now + 100,
                    now,
                    ethers.utils.parseEther("0.08"),
                    2,
                    merkleTree.getHexRoot()
                )
            ).to.be.revertedWith("Invalid times");
        });
    });

    describe("アローリストミント機能", function () {
        beforeEach(async function () {
            const now = Math.floor(Date.now() / 1000);

            // OGリストフェーズの設定
            await contract.setSaleConfig(
                SalePhase.OGList,
                now,
                now + 86400,
                ALLOWLIST_PRICE,
                2,
                merkleTree.getHexRoot()
            );

            // フェーズをOGListに設定
            await contract.setPhase(SalePhase.OGList);
        });

        it("アローリストに含まれるアドレスがミント可能であること", async function () {
            const leaf = ethers.utils.keccak256(
                ethers.utils.solidityPack(['address'], [addr1.address])
            );
            const proof = merkleTree.getHexProof(leaf);

            await contract.connect(addr1).allowlistMint(
                1,
                proof,
                { value: ALLOWLIST_PRICE }
            );

            expect(await contract.getMintCount(SalePhase.OGList, addr1.address)).to.equal(1);
        });

        it("アローリストに含まれないアドレスがミントできないこと", async function () {
            const leaf = ethers.utils.keccak256(
                ethers.utils.solidityPack(['address'], [addr4.address])
            );
            const proof = merkleTree.getHexProof(leaf);

            await expect(
                contract.connect(addr4).allowlistMint(
                    1,
                    proof,
                    { value: ALLOWLIST_PRICE }
                )
            ).to.be.revertedWithCustomError(contract, "InvalidProof");
        });

        it("ミント制限を超えられないこと", async function () {
            const proof = merkleTree.getHexProof(
                ethers.utils.keccak256(
                    ethers.utils.defaultAbiCoder.encode(['address'], [addr1.address])
                )
            );

            await contract.connect(addr1).allowlistMint(
                2,
                proof,
                { value: ALLOWLIST_PRICE.mul(2) }
            );

            await expect(
                contract.connect(addr1).allowlistMint(
                    1,
                    proof,
                    { value: ALLOWLIST_PRICE }
                )
            ).to.be.revertedWith("ExceedsPhaseLimit");
        });
    });

    describe("フェーズ移行とミント制限", function () {
        it("異なるフェーズで異なるアローリストが機能すること", async function () {
            const now = Math.floor(Date.now() / 1000);

            // WL1フェーズの設定
            await contract.setSaleConfig(
                SalePhase.WL1,
                now,
                now + 86400,
                ALLOWLIST_PRICE,
                1,
                merkleTreeWL1.getHexRoot()
            );

            await contract.setPhase(SalePhase.WL1);

            // addr2はWL1に含まれているのでミント可能
            const proofWL1 = merkleTreeWL1.getHexProof(
                ethers.utils.keccak256(
                    ethers.utils.defaultAbiCoder.encode(['address'], [addr2.address])
                )
            );

            await contract.connect(addr2).allowlistMint(
                1,
                proofWL1,
                { value: ALLOWLIST_PRICE }
            );

            // addr1はWL1に含まれていないのでミント不可
            const proofAddr1 = merkleTreeWL1.getHexProof(
                ethers.utils.keccak256(
                    ethers.utils.defaultAbiCoder.encode(['address'], [addr1.address])
                )
            );

            await expect(
                contract.connect(addr1).allowlistMint(
                    1,
                    proofAddr1,
                    { value: ALLOWLIST_PRICE }
                )
            ).to.be.revertedWith("InvalidProof");
        });

        it("パブリックセールが正しく機能すること", async function () {
            const now = Math.floor(Date.now() / 1000);

            // パブリックセールの設定
            await contract.setSaleConfig(
                SalePhase.Public,
                now,
                now + 86400,
                PUBLIC_PRICE,
                5,
                ZERO_BYTES32
            );

            await contract.setPhase(SalePhase.Public);

            // 誰でもミント可能
            await contract.connect(addr4).mint(
                1,
                { value: PUBLIC_PRICE }
            );

            expect(await contract.getMintCount(SalePhase.Public, addr4.address)).to.equal(1);
        });
    });

    describe("NFTミント機能", function () {
        beforeEach(async function () {
            const now = Math.floor(Date.now() / 1000);

            // OGリストフェーズの設定
            await contract.setSaleConfig(
                SalePhase.OGList,
                now,
                now + 86400,
                ALLOWLIST_PRICE,
                2,
                merkleTree.getHexRoot()
            );

            await contract.setPhase(SalePhase.OGList);
        });

        it("アローリストNFTミントが正しく機能すること", async function () {
            const proof = merkleTree.getHexProof(
                ethers.utils.keccak256(
                    ethers.utils.defaultAbiCoder.encode(['address'], [addr1.address])
                )
            );

            await contract.connect(addr1).allowlistNFTMint(
                1,
                proof,
                { value: ALLOWLIST_PRICE }
            );

            // NFTの所有権確認
            const balance = await contract.balanceOf(addr1.address);
            expect(balance).to.be.gt(0);
        });
    });

    describe("その他の管理機能", function () {
        it("供給上限の設定が機能すること", async function () {
            await contract.setMaxSupply(200);
            expect(await contract.maxSupply()).to.equal(200);
        });

        it("ウォレットあたりの制限設定が機能すること", async function () {
            await contract.setMaxPerWallet(50);
            expect(await contract.maxPerWallet()).to.equal(50);
        });

        it("価格設定が機能すること", async function () {
            const newPublicPrice = ethers.utils.parseEther("0.2");
            const newAllowlistPrice = ethers.utils.parseEther("0.15");
            await contract.setPrices(newPublicPrice, newAllowlistPrice);
            expect(await contract.publicPrice()).to.equal(newPublicPrice);
            expect(await contract.allowlistPrice()).to.equal(newAllowlistPrice);
        });
    });
});