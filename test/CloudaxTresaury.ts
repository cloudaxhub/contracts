import { expect } from "chai";
import { ethers } from "hardhat";
import { CloudaxTresuary } from "../typechain-types";

describe("Cloudax Tresuary", function () {
  let cloudaxTresuary: CloudaxTresuary;
  let owner, john, jane;

  beforeEach(async function () {
    [owner, john, jane] = await ethers.getSigners();

    const CloudaxTresuary = await ethers.getContractFactory("CloudaxTresuary");
    cloudaxTresuary = await CloudaxTresuary.deploy();
  });

  describe("setOracleAddress", function () {
    it("should set the oracle address", async function () {
      await cloudaxTresuary.connect(owner).setOracleAddress(john.address);
      const oracleAddress = await cloudaxTresuary.oracle();
      expect(oracleAddress).to.equal(john.address);
    });

    it("should revert if called by a non-owner", async function () {
      await expect(
        cloudaxTresuary.connect(john).setOracleAddress(jane.address)
      ).to.be.revertedWithCustomError(cloudaxTresuary, "UnauthorizedAddress");
    });
  });

  describe("initiateSwap", function () {
    it("should initiate a token swap operation for an approved wallet", async function () {
      await cloudaxTresuary.connect(owner).aproveEcoWallet(john.address);
      const amount = ethers.utils.parseEther("100");
      await cloudaxTresuary.connect(john).initiateSwap(amount, jane.address);
      const swapOperation = await cloudaxTresuary.getSwapOperation(jane.address);
      expect(swapOperation.status).to.equal(0);
      expect(swapOperation.amount).to.equal(amount);
    });

    it("should revert if the sender is not an approved wallet", async function () {
      await expect(
        cloudaxTresuary.connect(john).initiateSwap(ethers.utils.parseEther("100"), jane.address)
      ).to.be.revertedWithCustomError(cloudaxTresuary, "NotAnApprovedEcoWallet");
    });
  });

  describe("swapCldxToEco", function () {
    it("should swap CLDX tokens for ECO tokens for approved wallets", async function () {
      await cloudaxTresuary.connect(owner).aproveEcoWallet(john.address);
      const amount = ethers.utils.parseEther("100");
      await cloudaxTresuary.connect(john).initiateSwap(amount, jane.address);
      await cloudaxTresuary.connect(john).swapCldxToEco(amount, jane.address);
      const swappedForEco = await cloudaxTresuary._swappedForEco(jane.address);
      expect(swappedForEco).to.equal(amount);
    });

    it("should revert if the sender is not an approved wallet", async function () {
      await expect(
        cloudaxTresuary.connect(john).swapCldxToEco(ethers.utils.parseEther("100"), jane.address)
      ).to.be.revertedWithCustomError(cloudaxTresuary, "NotAnApprovedEcoWallet");
    });
  });

  describe("swapEcoToCldx", function () {
    it("should swap ECO tokens for CLDX tokens for approved wallets", async function () {
      await cloudaxTresuary.connect(owner).aproveEcoWallet(john.address);
      const amount = ethers.utils.parseEther("100");
      await cloudaxTresuary.connect(john).swapEcoToCldx(amount, jane.address);
      const swappedForCldx = await cloudaxTresuary._swappedForCldx(jane.address);
      expect(swappedForCldx).to.equal(amount);
    });

    it("should revert if the sender is not an approved wallet", async function () {
      await expect(
        cloudaxTresuary.connect(john).swapEcoToCldx(ethers.utils.parseEther("100"), jane.address)
      ).to.be.revertedWithCustomError(cloudaxTresuary, "NotAnApprovedEcoWallet");
    });
  });

  describe("aproveEcoWallet", function () {
    it("should approve an ECO wallet to perform token swaps", async function () {
      await cloudaxTresuary.connect(owner).aproveEcoWallet(john.address);
      const isApproved = await cloudaxTresuary.ecoApprovalWallet(john.address);
      expect(isApproved).to.be.true;
    });

    it("should revert if the wallet is already approved", async function () {
      await cloudaxTresuary.connect(owner).aproveEcoWallet(john.address);
      await expect(
        cloudaxTresuary.connect(owner).aproveEcoWallet(john.address)
      ).to.be.revertedWithCustomError(cloudaxTresuary, "AlreadyApproved");
    });
  });

  describe("removeEcoWallet", function () {
    it("should remove approval for an ECO wallet to perform token swaps", async function () {
      await cloudaxTresuary.connect(owner).aproveEcoWallet(john.address);
      await cloudaxTresuary.connect(owner).removeEcoWallet(john.address);
      const isApproved = await cloudaxTresuary.ecoApprovalWallet(john.address);
      expect(isApproved).to.be.false;
    });

    it("should revert if the wallet is not approved", async function () {
      await expect(
        cloudaxTresuary.connect(owner).removeEcoWallet(john.address)
      ).to.be.revertedWithCustomError(cloudaxTresuary, "NotAnApprovedEcoWallet");
    });
  });

  describe("burn", function () {
    it("should burn a specified amount of tokens", async function () {
      const amount = ethers.utils.parseEther("100");
      await cloudaxTresuary.connect(owner).burn(amount);
      const totalBurnt = await cloudaxTresuary._totalBurnt();
      expect(totalBurnt).to.equal(amount);
    });

    it("should revert if the sender is not the owner", async function () {
      await expect(
        cloudaxTresuary.connect(john).burn(ethers.utils.parseEther("100"))
      ).to.be.revertedWithCustomError(cloudaxTresuary, "UnauthorizedAddress");
    });
  });
});

