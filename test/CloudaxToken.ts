import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";
import { Cloudax } from "../typechain-types";
import { TestToken } from "../typechain-types";
import { CloudaxTresuary } from "../typechain-types";

describe("Cloudax Token", function () {
  let cloudax: Cloudax, owner, john, jane;
  let testToken: TestToken;
  let cloudaxTresuary: CloudaxTresuary;
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployAndSetup() {
    // Contracts are deployed using the first signer/account by default
    [owner, john, jane] = await ethers.getSigners();

    const Cloudax = await ethers.getContractFactory("Cloudax");
    cloudax = await Cloudax.deploy();

    const TestToken = await ethers.getContractFactory("TestToken");
    testToken = await TestToken.deploy(owner.getAddress());

    // Deploy CloudaxTresuary
    const CloudaxTresuary = await ethers.getContractFactory("CloudaxTresuary");
    cloudaxTresuary = await CloudaxTresuary.deploy(cloudax.getAddress());

    return { cloudax, cloudaxTresuary, testToken, owner, john, jane };
  }

  describe("Token Transactions", function () {
    it("Should deploy the contract with the correct total supply", async () => {
      const { cloudax } = await loadFixture(deployAndSetup);
      const totalSupply = await cloudax.totalSupply();
      const expectedTotalSupply = BigInt(200000000) * BigInt(10 ** 18);
      expect(totalSupply).to.equal(expectedTotalSupply);
    });

    it("Should allow users to transfer tokens", async () => {
      const { cloudax, owner, john } = await loadFixture(deployAndSetup);
      const initialBalanceOwner = await cloudax.balanceOf(owner.address);
      const transferAmount = BigInt(100);
      // setup tresuary
      await cloudax.setupTresuaryAddress(cloudaxTresuary.getAddress());

      // Transfer tokens from owner to user1
      await cloudax.connect(owner).transfer(john.address, transferAmount);

      const finalBalanceOwner = await cloudax.balanceOf(owner.address);
      const finalBalanceUser1 = await cloudax.balanceOf(john.address);

      expect(finalBalanceOwner).to.equal(initialBalanceOwner - transferAmount);
      expect(finalBalanceUser1).to.equal(transferAmount);
    });

    // it("Should allow users to transfer zero tokens", async () => {
    //   const { cloudax, owner, john } = await loadFixture(deployAndSetup);
    //   // setup tresuary
    //   await cloudax
    //     .connect(owner)
    //     .setupTresuaryAddress(cloudaxTresuary.getAddress());
    //   // make token an approved wallet
    //     await cloudaxTresuary.connect(owner).aproveEcoWallet(cloudax.getAddress());
    //   // Enable trading
    //   await cloudax.connect(owner).setTradingEnabled(true);
    //   await cloudax.connect(owner).transfer(john.address, 0);
    //   const finalBalanceUser1 = await cloudax.balanceOf(john.address);
    //   expect(finalBalanceUser1).to.equal(0);
    // });

    it("Should handle concurrent transactions correctly", async () => {
      const { cloudax, owner, john, jane } = await loadFixture(deployAndSetup);
      const transferAmount = ethers.parseEther("100");
      // setup tresuary
      await cloudax
        .connect(owner)
        .setupTresuaryAddress(cloudaxTresuary.getAddress());
      // make token an approved wallet
      await cloudaxTresuary
        .connect(owner)
        .aproveEcoWallet(cloudax.getAddress());
      // Enable trading
      await cloudax.connect(owner).setTradingEnabled(true);
      await Promise.all([
        cloudax.connect(owner).transfer(john.address, transferAmount),
        cloudax.connect(owner).transfer(jane.address, transferAmount),
      ]);
      const finalBalanceJohn = await cloudax.balanceOf(john.address);
      const finalBalanceJane = await cloudax.balanceOf(jane.address);
      expect(finalBalanceJohn).to.equal(transferAmount);
      expect(finalBalanceJane).to.equal(transferAmount);
    });

    it("Should handle large data inputs correctly", async () => {
      const { cloudax, owner, john } = await loadFixture(deployAndSetup);
      const largeAmount = ethers.parseEther("1000000"); // Large token amount
      // setup tresuary
      await cloudax
        .connect(owner)
        .setupTresuaryAddress(cloudaxTresuary.getAddress());
      // make token an approved wallet
      await cloudaxTresuary
        .connect(owner)
        .aproveEcoWallet(cloudax.getAddress());
      // Enable trading
      await cloudax.connect(owner).setTradingEnabled(true);
      await cloudax.connect(owner).transfer(john.address, largeAmount);
      const finalBalanceJohn = await cloudax.balanceOf(john.address);
      expect(finalBalanceJohn).to.equal(largeAmount);
    });
  });

  describe("Blacklisting", function () {
    it("Should allow the owner to blacklist and unblacklist addresses", async () => {
      const { cloudax, owner, jane } = await loadFixture(deployAndSetup);
      // Blacklist jane
      await cloudax.connect(owner).setBlacklisted(jane.address, true);

      // Check if jane is blacklisted
      const isUser1Blacklisted = await cloudax._isBlacklisted(jane.address);
      expect(isUser1Blacklisted).to.be.true;

      // Unblacklist jane
      await cloudax.connect(owner).setBlacklisted(jane.address, false);

      // Check if jane is unblacklisted
      const isJaneUnblacklisted = await cloudax._isBlacklisted(jane.address);
      expect(isJaneUnblacklisted).to.be.false;
    });
  });

  describe("Trading Control", function () {
    it("Should allow the owner to enable and disable trading", async () => {
      const { cloudax, owner, john, jane } = await loadFixture(deployAndSetup);
      // setup tresuary
      await cloudax.setupTresuaryAddress(cloudaxTresuary.getAddress());
      // token transfer
      await cloudax.connect(owner).transfer(john.address, 100);

      // Attempt a token transfer when trading is disabled
      await expect(cloudax.connect(john).transfer(jane.address, 10)).to.be
        .revertedWithCustomError;

      // Enable trading
      await cloudax.connect(owner).setTradingEnabled(true);

      // Attempt a token transfer when trading is enabled
      await cloudax.connect(john).transfer(jane.address, 10);
      const balanceJane = await cloudax.balanceOf(jane.address);
      expect(balanceJane).to.equal(10);
    });
    it("Should revert when trading is disabled", async () => {
      const { cloudax, owner, john } = await loadFixture(deployAndSetup);
      await cloudax.connect(owner).setTradingEnabled(false);
      await expect(cloudax.connect(john).transfer(owner.address, 100)).to.be
        .revertedWithCustomError;
    });
  });

  describe("Presale Integration", function () {
    it("Should allow the owner to set the presale address", async () => {
      const { cloudax, owner, john } = await loadFixture(deployAndSetup);
      const newPresaleAddress = john.address;

      // Set the presale address
      await cloudax.connect(owner).setupPresaleAddress(newPresaleAddress);

      // Check if the presale address is set correctly
      const presaleAddress = await cloudax.presaleAddress();
      expect(presaleAddress).to.equal(newPresaleAddress);
    });
  });

  describe("Receive Tokens", function () {
    it("Should allow users to receive tokens", async () => {
      const { cloudax, owner, john } = await loadFixture(deployAndSetup);
      const initialBalanceJohn = await cloudax.balanceOf(john.address);
      const transferAmount = ethers.parseEther("100");
      // setup tresuary
      await cloudax.setupTresuaryAddress(cloudaxTresuary.getAddress());

      // Transfer tokens from owner to john
      await cloudax.connect(owner).transfer(john.address, transferAmount);

      const finalBalanceJohn = await cloudax.balanceOf(john.address);
      expect(finalBalanceJohn).to.equal(initialBalanceJohn + transferAmount); // Use add method for BigNumber arithmetic
    });
  });

  describe("withdrawTokens", function () {
    it("Should allow the owner to withdraw tokens", async function () {
      const { cloudax, testToken, owner, john } = await loadFixture(
        deployAndSetup
      );

      // Mint some tokens to the contract
      await testToken.mint(owner.address, 1000);

      // tranfer test tokens to the contract
      await testToken.connect(owner).transfer(cloudax.getAddress(), 500);

      // Attempt to withdraw tokens
      await cloudax
        .connect(owner)
        .withdrawTokens(testToken.getAddress(), john.address, 500);

      // Check the recipient's balance
      expect(await testToken.balanceOf(john.address)).to.equal(500);
    });

    it("Should revert if the recipient is the zero address", async function () {
      const { cloudax, testToken } = await loadFixture(deployAndSetup);

      const zeroAddress = "0x0000000000000000000000000000000000000000";

      // Attempt to withdraw tokens to the zero address
      await expect(
        cloudax.withdrawTokens(testToken.getAddress(), zeroAddress, 500)
      ).to.be.revertedWithCustomError;
    });

    it("Should revert when transferring tokens to the zero address", async () => {
      const { cloudax, owner } = await loadFixture(deployAndSetup);
      const zeroAddress = "0x0000000000000000000000000000000000000000";
      await expect(cloudax.connect(owner).transfer(zeroAddress, 100)).to.be
        .revertedWithCustomError;
    });

    it("Should revert when transferring more tokens than balance", async () => {
      const { cloudax, owner, john } = await loadFixture(deployAndSetup);
      const ownerBalance = await cloudax.balanceOf(owner.address);
      const newAmount = ethers.parseEther("100") + ownerBalance;
      await expect(cloudax.connect(owner).transfer(john.address, newAmount)).to
        .be.revertedWithCustomError;
    });

    it("Should revert when a non-owner attempts to blacklist an address", async () => {
      const { cloudax, john, jane } = await loadFixture(deployAndSetup);
      await expect(cloudax.connect(john).setBlacklisted(jane.address, true)).to
        .be.revertedWithCustomError;
    });
  });

  describe("More on Blacklisting", function () {
    it("Should prevent blacklisted addresses from sending tokens", async () => {
      const { cloudax, owner, john } = await loadFixture(deployAndSetup);
      // setup tresuary
      await cloudax.setupTresuaryAddress(cloudaxTresuary.getAddress());
      await cloudax.connect(owner).setBlacklisted(john.address, true);
      await expect(cloudax.connect(john).transfer(owner.address, 100)).to.be
        .revertedWithCustomError;
    });

    it("Should prevent blacklisted addresses from receiving tokens", async () => {
      const { cloudax, owner, john } = await loadFixture(deployAndSetup);
      await cloudax.connect(owner).setBlacklisted(john.address, true);
      await expect(
        cloudax.connect(owner).transferFrom(owner.address, john.address, 100)
      ).to.be.revertedWithCustomError;
    });
  });
  describe("More Trading Control", function () {
    it("Should prevent non-presale transfers when trading is disabled", async () => {
      const { cloudax, owner, john } = await loadFixture(deployAndSetup);
      // setup tresuary
      await cloudax.setupTresuaryAddress(cloudaxTresuary.getAddress());
      await expect(cloudax.connect(john).transfer(owner.address, 100)).to.be
        .revertedWithCustomError;
    });

    it("Should allow presale transfers when trading is disabled", async () => {
      const { cloudax, owner, john, jane } = await loadFixture(deployAndSetup);
      // setup tresuary
      await cloudax.setupTresuaryAddress(cloudaxTresuary.getAddress());
      await cloudax.connect(owner).setupPresaleAddress(john.address);
      // Transfer token
      await cloudax.connect(owner).transfer(john.address, 1000);
      await cloudax.connect(john).transfer(jane.address, 100);
      const balance = await cloudax.balanceOf(jane.address);
      expect(balance).to.equal(100);
    });

    it("Should allow only the presale address to transfer tokens during presale", async () => {
      const { cloudax, owner, john, jane } = await loadFixture(deployAndSetup);
      await cloudax.connect(owner).setupPresaleAddress(john.address);
      await expect(cloudax.connect(jane).transfer(owner.address, 100)).to.be
        .revertedWithCustomError;
    });
  });
});
