import {
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";
import { Cloudax } from "../typechain-types";
import { CloudaxTresauryVestingWallet } from "../typechain-types";

describe("Cloudax Tresuary", function () {
  let cloudax: Cloudax, owner, john, jane;
  let  cloudaxTresauryVestingWallet:CloudaxTresauryVestingWallet
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployAndSetup() {
    // Contracts are deployed using the first signer/account by default
    [owner, john, jane] = await ethers.getSigners();

  // Deploy cloudax
    const Cloudax = await ethers.getContractFactory("Cloudax");
    cloudax = await Cloudax.deploy(owner.address);

  // Deploy CloudaxTresauryVestingWallet
    const CloudaxTresauryVestingWallet = await ethers.getContractFactory("CloudaxTresauryVestingWallet");
    cloudaxTresauryVestingWallet = await CloudaxTresauryVestingWallet.deploy(cloudax.getAddress() ,owner.address);

    return { cloudax, cloudaxTresauryVestingWallet, owner, john, jane };
  }

  describe("getToken", function () {
    it("should return the address of the ERC20 token", async function () {
      const { cloudaxTresauryVestingWallet, cloudax } = await loadFixture(deployAndSetup);
      const tokenAddress = await cloudaxTresauryVestingWallet.getToken();
      expect(tokenAddress).to.not.be.null;
      expect(tokenAddress).to.not.be.undefined;
      expect(tokenAddress).to.equal(await cloudax.getAddress());
    });
  });

  describe("setBeneficiaryAddress", function () {
    it("should set the beneficiary address", async function () {
      const { cloudaxTresauryVestingWallet, owner, john } = await loadFixture(deployAndSetup);
      await cloudaxTresauryVestingWallet.connect(owner).setBeneficiaryAddress(john.address);
      expect(await cloudaxTresauryVestingWallet.getBeneficiaryAddress()).to.equal(john.address);
    });

    it("should revert if called by a non-owner", async function () {
      const { cloudaxTresauryVestingWallet, john, jane } = await loadFixture(deployAndSetup);
      await expect(cloudaxTresauryVestingWallet.connect(john).setBeneficiaryAddress(jane.address)).to.be.revertedWithCustomError;
    });
  });

  describe("initialize", function () {
    it("should initialize the vesting schedule", async function () {
      const { cloudaxTresauryVestingWallet, owner, john } = await loadFixture(deployAndSetup);
      // Assuming the token contract is already deployed and the address is known
      const vestingDuration =  12; //  12 months for example
      const vestingAllocation = ethers.parseEther("1000"); //  1000 tokens for example
      const cliffPeriod =  0; //  0 month cliff period for example

      await cloudaxTresauryVestingWallet.connect(owner).initialize(vestingDuration, john.address, vestingAllocation, cliffPeriod);
      const beneficiaryAddress = await cloudaxTresauryVestingWallet.getBeneficiaryAddress();
      expect(beneficiaryAddress).to.equal(john.address);

      // await cloudaxTresauryVestingWallet.release();
      const releasableAmount = await cloudaxTresauryVestingWallet.getReleasableAmount();
      expect(BigInt(releasableAmount)).to.be.equal(0);
      // Additional checks for the vesting schedule initialization can be added here
    });

    it("should revert if called by a non-owner", async function () {
      const { cloudaxTresauryVestingWallet, john } = await loadFixture(deployAndSetup);
      const vestingDuration =  12; //  12 months for example
      const vestingAllocation = ethers.parseEther("1000"); //  1000 tokens for example
      const cliffPeriod =  1; //  1 month cliff period for example

      await expect(cloudaxTresauryVestingWallet.connect(john).initialize(vestingDuration, john.address, vestingAllocation, cliffPeriod)).to.be.revertedWithCustomError;
    });
  });

  describe("Token Swap", function () {
    it("Should allow approved wallets to swap tokens", async function () {
      const { cloudaxTresauryVestingWallet, cloudax, owner, john, jane } = await loadFixture(deployAndSetup);
      // Approve an ECO wallet
      await cloudaxTresauryVestingWallet.connect(owner).aproveEcoWallet(owner.address);

      // send cldx to tresuary
      await cloudax.connect(owner).setTradingEnabled(true);
      await cloudax.connect(owner).sendTokens(cloudaxTresauryVestingWallet.getAddress(), 1000)

      // Swap CLDX to ECO
      const amountToTransfer = 100;
      await cloudaxTresauryVestingWallet.connect(owner).swapCldxToEco(amountToTransfer, john.address);
      const burntToken = amountToTransfer * 0.2
      const remainingAmountToTransfer = amountToTransfer - burntToken;
      const swappedForEco = await cloudaxTresauryVestingWallet._swappedForEco(john.address)
      expect(swappedForEco).to.equal(remainingAmountToTransfer);

      // Swap ECO to CLDX
      await cloudaxTresauryVestingWallet.swapEcoToCldx(100, jane.address);
      const swappedForCldx = await cloudaxTresauryVestingWallet._swappedForCldx(jane.address);
      expect(swappedForCldx).to.equal(100);
    });
  });

  describe("Remove Eco Wallet", function () {
    it("Should allow the owner to remove an Eco wallet", async function () {
      const { cloudaxTresauryVestingWallet, owner, john, jane } = await loadFixture(deployAndSetup);
      // Approve an ECO wallet
      await cloudaxTresauryVestingWallet.connect(owner).aproveEcoWallet(john.address);
  
      // Remove the ECO wallet
      await cloudaxTresauryVestingWallet.connect(owner).removeEcoWallet(john.address);
      const isApproved = await cloudaxTresauryVestingWallet.connect(owner).ecoApprovalWallet(john.address);
      expect(isApproved).to.equal(0);
    });
  });

  describe("Withdraw", function () {
    it("Should allow the owner to withdraw tokens when the contract is paused", async function () {
      const { cloudaxTresauryVestingWallet, owner, john, jane } = await loadFixture(deployAndSetup);

      // send cldx to tresuary
      await cloudax.connect(owner).setTradingEnabled(true);
      await cloudax.connect(owner).sendTokens(cloudaxTresauryVestingWallet.getAddress(), 1000)
      // Assuming the contract has tokens to withdraw
      const initialBalance = await cloudaxTresauryVestingWallet.connect(owner).getWithdrawableAmount();
      expect(Number(initialBalance)).to.be.not.equal(0);

    });
  });

  describe("Get Vesting Schedules Count", function () {
    it("Should return the number of vesting schedules managed by this contract", async function () {
      const { cloudaxTresauryVestingWallet, owner, john, jane } = await loadFixture(deployAndSetup);
      // initialize vesting
      const vestingDuration =  12; //  12 months for example
      const vestingAllocation = ethers.parseEther("1000"); //  1000 tokens for example
      const cliffPeriod =  1; //  1 month cliff period for example

      await cloudaxTresauryVestingWallet.connect(owner).initialize(vestingDuration, john.address, vestingAllocation, cliffPeriod);
      const vestingSchedulesCount = await cloudaxTresauryVestingWallet.getVestingSchedulesCount();
      expect(Number(vestingSchedulesCount)).to.be.not.equal(0);
    });
  });

  describe("Get Start Time", function () {
    it("Should return the release start timestamp", async function () {
      const startTime = await cloudaxTresauryVestingWallet.getStartTime();
      expect(startTime).to.be.gt(0);
    });
  });

  describe("Get Daily Releasable Amount", function () {
    it("Should return the daily releasable amount of tokens for the mining pool", async function () {
      const { cloudaxTresauryVestingWallet, owner, john, jane } = await loadFixture(deployAndSetup);
      // initialize vesting
      const vestingDuration =  12; //  12 months for example
      const vestingAllocation = ethers.parseEther("1000"); //  1000 tokens for example
      const cliffPeriod =  0; //  0 month cliff period for example

      await cloudaxTresauryVestingWallet.connect(owner).initialize(vestingDuration, john.address, vestingAllocation, cliffPeriod);
      const dailyReleasableAmount = await cloudaxTresauryVestingWallet.getDailyReleasableAmount(await cloudaxTresauryVestingWallet.getCurrentTime());
      expect(dailyReleasableAmount).to.be.gt(0);
    });
  });

  describe("Get Current Time", function () {
    it("Should return the current timestamp", async function () {
      const currentTime = await cloudaxTresauryVestingWallet.getCurrentTime();
      expect(currentTime).to.be.gt(0);
    });
  });

  describe("Get Cliff", function () {
    it("Should return the cliff period in months", async function () {
      const { cloudaxTresauryVestingWallet, owner, john, jane } = await loadFixture(deployAndSetup);
      // initialize vesting
      const vestingDuration =  12; //  12 months for example
      const vestingAllocation = ethers.parseEther("1000"); //  1000 tokens for example
      const cliffPeriod =  1; //  1 month cliff period for example
      await cloudaxTresauryVestingWallet.connect(owner).initialize(vestingDuration, john.address, vestingAllocation, cliffPeriod);
      const cliff = await cloudaxTresauryVestingWallet.getCliff();
      expect(cliff).to.be.gt(0);
    });
  });

  describe("Burn", function () {
    it("Should allow the owner to burn tokens", async function () {
      const { cloudaxTresauryVestingWallet, owner, john, jane } = await loadFixture(deployAndSetup);
      // send cldx to tresuary
      await cloudax.connect(owner).setTradingEnabled(true);
      const amount: any = 100;
      await cloudax.connect(owner).sendTokens(cloudaxTresauryVestingWallet.getAddress(), amount)
      // Assuming the contract has tokens to burn
      const initialBalance = await cloudaxTresauryVestingWallet.getWithdrawableAmount();
      expect(Number(initialBalance)).to.be.gt(0);
  
      // Burn tokens
      const burnAmount = amount - 50;
      await cloudaxTresauryVestingWallet.burn(burnAmount);
  
      // Check the new balance
      const newBalance = await cloudaxTresauryVestingWallet.getWithdrawableAmount();
      expect(newBalance).to.equal(Number(initialBalance) - burnAmount);
    });
  });

  describe("pause and unpause", function () {
    it("should pause the contract and prevent release", async function () {
      const { cloudaxTresauryVestingWallet, owner, john } = await deployAndSetup();
      // initialize vesting
      const vestingDuration =  12; //  12 months for example
      const vestingAllocation = ethers.parseEther("1000"); //  1000 tokens for example
      const cliffPeriod =  1; //  1 month cliff period for example
      await cloudaxTresauryVestingWallet.connect(owner).initialize(vestingDuration, john.address, vestingAllocation, cliffPeriod);
      await cloudaxTresauryVestingWallet.connect(owner).pause();
      expect(await cloudaxTresauryVestingWallet.paused()).to.be.true;
      await expect(cloudaxTresauryVestingWallet.connect(owner).release()).to.be.revertedWithCustomError
    });
    it("should unpause by only owner", async function () {
      const { cloudaxTresauryVestingWallet, owner, john } = await deployAndSetup();
      // initialize vesting
      const vestingDuration =  12; //  12 months for example
      const vestingAllocation = ethers.parseEther("1000"); //  1000 tokens for example
      const cliffPeriod =  1; //  1 month cliff period for example
      await cloudaxTresauryVestingWallet.connect(owner).initialize(vestingDuration, john.address, vestingAllocation, cliffPeriod);
      await cloudaxTresauryVestingWallet.connect(owner).pause();
      await cloudaxTresauryVestingWallet.connect(owner).unpause()
      expect(await cloudaxTresauryVestingWallet.paused()).to.be.false;
      await expect(cloudaxTresauryVestingWallet.connect(owner).release()).to.be.revertedWithCustomError
    });
  });

  describe("getReleaseInfo", function () {
    it("should return  greater than 0 for releasable, released, and total if vesting is available", async function () {
      const { cloudaxTresauryVestingWallet, owner, john } = await deployAndSetup();
      // initialize vesting
      const vestingDuration =  12; //  12 months for example
      const vestingAllocation = ethers.parseEther("1000"); //  1000 tokens for example
      const cliffPeriod =  0; //  0 month cliff period for example
      await cloudaxTresauryVestingWallet.connect(owner).initialize(vestingDuration, john.address, vestingAllocation, cliffPeriod);
      await cloudaxTresauryVestingWallet.connect(owner).pause();
      const [releasable, released, total] = await cloudaxTresauryVestingWallet.getReleaseInfo();
      expect(Number(releasable)).to.not.equal(0);
      expect(Number(released)).to.equal(0);
      expect(Number(total)).to.not.equal(0);
    });
  });

});
