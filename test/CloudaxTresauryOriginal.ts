// import {
//   loadFixture,
// } from "@nomicfoundation/hardhat-toolbox/network-helpers";
// import { expect } from "chai";
// import { ethers } from "hardhat";
// import { Cloudax } from "../typechain-types";
// import { CloudaxTresuary } from "../typechain-types";

// describe("Cloudax Tresuary", function () {
//   let cloudax: Cloudax, owner, john, jane;
//   let  cloudaxTresuary:CloudaxTresuary
//   // We define a fixture to reuse the same setup in every test.
//   // We use loadFixture to run this setup once, snapshot that state,
//   // and reset Hardhat Network to that snapshot in every test.
//   async function deployAndSetup() {
//     // Contracts are deployed using the first signer/account by default
//     [owner, john, jane] = await ethers.getSigners();

//   // Deploy cloudax
//     const Cloudax = await ethers.getContractFactory("Cloudax");
//     cloudax = await Cloudax.deploy();

//   // Deploy CloudaxTresuary
//     const CloudaxTresuary = await ethers.getContractFactory("CloudaxTresuary");
//     cloudaxTresuary = await CloudaxTresuary.deploy(cloudax.getAddress());

//     return { cloudax, cloudaxTresuary, owner, john, jane };
//   }

//   describe("getToken", function () {
//     it("should return the address of the ERC20 token", async function () {
//       const { cloudaxTresuary, cloudax } = await loadFixture(deployAndSetup);
//       const tokenAddress = await cloudaxTresuary.getToken();
//       expect(tokenAddress).to.not.be.null;
//       expect(tokenAddress).to.not.be.undefined;
//       expect(tokenAddress).to.equal(await cloudax.getAddress());
//     });
//   });

//   describe("setBeneficiaryAddress", function () {
//     it("should set the beneficiary address", async function () {
//       const { cloudaxTresuary, owner, john } = await loadFixture(deployAndSetup);
//       await cloudaxTresuary.connect(owner).setBeneficiaryAddress(john.address);
//       expect(await cloudaxTresuary.getBeneficiaryAddress()).to.equal(john.address);
//     });

//     it("should revert if called by a non-owner", async function () {
//       const { cloudaxTresuary, john, jane } = await loadFixture(deployAndSetup);
//       await expect(cloudaxTresuary.connect(john).setBeneficiaryAddress(jane.address)).to.be.revertedWithCustomError;
//     });
//   });

//   describe("initialize", function () {
//     it("should initialize the vesting schedule", async function () {
//       const { cloudaxTresuary, owner, john } = await loadFixture(deployAndSetup);
//       // Assuming the token contract is already deployed and the address is known
//       const vestingDuration =  12; //  12 months for example
//       const vestingAllocation = ethers.parseEther("1000"); //  1000 tokens for example
//       const cliffPeriod =  0; //  0 month cliff period for example

//       await cloudaxTresuary.connect(owner).initialize(vestingDuration, john.address, vestingAllocation, cliffPeriod);
//       const beneficiaryAddress = await cloudaxTresuary.getBeneficiaryAddress();
//       expect(beneficiaryAddress).to.equal(john.address);

//       // await cloudaxTresuary.release();
//       const releasableAmount = await cloudaxTresuary.getReleasableAmount();
//       expect(BigInt(releasableAmount)).to.be.equal(0);
//       // Additional checks for the vesting schedule initialization can be added here
//     });

//     it("should revert if called by a non-owner", async function () {
//       const { cloudaxTresuary, john } = await loadFixture(deployAndSetup);
//       const vestingDuration =  12; //  12 months for example
//       const vestingAllocation = ethers.parseEther("1000"); //  1000 tokens for example
//       const cliffPeriod =  1; //  1 month cliff period for example

//       await expect(cloudaxTresuary.connect(john).initialize(vestingDuration, john.address, vestingAllocation, cliffPeriod)).to.be.revertedWithCustomError;
//     });
//   });

//   describe("Token Swap", function () {
//     it("Should allow approved wallets to swap tokens", async function () {
//       const { cloudaxTresuary, cloudax, owner, john, jane } = await loadFixture(deployAndSetup);
//       // Approve an ECO wallet
//       await cloudaxTresuary.connect(owner).aproveEcoWallet(owner.address);

//       // send cldx to tresuary
//       await cloudax.connect(owner).setTradingEnabled(true);
//       await cloudax.connect(owner).sendTokens(cloudaxTresuary.getAddress(), 1000)

