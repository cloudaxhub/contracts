import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";
import { Cloudax } from "../typechain-types";
import { CloudaxTresuary } from "../typechain-types";

describe("Cloudax Tresuary", function () {
  let cloudax: Cloudax, owner, john, jane;
  let cloudaxTresuary: CloudaxTresuary;
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployAndSetup() {
    // Contracts are deployed using the first signer/account by default
    [owner, john, jane] = await ethers.getSigners();

    // Deploy cloudax
    const Cloudax = await ethers.getContractFactory("Cloudax");
    cloudax = await Cloudax.deploy();

    // Deploy CloudaxTresuary
    const CloudaxTresuary = await ethers.getContractFactory("CloudaxTresuary");
    cloudaxTresuary = await CloudaxTresuary.deploy(cloudax.getAddress());

    return { cloudax, cloudaxTresuary, owner, john, jane };
  }

  describe("setOracleAddress", function () {
    it("should set the oracle address", async function () {
      const { cloudaxTresuary, john, owner } = await loadFixture(
        deployAndSetup
      );
      await cloudaxTresuary.connect(owner).setOracleAddress(john.address);
      const oracleAddress = await cloudaxTresuary.oracle();
      expect(oracleAddress).to.equal(john.address);
    });

    it("should revert if called by a non-owner", async function () {
      const { cloudaxTresuary, john, jane } = await loadFixture(deployAndSetup);
      await expect(cloudaxTresuary.connect(john).setOracleAddress(jane.address))
        .to.be.revertedWithCustomError;
    });
  });

  describe("swapCldxToEco", function () {
    it("should swap CLDX to ECO", async function () {
      const { cloudaxTresuary, owner, john, jane } = await loadFixture(
        deployAndSetup
      );
      const amount = ethers.parseEther("100");
      await cloudaxTresuary.connect(owner).setOracleAddress(john.address);
      await cloudaxTresuary.connect(owner).aproveEcoWallet(john.address);
      // send cldx to tresuary
      await cloudax.connect(owner).setTradingEnabled(true);
      // transfer cldx to user
      await cloudax.connect(owner).transfer(john.address, amount);

      await cloudax
        .connect(john)
        .transfer(cloudaxTresuary.getAddress(), amount);

      // Perform the swap
      await expect(
        cloudaxTresuary.connect(john).swapCldxToEco(amount, jane.address)
      )
        .to.emit(cloudaxTresuary, "TokenSwap")
        .withArgs(
          jane.address,
          cloudaxTresuary.getAddress(),
          john.address,
          amount,
          "CldxToEco"
        );
    });
  });
  describe("Burn Token", function () {
    it("Should burn tokens", async function () {
      const { cloudaxTresuary, owner, cloudax } = await loadFixture(
        deployAndSetup
      );
      const zeroAddress = "0x000000000000000000000000000000000000dEaD";

      const amount = ethers.parseEther("100");
      // send cldx to tresuary
      await cloudax.connect(owner).setTradingEnabled(true);
      // Simulate a token transfer to the contract
      await cloudax
        .connect(owner)
        .transfer(cloudaxTresuary.getAddress(), amount);

      // Burn tokens
      await expect(cloudaxTresuary.connect(owner).burn(amount))
        .to.emit(cloudaxTresuary, "TokenBurnt")
        .withArgs(owner.address, owner.address, zeroAddress, amount);
    });
  });
  describe("Add and remove ECO Wallet", function () {
    it("Should approve an ECO wallet", async function () {
      const { cloudaxTresuary, owner, jane } = await loadFixture(
        deployAndSetup
      );
      await expect(cloudaxTresuary.connect(owner).aproveEcoWallet(jane.address))
        .to.emit(cloudaxTresuary, "EcoWalletAdded")
        .withArgs(jane.address, owner.address);
      expect(await cloudaxTresuary.ecoApprovalWallet(jane.address)).to.be.true;
    });

    it("Should remove an ECO wallet", async function () {
      const { cloudaxTresuary, owner, jane } = await loadFixture(
        deployAndSetup
      );
      await cloudaxTresuary.connect(owner).aproveEcoWallet(jane.address);
      await expect(cloudaxTresuary.connect(owner).removeEcoWallet(jane.address))
        .to.emit(cloudaxTresuary, "EcoWalletRemoved")
        .withArgs(jane.address, owner.address);
      expect(await cloudaxTresuary.ecoApprovalWallet(jane.address)).to.be.false;
    });
  });
  describe("burn percentage", function () {
    it("Should set the burn percentage", async function () {
      const { cloudaxTresuary, owner } = await loadFixture(deployAndSetup);
      await cloudaxTresuary.connect(owner).setBurnPercentage(5);
      expect(await cloudaxTresuary.burnPercentage()).to.equal(5);
    });
    it("burn percentage max must be 5", async function () {
      const { cloudaxTresuary, owner } = await loadFixture(deployAndSetup);
      await expect(cloudaxTresuary.connect(owner).setBurnPercentage(6)).to.be
        .revertedWithCustomError;
    });
    it("burn percentage min must be 0", async function () {
      const { cloudaxTresuary, owner } = await loadFixture(deployAndSetup);
      await expect(cloudaxTresuary.connect(owner).setBurnPercentage(0.1)).to.be
        .revertedWithCustomError;
    });
    it("Should get the token address", async function () {
      const { cloudaxTresuary, cloudax } = await loadFixture(deployAndSetup);
      expect(await cloudaxTresuary.getToken()).to.equal(
        await cloudax.getAddress()
      );
    });
  });

  describe("swapEcoToCldx", function () {
    it("Should swap ECO to CLDX", async function () {
      const { cloudaxTresuary, cloudax, owner, john, jane } = await loadFixture(
        deployAndSetup
      );
      // Approve the wallet
      await cloudaxTresuary.connect(owner).aproveEcoWallet(john.address);
      await cloudaxTresuary.connect(owner).setOracleAddress(john.address);

      await cloudax.connect(owner).setTradingEnabled(true);
      const amount = ethers.parseEther("100");
      await cloudax.connect(owner).transfer(john.address, amount);
      // Simulate a token transfer to the contract
      await cloudax
        .connect(john)
        .transfer(cloudaxTresuary.getAddress(), amount);

      // Perform the swap
      await expect(
        cloudaxTresuary.connect(john).swapEcoToCldx(amount, jane.address)
      )
        .to.emit(cloudaxTresuary, "TokenSwap")
        .withArgs(
          cloudaxTresuary.getAddress(),
          jane.address,
          john.address,
          amount,
          "EcoToCldx"
        );
    });

    it("Should swap ECO to CLDX and recipent balance should increase", async function () {
      const { cloudaxTresuary, cloudax, owner, john, jane } = await loadFixture(
        deployAndSetup
      );
      // Approve the wallet
      await cloudaxTresuary.connect(owner).aproveEcoWallet(john.address);
      await cloudaxTresuary.connect(owner).setOracleAddress(john.address);

      await cloudax.connect(owner).setTradingEnabled(true);
      const amount = ethers.parseEther("100");
      await cloudax.connect(owner).transfer(john.address, amount);
      // Simulate a token transfer to the contract
      await cloudax
        .connect(john)
        .transfer(cloudaxTresuary.getAddress(), amount);

      const recipentBalanceBefore = await cloudax.balanceOf(jane.address);
      await cloudaxTresuary.connect(john).swapEcoToCldx(amount, jane.address);
      const recipentBalanceAfter = await cloudax.balanceOf(jane.address);

      // Perform the swap
      await expect(recipentBalanceAfter).to.equal(amount);
    });
  });
});
