// import {
//   loadFixture,
// } from "@nomicfoundation/hardhat-toolbox/network-helpers";
// import { expect } from "chai";
// import { ethers } from "hardhat";
// import { Cloudax } from "../typechain-types";
// import { CloudaxTeamVestingWallet } from "../typechain-types";

// describe("Cloudax Team", function () {
//   let cloudax: Cloudax, owner, john, jane;
//   let  cloudaxTeamVestingWallet:CloudaxTeamVestingWallet
//   // We define a fixture to reuse the same setup in every test.
//   // We use loadFixture to run this setup once, snapshot that state,
//   // and reset Hardhat Network to that snapshot in every test.
//   async function deployAndSetup() {
//     // Contracts are deployed using the first signer/account by default
//     [owner, john, jane] = await ethers.getSigners();

//   // Deploy cloudax
//     const Cloudax = await ethers.getContractFactory("Cloudax");
//     cloudax = await Cloudax.deploy();

//   // Deploy CloudaxTeamVestingWallet
//     const CloudaxTeamVestingWallet = await ethers.getContractFactory("CloudaxTeamVestingWallet");
//     cloudaxTeamVestingWallet = await CloudaxTeamVestingWallet.deploy(cloudax.getAddress(), 0);

//     return { cloudax, cloudaxTeamVestingWallet, owner, john, jane };
//   }

//   describe("getToken", function () {
//     it("should return the address of the ERC20 token", async function () {
//       const { cloudaxTeamVestingWallet, owner } = await deployAndSetup();
//       const tokenAddress = await cloudaxTeamVestingWallet.getToken();
//       expect(tokenAddress).to.not.be.null;
//       expect(tokenAddress).to.not.be.undefined;
//       expect(tokenAddress).to.equal(await cloudax.getAddress());
//     });
//   });

//   describe("setBeneficiaryAddress", function () {
//     it("should set the beneficiary address", async function () {
//       const { cloudaxTeamVestingWallet, owner, john } = await deployAndSetup();
//       await cloudaxTeamVestingWallet.connect(owner).setBeneficiaryAddress(john.address);
//       expect(await cloudaxTeamVestingWallet.getBeneficiaryAddress()).to.equal(john.address);
//     });

//     it("should revert if called by a non-owner", async function () {
//       const { cloudaxTeamVestingWallet, john, jane } = await deployAndSetup();
//       await expect(cloudaxTeamVestingWallet.connect(john).setBeneficiaryAddress(jane.address)).to.be.revertedWithCustomError;
//     });
//   });

//   describe("initialize", function () {
//     it("should initialize the vesting schedule", async function () {
//       const { cloudaxTeamVestingWallet, owner } = await deployAndSetup();
//       await cloudaxTeamVestingWallet.connect(owner).initialize(owner.address);
//       expect(await cloudaxTeamVestingWallet.getStartTime()).to.be.gt(0);
//       expect(await cloudaxTeamVestingWallet.getVestingSchedulesCount()).to.equal(48);
//     });
//   });

//   describe("withdraw", function () {
//     it("should allow the owner to withdraw tokens when paused", async function () {
//       const { cloudaxTeamVestingWallet, owner } = await deployAndSetup();
//       await cloudax.connect(owner).setTradingEnabled(true);
//       const withdrawableAmount = await cloudaxTeamVestingWallet.getWithdrawableAmount();
//       await cloudaxTeamVestingWallet.connect(owner).withdraw(withdrawableAmount);
//       expect(await cloudaxTeamVestingWallet.getWithdrawableAmount()).to.equal(0);
//     });
//     it("should revert if called by a non-owner", async function () {
//       const { cloudaxTeamVestingWallet, john } = await deployAndSetup();
//       await expect(cloudaxTeamVestingWallet.connect(john).withdraw(1)).to.be.revertedWithCustomError;
//     });
//   });


//   describe("getVestingSchedule", function () {
//     it("should return the vesting schedule for a given identifier", async function () {
//       const { cloudaxTeamVestingWallet, owner } = await deployAndSetup();
//       await cloudaxTeamVestingWallet.connect(owner).initialize(owner.address);
//       const vestingSchedule = await cloudaxTeamVestingWallet.getVestingSchedule(0);
//       expect(vestingSchedule.totalAmount).to.be.gt(0);
//       expect(vestingSchedule.startTime).to.be.gt(0);
//       expect(vestingSchedule.duration).to.equal(30 *  24 *  60 *  60); //  30 days in seconds
//     });
//   });