//       // Swap CLDX to ECO
//       const amountToTransfer = 100;
//       await cloudaxTresuary.connect(owner).swapCldxToEco(amountToTransfer, john.address);
//       const burntToken = amountToTransfer * 0.2
//       const remainingAmountToTransfer = amountToTransfer - burntToken;
//       const swappedForEco = await cloudaxTresuary._swappedForEco(john.address)
//       expect(swappedForEco).to.equal(remainingAmountToTransfer);

//       // Swap ECO to CLDX
//       await cloudaxTresuary.swapEcoToCldx(100, jane.address);
//       const swappedForCldx = await cloudaxTresuary._swappedForCldx(jane.address);
//       expect(swappedForCldx).to.equal(100);
//     });
//   });

//   describe("Remove Eco Wallet", function () {
//     it("Should allow the owner to remove an Eco wallet", async function () {
//       const { cloudaxTresuary, owner, john } = await loadFixture(deployAndSetup);
//       // Approve an ECO wallet
//       await cloudaxTresuary.connect(owner).aproveEcoWallet(john.address);
//       await cloudaxTresuary.connect(owner).aproveEcoWallet(owner.address);
  
//       // Remove the ECO wallet
//       await cloudaxTresuary.connect(owner).removeEcoWallet(john.address);
//       const isApproved = await cloudaxTresuary.connect(owner).ecoApprovalWallet(john.address);
//       console.log("isApproved",isApproved)
//       expect(isApproved).to.revertedWithCustomError;
//     });
//   });

//   describe("Withdraw", function () {
//     it("Should allow the owner to withdraw tokens when the contract is paused", async function () {
//       const { cloudaxTresuary, owner, john, jane } = await loadFixture(deployAndSetup);

//       // send cldx to tresuary
//       await cloudax.connect(owner).setTradingEnabled(true);
//       await cloudax.connect(owner).sendTokens(cloudaxTresuary.getAddress(), 1000)
//       // Assuming the contract has tokens to withdraw
//       const initialBalance = await cloudaxTresuary.connect(owner).getWithdrawableAmount();
//       expect(Number(initialBalance)).to.be.not.equal(0);

//     });
//   });

//   describe("Get Vesting Schedules Count", function () {
//     it("Should return the number of vesting schedules managed by this contract", async function () {
//       const { cloudaxTresuary, owner, john, jane } = await loadFixture(deployAndSetup);
//       // initialize vesting
//       const vestingDuration =  12; //  12 months for example
//       const vestingAllocation = ethers.parseEther("1000"); //  1000 tokens for example
//       const cliffPeriod =  1; //  1 month cliff period for example

//       await cloudaxTresuary.connect(owner).initialize(vestingDuration, john.address, vestingAllocation, cliffPeriod);
//       const vestingSchedulesCount = await cloudaxTresuary.getVestingSchedulesCount();
//       expect(Number(vestingSchedulesCount)).to.be.not.equal(0);
//     });
//   });

//   describe("Get Start Time", function () {
//     it("Should return the release start timestamp", async function () {
//       const startTime = await cloudaxTresuary.getStartTime();
//       expect(startTime).to.be.gt(0);
//     });
//   });

//   // describe("Get Daily Releasable Amount", function () {
//   //   it("Should return the daily releasable amount of tokens for the mining pool", async function () {
//   //     const { cloudaxTresuary, owner, john, jane } = await loadFixture(deployAndSetup);
//   //     // initialize vesting
//   //     const vestingDuration =  12; //  12 months for example
//   //     const vestingAllocation = ethers.parseEther("1000"); //  1000 tokens for example
//   //     const cliffPeriod =  0; //  0 month cliff period for example
//   //     // function getDateFromTimestamp(timestamp) {
//   //     //     // Convert the timestamp from seconds to milliseconds
//   //     //     const milliseconds = timestamp * 1000;
//   //     //     // Create a new Date object using the milliseconds
//   //     //     const date = new Date(milliseconds);
//   //     //     return date;
//   //     // }
//   //     // const solidityTimestamp = 1647555200; // Example Solidity timestamp
//   //     // const date = getDateFromTimestamp(solidityTimestamp);
//   //     const date = new Date(); // Example Date object
//   //     const timestamp = date.getTime(); // Convert to milliseconds since Unix epoch

//   //     await cloudaxTresuary.connect(owner).initialize(vestingDuration, john.address, vestingAllocation, cliffPeriod);
//   //     const dailyReleasableAmount = await cloudaxTresuary.getDailyReleasableAmount(Math.floor(timestamp / 100));
//   //     console.log(`Daily releasable amount:${Number(dailyReleasableAmount)}`)
//   //     console.log(`Daily releasable amount Original:${dailyReleasableAmount}`)
//   //     expect(Number(dailyReleasableAmount)).to.be.gt(0);
//   //   });
//   // });

