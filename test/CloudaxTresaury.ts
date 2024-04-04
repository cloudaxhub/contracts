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
      // make jane the oracle
      await cloudaxTresuary.connect(owner).setOracleAddress(jane.address);
      // transfer cldx to user
      await cloudax.connect(owner).transfer(john.address, amount);

      // initialize swap
      await cloudaxTresuary.connect(jane).initiateSwap(amount, john.address);
      const amountOfEcoSwapBefore = await cloudaxTresuary._swappedForEco(
        jane.address
      );

      await cloudax
        .connect(john)
        .transfer(cloudaxTresuary.getAddress(), amount);

      // const burnAmount = (amount * 20) / 100; // 20% of the amount to burn
      // const lockAmount = amount - burnAmount; // The rest to lock

      // await cloudaxTresuary
      //   .connect(john)
      //   .swapCldxToEco(ethers.parseEther(String(amount)), jane.address);
      // Additional checks for the swap can be added here

      const amountOfEcoSwapAfter = await cloudaxTresuary._swappedForEco(
        jane.address
      );
      const amountOfEcoSwapDifference =
        amountOfEcoSwapAfter - amountOfEcoSwapBefore;
      expect(amountOfEcoSwapAfter).to.be.equal(
        amount
      );
    });

    // it("should revert if the sender is not an approved Eco wallet", async function () {
    //   const { cloudaxTresuary, owner, john, jane } = await loadFixture(
    //     deployAndSetup
    //   );
    //   // send cldx to tresuary
    //   await cloudax.connect(owner).setTradingEnabled(true);
    //   const amount: any = 100;
    //   const burnAmount = (amount * 20) / 100; // 20% of the amount to burn
    //   const lockAmount = amount - burnAmount; // The rest to lock
    //   await cloudax
    //     .connect(owner)
    //     .transfer(
    //       cloudaxTresuary.getAddress(),
    //       ethers.parseEther(String(amount))
    //     );

    //   await cloudaxTresuary.connect(owner).setOracleAddress(john.address);
    //   // // Assuming john is not an approved Eco wallet
    //   // await cloudaxTresuary.connect(owner).aproveEcoWallet(john.address);
    //   expect(
    //     await cloudaxTresuary
    //       .connect(john)
    //       .swapCldxToEco(ethers.parseEther(String(amount)), jane.address)
    //   ).to.be.revertedWithCustomError;
    //   // console.log(`for CLDX: ${await cloudaxTresuary.connect(owner)._swappedForCldx(jane.address)}`)
    //   // expect(await cloudaxTresuary.connect(owner)._swappedForEco(jane.address)).to.be.equal(lockAmount)
    // });
  });

  //  describe("swapEcoToCldx", function () {
  //     it("should swap ECO to CLDX", async function () {
  //       const { cloudaxTresuary, owner, john } = await loadFixture(deployAndSetup);
  //       await cloudaxTresuary.connect(owner).setOracleAddress(john.address);
  //       // Assuming john has enough ECO tokens and the contract has enough CLDX tokens
  //       await cloudaxTresuary.connect(john).swapEcoToCldx(ethers.utils.parseEther("100"), jane.address);
  //       // Additional checks for the swap can be added here
  //     });
  //  });

  //  describe("approveEcoWallet", function () {
  //     it("should approve an Eco wallet", async function () {
  //       const { cloudaxTresuary, owner } = await loadFixture(deployAndSetup);
  //       await cloudaxTresuary.connect(owner).approveEcoWallet(john.address);
  //       expect(await cloudaxTresuary.ecoApprovalWallet(john.address)).to.be.true;
  //     });
  //  });

  //  describe("removeEcoWallet", function () {
  //     it("should remove an approved Eco wallet", async function () {
  //       const { cloudaxTresuary, owner } = await loadFixture(deployAndSetup);
  //       await cloudaxTresuary.connect(owner).approveEcoWallet(john.address);
  //       await cloudaxTresuary.connect(owner).removeEcoWallet(john.address);
  //       expect(await cloudaxTresuary.ecoApprovalWallet(john.address)).to.be.false;
  //     });
  //  });

  //  describe("burn", function () {
  //     it("should burn tokens", async function () {
  //       const { cloudaxTresuary, owner } = await loadFixture(deployAndSetup);
  //       // Assuming the contract has enough CLDX tokens
  //       await cloudaxTresuary.connect(owner).burn(ethers.utils.parseEther("100"));
  //       // Additional checks for the burn can be added here
  //     });
  //  });
});