//   describe("getStartTime", function () {
//     it("should return the start time of the vesting schedule", async function () {
//       const { cloudaxTeamVestingWallet, owner } = await deployAndSetup();
//       await cloudaxTeamVestingWallet.connect(owner).initialize(owner.address);
//       const startTime = await cloudaxTeamVestingWallet.getStartTime();
//       expect(startTime).to.be.gt(0);
//     });
//   });

//   describe("getDailyReleasableAmount", function () {
//     it("should return the daily releasable amount of tokens", async function () {
//       const { cloudaxTeamVestingWallet, owner } = await deployAndSetup();
//       await cloudaxTeamVestingWallet.connect(owner).initialize(owner.address);
//       const dailyReleasableAmount = await cloudaxTeamVestingWallet.getDailyReleasableAmount('4478568980890');
//       console.log(`DailyReleasableAmount${dailyReleasableAmount}`)
//       expect(Number(dailyReleasableAmount)).to.be.equal(0);
//     });
//   });

//   describe("getCurrentTime", function () {
//     it("should return the current timestamp", async function () {
//       const { cloudaxTeamVestingWallet } = await deployAndSetup();
//       const currentTime = await cloudaxTeamVestingWallet.getCurrentTime();
//       expect(currentTime).to.be.gt(0);
//     });
//   });
//   describe("withdraw", function () {
//     it("should revert if the contract is not paused", async function () {
//       const { cloudaxTeamVestingWallet, owner } = await deployAndSetup();
//       await cloudaxTeamVestingWallet.connect(owner).initialize(owner.address);
//       await expect(cloudaxTeamVestingWallet.connect(owner).withdraw(1)).to.be.revertedWithCustomError;
//     });
//   });

//   describe("getToken", function () {
//     it("should return the address of the ERC20 token", async function () {
//       const { cloudaxTeamVestingWallet, cloudax } = await deployAndSetup();
//       const tokenAddress = await cloudaxTeamVestingWallet.getToken();
//       expect(tokenAddress).to.not.be.null;
//       expect(tokenAddress).to.not.be.undefined;
//       expect(tokenAddress).to.equal(await cloudax.getAddress());
//     });
//   });

//   describe("pause and unpause", function () {
//     it("should pause the contract and prevent release", async function () {
//       const { cloudaxTeamVestingWallet, owner } = await deployAndSetup();
//       await cloudaxTeamVestingWallet.connect(owner).initialize(owner.address);
//       await cloudaxTeamVestingWallet.connect(owner).pause();
//       expect(await cloudaxTeamVestingWallet.paused()).to.be.true;
//       await expect(cloudaxTeamVestingWallet.connect(owner).release()).to.be.revertedWithCustomError
//     });
//     it("should unpause by only owner", async function () {
//       const { cloudaxTeamVestingWallet, owner, john } = await deployAndSetup();
//       await cloudaxTeamVestingWallet.connect(owner).initialize(owner.address);
//       await cloudaxTeamVestingWallet.connect(owner).pause();
//       await cloudaxTeamVestingWallet.connect(owner).unpause()
//       expect(await cloudaxTeamVestingWallet.paused()).to.be.false;
//       await expect(cloudaxTeamVestingWallet.connect(owner).release()).to.be.revertedWithCustomError
//     });
//   });

//   describe("getReleasableAmount", function () {

//     it("should return the releasable amount after initialization", async function () {
//       const { cloudaxTeamVestingWallet, owner } = await deployAndSetup();
//       await cloudaxTeamVestingWallet.connect(owner).initialize(owner.address);
//       const releasableAmount = await cloudaxTeamVestingWallet.getReleasableAmount();
//       expect(releasableAmount).to.be.gt(0);
//     });
//   });

//   describe("getReleaseInfo", function () {
//     it("should return  greater than 0 for releasable, released, and total if vesting is available", async function () {
//       const { cloudaxTeamVestingWallet, owner } = await deployAndSetup();
//       await cloudaxTeamVestingWallet.connect(owner).initialize(owner.address);
//       const [releasable, released, total] = await cloudaxTeamVestingWallet.getReleaseInfo();
//       expect(Number(releasable)).to.not.equal(0);
//       expect(Number(released)).to.equal(0);
//       expect(Number(total)).to.not.equal(0);
//     });

//     it("should return the release info after initialization", async function () {
//       const { cloudaxTeamVestingWallet, owner } = await deployAndSetup();
//       await cloudaxTeamVestingWallet.connect(owner).initialize(owner.address);
//       const [releasable, released, total] = await cloudaxTeamVestingWallet.getReleaseInfo();
//       expect(releasable).to.be.gt(0);
//       expect(released).to.equal(0);
//       expect(total).to.be.gt(0);
//     });
//   });
// });
