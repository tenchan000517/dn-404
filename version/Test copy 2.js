// npx hardhat test test/Test.js

const { expect } = require("chai");
const { ethers } = require("hardhat");
const { BigNumber } = require("ethers");

describe("TESTDN404v2 and ExtendedDN404Mirror", function () {
  let TESTDN404v2;
  let ExtendedDN404Mirror;
  let testDN404;
  let mirror;
  let owner;
  let allowedPlatform;
  let notAllowedPlatform;
  let user1;
  let user2;

  beforeEach(async function () {
    [owner, allowedPlatform, notAllowedPlatform, user1, user2] = await ethers.getSigners();

    // Deploy TESTDN404v2
    TESTDN404v2 = await ethers.getContractFactory("TESTDN404v2");
    testDN404 = await TESTDN404v2.deploy(
      "TestToken",
      "TT",
      ethers.utils.keccak256(ethers.utils.toUtf8Bytes("dummy")),
      ethers.utils.parseEther("0.1"),
      ethers.utils.parseEther("0.05"),
      1000,
      owner.address
    );
    await testDN404.deployed();

    // Get the address of the deployed ExtendedDN404Mirror
    const mirrorAddress = await testDN404.mirror();
    ExtendedDN404Mirror = await ethers.getContractFactory("ExtendedDN404Mirror");
    mirror = await ExtendedDN404Mirror.attach(mirrorAddress);

    // Verify that the owner has DEFAULT_ADMIN_ROLE and ADMIN_ROLE
    const DEFAULT_ADMIN_ROLE = await mirror.DEFAULT_ADMIN_ROLE();
    const ADMIN_ROLE = await mirror.ADMIN_ROLE();
    expect(await mirror.hasRole(DEFAULT_ADMIN_ROLE, owner.address)).to.be.true;
    expect(await mirror.hasRole(ADMIN_ROLE, owner.address)).to.be.true;

    // Set up the contract for testing
    await testDN404.toggleLive();
    await mirror.setCALLevel(2);
    await mirror.addAddressToCAL(2, allowedPlatform.address);
  });

  it("Should set up roles correctly", async function () {
    const MINTER_ROLE = await mirror.MINTER_ROLE();
    expect(await mirror.hasRole(MINTER_ROLE, owner.address)).to.be.true;
  });

  it("Should set CAL level correctly", async function () {
    expect((await mirror.calLevel()).toString()).to.equal('2');
});

  it("Should add address to CAL correctly", async function () {
    const allowedContracts = await mirror.getCALAllowedContracts(2);
    expect(allowedContracts).to.include(allowedPlatform.address);
  });

  it("Should allow minting by owner", async function () {
    await testDN404.connect(owner).mint(1, { value: ethers.utils.parseEther("0.1") });
    expect(await testDN404.balanceOf(owner.address).toString()).to.equal(ethers.utils.parseUnits("1", 18));
  });

  it("Should allow listing by allowed platform", async function () {
    await testDN404.connect(owner).mint(1, { value: ethers.utils.parseEther("0.1") });
    await testDN404.connect(owner).setApprovalForAll(allowedPlatform.address, true);
    
    // Simulate listing by transferring to the platform
    await expect(testDN404.connect(allowedPlatform).transferFrom(owner.address, allowedPlatform.address, 1))
      .to.not.be.reverted;
  });

  it("Should not allow listing by not allowed platform", async function () {
    await testDN404.connect(owner).mint(1, { value: ethers.utils.parseEther("0.1") });
    await testDN404.connect(owner).setApprovalForAll(notAllowedPlatform.address, true);
    
    // Simulate listing by transferring to the platform
    await expect(testDN404.connect(notAllowedPlatform).transferFrom(owner.address, notAllowedPlatform.address, 1))
      .to.be.revertedWith("Transfer not allowed");
  });

  it("Should allow transfer by allowed platform", async function () {
    await testDN404.connect(owner).mint(1, { value: ethers.utils.parseEther("0.1") });
    await testDN404.connect(owner).setApprovalForAll(allowedPlatform.address, true);
    
    await expect(testDN404.connect(allowedPlatform).transferFrom(owner.address, user1.address, 1))
      .to.not.be.reverted;
    
    expect(await testDN404.ownerOf(1)).to.equal(user1.address);
  });

  it("Should not allow transfer by not allowed platform", async function () {
    await testDN404.connect(owner).mint(1, { value: ethers.utils.parseEther("0.1") });
    await testDN404.connect(owner).setApprovalForAll(notAllowedPlatform.address, true);
    
    await expect(testDN404.connect(notAllowedPlatform).transferFrom(owner.address, user1.address, 1))
      .to.be.revertedWith("Transfer not allowed");
  });

  it("Should allow owner to transfer their own tokens", async function () {
    await testDN404.connect(owner).mint(1, { value: ethers.utils.parseEther("0.1") });
    
    await expect(testDN404.connect(owner).transfer(user1.address, ethers.utils.parseUnits("1", 18)))
      .to.not.be.reverted;
    
    expect(await testDN404.balanceOf(user1.address).toString()).to.equal(ethers.utils.parseUnits("1", 18));
  });

  it("Should update CAL level and allowed addresses correctly", async function () {
    await mirror.connect(owner).setCALLevel(3);
    await mirror.connect(owner).addAddressToCAL(3, user2.address);

    expect((await mirror.calLevel()).toString()).to.equal('3');
    expect(await mirror.getCALAllowedContracts(3)).to.include(user2.address);
  });

  it("Should handle fractional token transfers correctly", async function () {
    await testDN404.connect(owner).mint(1, { value: ethers.utils.parseEther("0.1") });
    
    // Transfer 0.5 tokens
    await expect(testDN404.connect(owner).transfer(user1.address, ethers.utils.parseUnits("0.5", 18)))
      .to.not.be.reverted;
    
      expect((await testDN404.balanceOf(owner.address)).toString()).to.equal(ethers.utils.parseUnits("1", 18).toString());
      expect((await testDN404.balanceOf(user1.address)).toString()).to.equal(ethers.utils.parseUnits("0.5", 18).toString());
  });
});
