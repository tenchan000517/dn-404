const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("TESTDN404v2 and ExtendedDN404Mirror", function () {
  let TESTDN404v2, ExtendedDN404Mirror;
  let testDN404, mirror;
  let owner, seller, platform;

  beforeEach(async function () {
    [owner, seller, platform] = await ethers.getSigners();

    TESTDN404v2 = await ethers.getContractFactory("TESTDN404v2");
    testDN404 = await TESTDN404v2.deploy(
      "TestToken", "TT",
      ethers.utils.keccak256(ethers.utils.toUtf8Bytes("dummy")),
      ethers.utils.parseEther("0.1"),
      ethers.utils.parseEther("0.05"),
      1000,
      owner.address
    );
    await testDN404.deployed();

    const mirrorAddress = await testDN404.mirror();
    ExtendedDN404Mirror = await ethers.getContractFactory("ExtendedDN404Mirror");
    mirror = await ExtendedDN404Mirror.attach(mirrorAddress);

    await testDN404.toggleLive();
    await mirror.setCALLevel(1);
    // await mirror.addAddressToCAL(1, platform.address);
  });

//   it("Should allow minting by owner", async function () {
//     // 初期の live 状態を確認
//     const initialLiveState = await testDN404.live();
//     console.log("Initial live state:", initialLiveState);

//     // 初期の live 状態が false なら toggleLive() を呼び出す
//     if (!initialLiveState) {
//         await testDN404.toggleLive();
//         console.log("Live state toggled to true.");
//     }

//     // NFTのスキップを無効にする
//     await testDN404.setSkipNFT(false);

//     // NFTのミント
//     const mintTx = await testDN404.mintNFT(1, { value: ethers.utils.parseEther("0.1") });
//     await mintTx.wait();

//     // ミント後の totalSupply を取得して、次のトークンIDを確認
//     const nextTokenId = await mirror.totalSupply();
//     console.log("Next token ID:", nextTokenId.toString());

//     // Token ID がオーナーによって所有されているか確認
//     expect(await mirror.ownerOf(nextTokenId)).to.equal(owner.address);
// });

// it("Should retrieve CAL level and list all registered addresses", async function () {
//     // 現在のCALレベルを取得
//     const currentCALLevel = await mirror.calLevel(); // 修正: CALLevel() から calLevel() に変更
//     console.log("Current CAL Level:", currentCALLevel.toString());

//     // 全ての登録されたアドレスを取得
//     for (let level = 1; level <= currentCALLevel; level++) {
//         const addressesAtLevel = await mirror.getCALAllowedContracts(level);
//         console.log(`Addresses at CAL Level ${level}:`, addressesAtLevel);
//     }

//     // レベルごとの登録アドレスが存在することを確認
//     for (let level = 1; level <= currentCALLevel; level++) {
//         const addressesAtLevel = await mirror.getCALAllowedContracts(level);
//         expect(addressesAtLevel).to.not.be.empty;
//     }
//         // レベルごとのアドレスを取得
//         const levels = [0, 1, 2, 3, 10]; // 0, 1, 2, 3, 10 レベルを対象とする
//         for (let level of levels) {
//             const addresses = await mirror.getCALAllowedContracts(level);
//             console.log(`Addresses at CAL Level ${level}:`, addresses);
//         }
// });

// it("Should approve platform address 0x9A1D00bEd7CD04BCDA516d721A596eb22Aac6834", async function () {
//     // アカウントを取得
//     const [owner, seller, platform] = await ethers.getSigners();

//     // live stateを確認し、falseならtoggleLiveを呼ぶ
//     const liveState = await testDN404.live();
//     console.log("Initial live state:", liveState);

//     if (!liveState) {
//       await testDN404.toggleLive();
//     }

//     // seller にNFTをミント
//     const mintTx = await testDN404.connect(seller).mintNFT(1, { value: ethers.utils.parseEther("0.1") });
//     await mintTx.wait();

//     // seller がNFTの所有者であることを確認
//     const ownerOfToken = await mirror.ownerOf(1);
//     console.log("Owner of Token 1:", ownerOfToken);
//     expect(ownerOfToken).to.equal(seller.address);

//     // プラットフォームにsetApprovalForAllを承認（0x9A1D00bEd7CD04BCDA516d721A596eb22Aac6834）
//     const platformAddress = "0x9A1D00bEd7CD04BCDA516d721A596eb22Aac6834";
//     await expect(mirror.connect(seller).setApprovalForAll(platformAddress, true))
//       .to.not.be.reverted;

//     console.log("Approval for 0x9A1D00bEd7CD04BCDA516d721A596eb22Aac6834 was successful.");
//   });

//   it("Should reject platform address 0x1E0049783F008A0085193E00003D00cd54003c71", async function () {
//     // アカウントを取得
//     const [owner, seller, platform] = await ethers.getSigners();

//     // live stateを確認し、falseならtoggleLiveを呼ぶ
//     const liveState = await testDN404.live();
//     console.log("Initial live state:", liveState);

//     if (!liveState) {
//       await testDN404.toggleLive();
//     }

//     // seller にNFTをミント
//     const mintTx = await testDN404.connect(seller).mintNFT(1, { value: ethers.utils.parseEther("0.1") });
//     await mintTx.wait();

//     // seller がNFTの所有者であることを確認
//     const ownerOfToken = await mirror.ownerOf(1);
//     console.log("Owner of Token 1:", ownerOfToken);
//     expect(ownerOfToken).to.equal(seller.address);

//     // プラットフォームにsetApprovalForAllを拒否（0x1E0049783F008A0085193E00003D00cd54003c71）
//     const platformAddress = "0x1E0049783F008A0085193E00003D00cd54003c71";
//     await expect(mirror.connect(seller).setApprovalForAll(platformAddress, true))
//       .to.be.revertedWith("Operator not allowed");

//     console.log("Approval for 0x1E0049783F008A0085193E00003D00cd54003c71 was rejected as expected.");
//   });

// it("Should approve platform address 0x9A1D00bEd7CD04BCDA516d721A596eb22Aac6834 and check if allowed", async function () {
//     // アカウントを取得
//     const [owner, seller, platform] = await ethers.getSigners();

//     // live stateを確認し、falseならtoggleLiveを呼ぶ
//     const liveState = await testDN404.live();
//     console.log("Initial live state:", liveState);

//     if (!liveState) {
//         await testDN404.toggleLive();
//     }

//     // seller にNFTをミント
//     const mintTx = await testDN404.connect(seller).mintNFT(1, { value: ethers.utils.parseEther("0.1") });
//     await mintTx.wait();

//     // seller がNFTの所有者であることを確認
//     const ownerOfToken = await mirror.ownerOf(1);
//     console.log("Owner of Token 1:", ownerOfToken);
//     expect(ownerOfToken).to.equal(seller.address);

//     // プラットフォームにsetApprovalForAllを承認（0x9A1D00bEd7CD04BCDA516d721A596eb22Aac6834）
//     const platformAddress = "0x9A1D00bEd7CD04BCDA516d721A596eb22Aac6834";
//     await expect(mirror.connect(seller).setApprovalForAll(platformAddress, true))
//         .to.not.be.reverted;

//     console.log("Approval for 0x9A1D00bEd7CD04BCDA516d721A596eb22Aac6834 was successful.");

//     // checkIsAllowedを呼び出して確認
//     const isAllowed = await mirror.checkIsAllowed(platformAddress, seller.address);
//     console.log(`Is platform (${platformAddress}) allowed for seller:`, isAllowed);

//     // isAllowedがtrueであることを確認
//     expect(isAllowed).to.equal(true);
// });

it("Should reject platform address 0x1E0049783F008A0085193E00003D00cd54003c71 and check if not allowed", async function () {
    // アカウントを取得
    const [owner, seller, platform] = await ethers.getSigners();

    // live stateを確認し、falseならtoggleLiveを呼ぶ
    const liveState = await testDN404.live();
    console.log("Initial live state:", liveState);

    if (!liveState) {
        await testDN404.toggleLive();
    }

    // seller にNFTをミント
    const mintTx = await testDN404.connect(seller).mintNFT(1, { value: ethers.utils.parseEther("0.1") });
    await mintTx.wait();

    // seller がNFTの所有者であることを確認
    const ownerOfToken = await mirror.ownerOf(1);
    console.log("Owner of Token 1:", ownerOfToken);
    expect(ownerOfToken).to.equal(seller.address);

    // プラットフォームにsetApprovalForAllを拒否（0x1E0049783F008A0085193E00003D00cd54003c71）
    const platformAddress = "0x1E0049783F008A0085193E00003D00cd54003c71";
    await expect(mirror.connect(seller).setApprovalForAll(platformAddress, true))
        .to.be.revertedWith("Operator not allowed");

    console.log(`Approval for ${platformAddress} was rejected as expected.`);

    // checkIsAllowedを呼び出して確認
    const isAllowed = await mirror.checkIsAllowed(platformAddress, seller.address);
    console.log(`Is platform (${platformAddress}) allowed for seller:`, isAllowed);

    // isAllowedがfalseであることを確認
    expect(isAllowed).to.equal(false);
});

it("Should allow approved platform to transfer NFT", async function () {
    const [owner, seller, platform] = await ethers.getSigners();
    const approvedPlatform = "0x9A1D00bEd7CD04BCDA516d721A596eb22Aac6834";

    // Check live state and toggle if necessary
    const liveState = await testDN404.live();
    console.log("Initial live state:", liveState);
    if (!liveState) {
        await testDN404.toggleLive();
        console.log("Toggled live state to true");
    }

    // Mint NFT to seller
    console.log("Minting NFT to seller...");
    const mintTx = await testDN404.connect(seller).mintNFT(1, { value: ethers.utils.parseEther("0.1") });
    await mintTx.wait();
    console.log("Minted NFT to seller:", seller.address);

    // Verify seller is the owner of the NFT
    const tokenId = 1; // Assuming the first minted token has ID 1
    const ownerOfToken = await mirror.ownerOf(tokenId);
    expect(ownerOfToken).to.equal(seller.address);
    console.log("Verified seller is the owner of NFT", tokenId);

    // Approve platform for setApprovalForAll
    await mirror.connect(seller).setApprovalForAll(approvedPlatform, true);
    console.log("Approved platform for setApprovalForAll:", approvedPlatform);

    // Check if platform is approved
    const isApproved = await mirror.isApprovedForAll(seller.address, approvedPlatform);
    console.log("Is platform approved:", isApproved);

    // Check current CAL level
    const calLevel = await mirror.calLevel();
    console.log("Current CAL level:", calLevel.toString());

    // Check if platform is in the allowed list for the current CAL level
    const isAllowed = await mirror.checkIsAllowed(approvedPlatform, seller.address);
    console.log("Is platform in allowed list:", isAllowed);

    // Fund the approved platform account with some ETH
    await owner.sendTransaction({
        to: approvedPlatform,
        value: ethers.utils.parseEther("1.0")
    });

    await network.provider.request({
        method: "hardhat_impersonateAccount",
        params: [approvedPlatform],
    });
    const impersonatedSigner = await ethers.getSigner(approvedPlatform);

    console.log("Impersonated signer balance:", ethers.utils.formatEther(await impersonatedSigner.getBalance()));

    // Verify token exists before transfer
    const tokenExists = await mirror.ownerOf(tokenId).catch(() => false);
    console.log("Token exists before transfer:", tokenExists);    

    // Attempt to transfer NFT using the approved platform
    try {
        await mirror.connect(impersonatedSigner).transferFrom(seller.address, platform.address, tokenId);
        console.log("Approved platform successfully transferred the NFT.");
    } catch (error) {
        console.error("Error during transfer:", error.message);
        throw error;
    }

    // Stop impersonating the account
    await network.provider.request({
        method: "hardhat_stopImpersonatingAccount",
        params: [approvedPlatform],
    });

    // Verify new owner of the NFT
    const newOwner = await mirror.ownerOf(tokenId);
    expect(newOwner).to.equal(platform.address);
    console.log("Verified platform is the new owner of NFT", tokenId);
});

//   it("Should reject unapproved platform from transferring NFT", async function () {
//     // Check live state and toggle if necessary
//     const liveState = await testDN404.live();
//     console.log("Initial live state:", liveState);
//     if (!liveState) {
//       await testDN404.toggleLive();
//       console.log("Toggled live state to true");
//     }

//     // Mint NFT to seller
//     const mintTx = await testDN404.connect(seller).mintNFT(1, { value: ethers.utils.parseEther("0.1") });
//     await mintTx.wait();
//     console.log("Minted NFT to seller:", seller.address);

//     // Verify seller is the owner of the NFT
//     const ownerOfToken = await mirror.ownerOf(1);
//     expect(ownerOfToken).to.equal(seller.address);
//     console.log("Verified seller is the owner of NFT 1");

//     // Reject platform for setApprovalForAll
//     const rejectedPlatform = "0x1E0049783F008A0085193E00003D00cd54003c71";
//     await mirror.connect(seller).setApprovalForAll(rejectedPlatform, false);
//     console.log("Rejected platform for setApprovalForAll:", rejectedPlatform);

//     // Check if platform is approved
//     const isApproved = await mirror.isApprovedForAll(seller.address, rejectedPlatform);
//     console.log("Is platform approved:", isApproved);

//     // Check current CAL level
//     const calLevel = await mirror.calLevel();
//     console.log("Current CAL level:", calLevel.toString());

//     // Check if platform is in the allowed list for the current CAL level
//     const isAllowed = await mirror.checkIsAllowed(rejectedPlatform, seller.address);
//     console.log("Is platform in allowed list:", isAllowed);

//     // Attempt to transfer NFT using unapproved platform
//     try {
//       await mirror.connect(unapprovedPlatform).transferFrom(seller.address, unapprovedPlatform.address, 1);
//       throw new Error("Transfer should have failed but succeeded");
//     } catch (error) {
//       if (error.message.includes("Caller is not allowed to transfer")) {
//         console.log("Unapproved platform was correctly rejected from transferring the NFT.");
//       } else {
//         console.error("Unexpected error:", error.message);
//         throw error;
//       }
//     }

//     // Verify seller is still the owner of the NFT
//     const finalOwner = await mirror.ownerOf(1);
//     expect(finalOwner).to.equal(seller.address);
//     console.log("Verified seller is still the owner of NFT 1");
//   });

// it("Should allow listing by approved platform", async function () {
//     // アカウントを取得
//     const [owner, seller, platform] = await ethers.getSigners();

//     // live stateを確認し、falseならtoggleLiveを呼ぶ
//     const liveState = await testDN404.live();
//     console.log("Initial live state:", liveState);

//     if (!liveState) {
//         await testDN404.toggleLive();
//     }

//     // seller にNFTをミント
//     const mintTx = await testDN404.connect(seller).mintNFT(1, { value: ethers.utils.parseEther("0.1") });
//     await mintTx.wait();

//     // seller がNFTの所有者であることを確認
//     const ownerOfToken = await mirror.ownerOf(1);
//     console.log("Owner of Token 1:", ownerOfToken);
//     expect(ownerOfToken).to.equal(seller.address);

//     // seller がプラットフォームに全てのNFTを転送可能にする
//     await mirror.connect(seller).setApprovalForAll(platform.address, true);

//     // プラットフォームがNFTを転送できることを確認
//     await expect(mirror.connect(platform).transferFrom(seller.address, platform.address, 1))
//         .to.not.be.reverted;
// });





// it("Should not allow listing by unapproved address", async function () {
//     await testDN404.mintNFT(1, { value: ethers.utils.parseEther("0.1") });  // mintNFT関数を使用
//     await expect(testDN404.connect(buyer).transferFrom(seller.address, buyer.address, 1))
//         .to.be.revertedWith("ERC721: transfer caller is not owner nor approved");
// });



// it("Should allow purchase through platform", async function () {
//     await testDN404.mintNFT(1, { value: ethers.utils.parseEther("0.1") });  // mintNFT関数を使用
//     await testDN404.connect(seller).setApprovalForAll(platform.address, true);
//     await expect(testDN404.connect(platform).transferFrom(seller.address, buyer.address, 1))
//         .to.not.be.reverted;
//     expect(await testDN404.ownerOf(1)).to.equal(buyer.address);
// });



//   it("Should handle fractional token transfers", async function () {
//     await testDN404.mint(1, { value: ethers.utils.parseEther("0.1") });
    
//     // Transfer 0.5 tokens
//     await expect(testDN404.connect(seller).transfer(buyer.address, ethers.utils.parseUnits("0.5", 18)))
//       .to.not.be.reverted;
    
//     expect(await testDN404.balanceOf(seller.address)).to.equal(ethers.utils.parseUnits("0.5", 18));
//     expect(await testDN404.balanceOf(buyer.address)).to.equal(ethers.utils.parseUnits("0.5", 18));
//   });

//   it("Should update NFT ownership after fractional token transfer reaches threshold", async function () {
//     await testDN404.mint(1, { value: ethers.utils.parseEther("0.1") });
    
//     // Transfer 0.9 tokens
//     await testDN404.connect(seller).transfer(buyer.address, ethers.utils.parseUnits("0.9", 18));
    
//     // Check NFT ownership
//     expect(await mirror.ownerOf(1)).to.equal(buyer.address);
//   });

//   it("Should allow platform to transfer listed NFT", async function () {
//     await testDN404.mint(1, { value: ethers.utils.parseEther("0.1") });
//     await mirror.connect(seller).setApprovalForAll(platform.address, true);
    
//     // Simulate platform transferring listed NFT
//     await expect(mirror.connect(platform).transferFrom(seller.address, buyer.address, 1))
//       .to.not.be.reverted;
    
//     expect(await mirror.ownerOf(1)).to.equal(buyer.address);
//   });

//   it("Should not allow transfer if CAL level is not met", async function () {
//     await testDN404.mint(1, { value: ethers.utils.parseEther("0.1") });
//     await mirror.connect(seller).setApprovalForAll(platform.address, true);
    
//     // Lower CAL level
//     await mirror.setCALLevel(3);
    
//     // Attempt transfer
//     await expect(mirror.connect(platform).transferFrom(seller.address, buyer.address, 1))
//       .to.be.revertedWith("Transfer not allowed");
//   });
});