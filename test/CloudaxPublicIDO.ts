// import {
//   loadFixture,
// } from "@nomicfoundation/hardhat-toolbox/network-helpers";
// import { expect } from "chai";
// import { ethers } from "hardhat";
// import { Cloudax } from "../typechain-types";
// import { CloudaxPublicIDOVestingWallet } from "../typechain-types";

// describe("Cloudax Team", function () {
//   let cloudax: Cloudax, owner, john, jane;
//   let  cloudaxPublicIDOVestingWallet:CloudaxPublicIDOVestingWallet
//   // We define a fixture to reuse the same setup in every test.
//   // We use loadFixture to run this setup once, snapshot that state,
//   // and reset Hardhat Network to that snapshot in every test.
//   async function deployAndSetup() {
//     // Contracts are deployed using the first signer/account by default
//     [owner, john, jane] = await ethers.getSigners();

//   // Deploy cloudax
//     const Cloudax = await ethers.getContractFactory("Cloudax");
//     cloudax = await Cloudax.deploy();

//   // Deploy CloudaxPublicIDOVestingWallet
//     const CloudaxPublicIDOVestingWallet = await ethers.getContractFactory("CloudaxPublicIDOVestingWallet");
//     cloudaxPublicIDOVestingWallet = await CloudaxPublicIDOVestingWallet.deploy(cloudax.getAddress());

//     return { cloudax, cloudaxPublicIDOVestingWallet, owner, john, jane };
//   }

//   describe("getToken", function () {
//     it("should return the address of the ERC20 token", async function () {
//       const { cloudaxPublicIDOVestingWallet, owner } = await deployAndSetup();
//       const tokenAddress = await cloudaxPublicIDOVestingWallet.getToken();
//       expect(tokenAddress).to.not.be.null;
//       expect(tokenAddress).to.not.be.undefined;
//       expect(tokenAddress).to.equal(await cloudax.getAddress());
//     });
//   });

//   describe("setBeneficiaryAddress", function () {
//     it("should set the beneficiary address", async function () {
//       const { cloudaxPublicIDOVestingWallet, owner, john } = await deployAndSetup();
//       await cloudaxPublicIDOVestingWallet.connect(owner).setBeneficiaryAddress(john.address);
//       expect(await cloudaxPublicIDOVestingWallet.getBeneficiaryAddress()).to.equal(john.address);
//     });

//     it("should revert if called by a non-owner", async function () {
//       const { cloudaxPublicIDOVestingWallet, john, jane } = await deployAndSetup();
//       await expect(cloudaxPublicIDOVestingWallet.connect(john).setBeneficiaryAddress(jane.address)).to.be.revertedWithCustomError;
//     });
//   });

//   describe("getCurrentTime", function () {
//     it("should return the current timestamp", async function () {
//       const { cloudaxPublicIDOVestingWallet } = await deployAndSetup();
//       const currentTime = await cloudaxPublicIDOVestingWallet.getCurrentTime();
//       expect(currentTime).to.be.gt(0);
//     });
//   });

//   describe("withdraw", function () {
//     it("should allow the owner to withdraw tokens when paused", async function () {
//       const { cloudaxPublicIDOVestingWallet, owner } = await deployAndSetup();
//       await cloudax.connect(owner).setTradingEnabled(true);
//       const withdrawableAmount = await cloudaxPublicIDOVestingWallet.getWithdrawableAmount();
//       await cloudaxPublicIDOVestingWallet.connect(owner).withdraw(withdrawableAmount);
//       expect(await cloudaxPublicIDOVestingWallet.getWithdrawableAmount()).to.equal(0);
//     });
//     it("should revert if called by a non-owner", async function () {
//       const { cloudaxPublicIDOVestingWallet, john } = await deployAndSetup();
//       await expect(cloudaxPublicIDOVestingWallet.connect(john).withdraw(1)).to.be.revertedWithCustomError;
//     });
//   });

//   describe("getToken", function () {
//     it("should return the address of the ERC20 token", async function () {
//       const { cloudaxPublicIDOVestingWallet, cloudax } = await deployAndSetup();
//       const tokenAddress = await cloudaxPublicIDOVestingWallet.getToken();
//       expect(tokenAddress).to.not.be.null;
//       expect(tokenAddress).to.not.be.undefined;
//       expect(tokenAddress).to.equal(await cloudax.getAddress());
//     });
//   });

//   describe("only owner can withdraw", function () {
//       it("should revert if the contract is not paused", async function () {
//         const { cloudaxPublicIDOVestingWallet, john, owner, cloudax } = await deployAndSetup();
//         // send cldx to public
//         await cloudax.connect(owner).setTradingEnabled(true);
//         await cloudax.connect(owner).sendTokens(cloudaxPublicIDOVestingWallet.getAddress(), 1000)
//         await expect(cloudaxPublicIDOVestingWallet.connect(john).withdraw(1000)).to.be.revertedWithCustomError;
//       });
//     });

