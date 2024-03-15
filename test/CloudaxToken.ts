import {
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";
import { Cloudax } from "../typechain-types";

describe("Cloudax Token", function () {
  let cloudax: Cloudax, owner, john, jane;
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployAndSetup() {
    // Contracts are deployed using the first signer/account by default
    [owner, john, jane] = await ethers.getSigners();

    const Cloudax = await ethers.getContractFactory("Cloudax");
    cloudax = await Cloudax.deploy();

    return { cloudax, owner, john, jane };
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

      // Transfer tokens from owner to user1
      await cloudax.connect(owner).sendTokens(john.address, transferAmount);

      const finalBalanceOwner = await cloudax.balanceOf(owner.address);
      const finalBalanceUser1 = await cloudax.balanceOf(john.address);

      expect(finalBalanceOwner).to.equal(initialBalanceOwner - transferAmount);
      expect(finalBalanceUser1).to.equal(transferAmount);
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
      // token transfer
      await cloudax.connect(owner).sendTokens(john.address, 100);

      // Attempt a token transfer when trading is disabled
      await expect(
        cloudax.connect(john).sendTokens(jane.address, 10)
      ).to.be.revertedWithCustomError;

      // Enable trading
      await cloudax.connect(owner).setTradingEnabled(true);

      // Attempt a token transfer when trading is enabled
      await cloudax.connect(john).sendTokens(jane.address, 10);
      const balanceJane = await cloudax.balanceOf(jane.address);
      expect(balanceJane).to.equal(10);
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

      // Transfer tokens from owner to john
      await cloudax.connect(owner).sendTokens(john.address, transferAmount);

      const finalBalanceJohn = await cloudax.balanceOf(john.address);
      expect(finalBalanceJohn).to.equal(initialBalanceJohn + transferAmount); // Use add method for BigNumber arithmetic
    });
  });

  describe("Withdrawal Functions", function () {

    it("Should allow the owner to withdraw ERC-20 tokens", async () => {
      const { cloudax, owner, john } = await loadFixture(deployAndSetup);
      // Enable trading
      await cloudax.connect(owner).setTradingEnabled(true);

      const initialBalanceOwner = await cloudax.balanceOf(john.address);

      const transferAmount = await ethers.parseEther("500");

      // Transfer token
      await cloudax.connect(owner).sendTokens(john.address, transferAmount);

      // Withdraw Cloudax tokens to owner
      await cloudax
        .connect(owner)
        .withdrawTokens(cloudax.getAddress(), john.address, transferAmount);

      const finalBalanceOwner = await cloudax.balanceOf(john.address);
      expect(finalBalanceOwner).to.equal(initialBalanceOwner + transferAmount);
    });
  });

  describe("More on Blacklisting", function () {
    it("Should prevent blacklisted addresses from sending tokens", async () => {
      const { cloudax, owner, john } = await loadFixture(deployAndSetup);
      await cloudax.connect(owner).setBlacklisted(john.address, true);
      await expect(
        cloudax.connect(john).sendTokens(owner.address, 100)
      ).to.be.revertedWithCustomError;
    });

    it("Should prevent blacklisted addresses from receiving tokens", async () => {
      const { cloudax, owner, john } = await loadFixture(deployAndSetup);
      await cloudax.connect(owner).setBlacklisted(john.address, true);
      await expect(
        cloudax.connect(owner).receiveTokens(john.address, 100)
      ).to.be.revertedWithCustomError;
    });
  });
  describe("More Trading Control", function () {
    it("Should prevent non-presale transfers when trading is disabled", async () => {
      const { cloudax, owner, john } = await loadFixture(deployAndSetup);
      await expect(
        cloudax.connect(john).sendTokens(owner.address, 100)
      ).to.be.revertedWithCustomError;
    });

    it("Should allow presale transfers when trading is disabled", async () => {
      const { cloudax, owner, john, jane } = await loadFixture(deployAndSetup);
      await cloudax.connect(owner).setupPresaleAddress(john.address);
      // Transfer token
      await cloudax.connect(owner).sendTokens(john.address, 1000);
      await cloudax.connect(john).sendTokens(jane.address, 100);
      const balance = await cloudax.balanceOf(jane.address);
      expect(balance).to.equal(100);
    });
  });

});