//   // describe("Get Current Time", function () {
//   //   it("Should return the current timestamp", async function () {
//   //     const currentTime = await cloudaxTresuary.getCurrentTime();
//   //     expect(currentTime).to.be.gt(0);
//   //   });
//   // });

//   describe("Get Cliff", function () {
//     it("Should return the cliff period in months", async function () {
//       const { cloudaxTresuary, owner, john, jane } = await loadFixture(deployAndSetup);
//       // initialize vesting
//       const vestingDuration =  12; //  12 months for example
//       const vestingAllocation = ethers.parseEther("1000"); //  1000 tokens for example
//       const cliffPeriod =  1; //  1 month cliff period for example
//       await cloudaxTresuary.connect(owner).initialize(vestingDuration, john.address, vestingAllocation, cliffPeriod);
//       const cliff = await cloudaxTresuary.getCliff();
//       expect(cliff).to.be.gt(0);
//     });
//   });

//   describe("Burn", function () {
//     it("Should allow the owner to burn tokens", async function () {
//       const { cloudaxTresuary, owner, john, jane } = await loadFixture(deployAndSetup);
//       // send cldx to tresuary
//       await cloudax.connect(owner).setTradingEnabled(true);
//       const amount: any = 100;
//       await cloudax.connect(owner).sendTokens(cloudaxTresuary.getAddress(), amount)
//       // Assuming the contract has tokens to burn
//       const initialBalance = await cloudaxTresuary.getWithdrawableAmount();
//       expect(Number(initialBalance)).to.be.gt(0);
  
//       // Burn tokens
//       const burnAmount = amount - 50;
//       await cloudaxTresuary.burn(burnAmount);
  
//       // Check the new balance
//       const newBalance = await cloudaxTresuary.getWithdrawableAmount();
//       expect(newBalance).to.equal(Number(initialBalance) - burnAmount);
//     });
//   });

//   describe("pause and unpause", function () {
//     it("should pause the contract and prevent release", async function () {
//       const { cloudaxTresuary, owner, john } = await deployAndSetup();
//       // initialize vesting
//       const vestingDuration =  12; //  12 months for example
//       const vestingAllocation = ethers.parseEther("1000"); //  1000 tokens for example
//       const cliffPeriod =  1; //  1 month cliff period for example
//       await cloudaxTresuary.connect(owner).initialize(vestingDuration, john.address, vestingAllocation, cliffPeriod);
//       await cloudaxTresuary.connect(owner).pause();
//       expect(await cloudaxTresuary.paused()).to.be.true;
//       await expect(cloudaxTresuary.connect(owner).release()).to.be.revertedWithCustomError
//     });
//     it("should unpause by only owner", async function () {
//       const { cloudaxTresuary, owner, john } = await deployAndSetup();
//       // initialize vesting
//       const vestingDuration =  12; //  12 months for example
//       const vestingAllocation = ethers.parseEther("1000"); //  1000 tokens for example
//       const cliffPeriod =  1; //  1 month cliff period for example
//       await cloudaxTresuary.connect(owner).initialize(vestingDuration, john.address, vestingAllocation, cliffPeriod);
//       await cloudaxTresuary.connect(owner).pause();
//       await cloudaxTresuary.connect(owner).unpause()
//       expect(await cloudaxTresuary.paused()).to.be.false;
//       await expect(cloudaxTresuary.connect(owner).release()).to.be.revertedWithCustomError
//     });
//   });

//   describe("getReleaseInfo", function () {
//     it("should return  greater than 0 for releasable, released, and total if vesting is available", async function () {
//       const { cloudaxTresuary, owner, john } = await deployAndSetup();
//       // initialize vesting
//       const vestingDuration =  12; //  12 months for example
//       const vestingAllocation = ethers.parseEther("1000"); //  1000 tokens for example
//       const cliffPeriod =  0; //  0 month cliff period for example
//       await cloudaxTresuary.connect(owner).initialize(vestingDuration, john.address, vestingAllocation, cliffPeriod);
//       await cloudaxTresuary.connect(owner).pause();
//       const [releasable, released, total] = await cloudaxTresuary.getReleaseInfo();
//       expect(Number(releasable)).to.not.equal(0);
//       expect(Number(released)).to.equal(0);
//       expect(Number(total)).to.not.equal(0);
//     });
//   });

// });