//     describe("tge duration can only be set by owner", function () {
//       it("only owner should set tge duration", async function () {
//         const { cloudaxPublicIDOVestingWallet, john, owner } = await deployAndSetup();
//         await expect(cloudaxPublicIDOVestingWallet.connect(john).setTgeDate(6)).to.be.revertedWithCustomError;
//       });
//       it("only owner should set tge duration", async function () {
//         const { cloudaxPublicIDOVestingWallet, owner } = await deployAndSetup();
//         const duration = 6;
//         await cloudaxPublicIDOVestingWallet.connect(owner).setTgeDate(duration);
//       });
//     });

//     describe("releaseTgeFunds", function () {
//       it("should release TGE funds if TGE has happened and beneficiary address is set", async function () {
//         const { cloudaxPublicIDOVestingWallet, owner } = await deployAndSetup();
//         await cloudaxPublicIDOVestingWallet.connect(owner).setBeneficiaryAddress(owner.address)
//         await cloudax.connect(owner).setTradingEnabled(true);
//         await cloudax.connect(owner).sendTokens(cloudaxPublicIDOVestingWallet.getAddress(), ethers.parseUnits("1000"))
//         await expect(cloudaxPublicIDOVestingWallet.connect(owner).releaseTgeFunds()).to.be.revertedWithCustomError
//       });
//     });

//     describe("tge duration can only be set by owner", function () {
//       it("only owner should set tge duration", async function () {
//         const { cloudaxPublicIDOVestingWallet, john, owner } = await deployAndSetup();
//         await expect(cloudaxPublicIDOVestingWallet.connect(john).setTgeDate(6)).to.be.revertedWithCustomError;
//       });
//       it("should revert if TGE has not happened", async function () {
//         const { cloudaxPublicIDOVestingWallet, owner } = await deployAndSetup();
//         await cloudaxPublicIDOVestingWallet.connect(owner).setBeneficiaryAddress(owner.address)
//         await cloudax.connect(owner).setTradingEnabled(true);
//         // Assuming TGE has not happened
//         await expect(cloudaxPublicIDOVestingWallet.connect(owner).releaseTgeFunds()).to.be.revertedWithCustomError
//       });
  
//       it("should revert if beneficiary address has not been set", async function () {
//         const { cloudaxPublicIDOVestingWallet, owner } = await deployAndSetup();
//         // Assuming TGE has happened but beneficiary address is not set
//         await expect(cloudaxPublicIDOVestingWallet.connect(owner).releaseTgeFunds()).to.be.revertedWith("Beneficiary Address has not been set");
//       });
//     });

//     describe("burn", function () {
//       it("should burn tokens if the amount is greater than zero and the contract has enough tokens", async function () {
//         const { cloudaxPublicIDOVestingWallet, owner } = await deployAndSetup();
//         await cloudax.connect(owner).setTradingEnabled(true);
//         await cloudax.connect(owner).sendTokens(cloudaxPublicIDOVestingWallet.getAddress(), ethers.parseUnits("1000"))
//         const amount = ethers.parseEther("100");
//         await expect(cloudaxPublicIDOVestingWallet.connect(owner).burn(amount))
//           .to.emit(cloudaxPublicIDOVestingWallet, "TokenBurnt")
//           .withArgs(cloudaxPublicIDOVestingWallet.getAddress, owner.address, owner.address,"0x000000000000000000000000000000000000dEaD", amount);
//       });
  
//       it("should revert if the amount is zero", async function () {
//         const { cloudaxPublicIDOVestingWallet, owner } = await deployAndSetup();
//         await cloudax.connect(owner).setTradingEnabled(true);
//         await cloudax.connect(owner).sendTokens(cloudaxPublicIDOVestingWallet.getAddress(), ethers.parseUnits("1000"))
//         await expect(cloudaxPublicIDOVestingWallet.connect(owner).burn(0)).to.be.revertedWith("Amount must be greater than Zero");
//       });
  
//       it("should revert if the contract does not have enough tokens", async function () {
//         const { cloudaxPublicIDOVestingWallet, owner } = await deployAndSetup();
//         await cloudax.connect(owner).setTradingEnabled(true);
//         await cloudax.connect(owner).sendTokens(cloudaxPublicIDOVestingWallet.getAddress(), ethers.parseEther("10000"))
//         const amount = ethers.parseEther("1000000"); // Assuming the contract has less than this amount
//         await expect(cloudaxPublicIDOVestingWallet.connect(owner).burn(amount)).to.be.revertedWith("Not enough tokens in treasury");
//       });
//     });

// });
