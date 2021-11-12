const { ethers, upgrades } = require("hardhat");
const { expect } = require("chai");
let chai = require("chai");
let chaiAsPromised = require("chai-as-promised");
chai.use(chaiAsPromised);

describe("test", () => {
  let owner, tokenContract, icoContract, all, postDistributionBalance;
  // addresses
  let add1, add2, add3, add4, add5, add6, add7, add8, add9, add10, add11;

  beforeEach(async () => {
    let ICO = await ethers.getContractFactory("ICOUpgradeable");
    let Token = await ethers.getContractFactory("TestTokenUpgradeable");

    [
      owner,
      add1,
      add2,
      add3,
      add4,
      add5,
      add6,
      add7,
      add8,
      add9,
      add10,
      add11,
    ] = await ethers.getSigners();

    all = [add1, add2, add3, add4, add5, add6, add7, add8, add9, add10, add11];

    const blockNum = await ethers.provider.getBlockNumber();
    const block = await ethers.provider.getBlock(blockNum);
    startingTime = block.timestamp;

    // deploy the contracts
    tokenContract = await upgrades.deployProxy(Token);

    const blockNumBefore = await ethers.provider.getBlockNumber();
    const blockBefore = await ethers.provider.getBlock(blockNumBefore);
    const timestampBefore = blockBefore.timestamp;

    icoContract = await upgrades.deployProxy(ICO,[
      "7200000000000000000000",
      timestampBefore,
      300,
      tokenContract.address,
      [
        add1.address,
        add2.address,
        add3.address,
        add4.address,
        add5.address,
        add6.address,
        add7.address,
        add8.address,
        add9.address,
        add10.address,
      ]
    ]);

    // distribute the token for testing
    for (let i = 0; i < all.length; i++) {
      tokenContract
        .connect(owner)
        .transfer(all[i].address, "1000000000000000000000");
    }

    postDistributionBalance = tokenContract.balanceOf(owner.address);
  });

  describe("Contributions", async () => {
    it("should allow whitelisted to contribute correct amounts until limit is reached", async () => {
      await tokenContract
        .connect(add1)
        .approve(icoContract.address, "100000000000000000000");
      await icoContract.connect(add1).contribute("100000000000000000000");
      expect(await icoContract.totalAccumulated()).to.equal(
        "100000000000000000000"
      );
      expect(await icoContract.addressToContribution(add1.address)).to.equal(
        "100000000000000000000"
      );

      await tokenContract
        .connect(add1)
        .approve(icoContract.address, "400000000000000000000");
      await icoContract.connect(add1).contribute("400000000000000000000");
      expect(await icoContract.totalAccumulated()).to.equal(
        "500000000000000000000"
      );
      expect(await icoContract.addressToContribution(add1.address)).to.equal(
        "500000000000000000000"
      );

      await tokenContract
        .connect(add2)
        .approve(icoContract.address, "800000000000000000000");
      await icoContract.connect(add2).contribute("800000000000000000000");
      expect(await icoContract.totalAccumulated()).to.equal(
        "1300000000000000000000"
      );
      expect(await icoContract.addressToContribution(add1.address)).to.equal(
        "500000000000000000000"
      );
      expect(await icoContract.addressToContribution(add2.address)).to.equal(
        "800000000000000000000"
      );

      await expect(
        icoContract.connect(add2).contribute("100000000000000000000")
      ).to.be.revertedWith("Max limit reached");
    });

    it("should not allow whitelisted members to contribute after sale ends", async () => {
      for (let i = 0; i < 9; i++) {
        await tokenContract
          .connect(all[i])
          .approve(icoContract.address, "800000000000000000000");
        await icoContract.connect(all[i]).contribute("800000000000000000000");
      }

      await expect(
        icoContract.connect(add10).contribute("100000000000000000000")
      ).to.be.revertedWith("Contribution exceeds goal");
    });

    it("should not allow whitelist to contribute wrong amount", async () => {
      await tokenContract
        .connect(add1)
        .approve(icoContract.address, "250000000000000000000");
      await expect(
        icoContract.connect(add1).contribute("250000000000000000000")
      ).to.be.revertedWith("Incorrect amount");
    });

    it("should not allow non-whitelist members to contribute", async () => {
      await tokenContract
        .connect(add11)
        .approve(icoContract.address, "100000000000000000000");
      await expect(
        icoContract.connect(add11).contribute("100000000000000000000")
      ).to.be.reverted;
    });
  });

  describe("Withdraw", async () => {
    it("should not allow withdrawal before ICO ends", async () => {
      await expect(icoContract.connect(owner).withdraw()).to.be.revertedWith(
        "ICO in progress"
      );
    });

    it("should not allow non-admins to withdraw tokens", async () => {
      await expect(icoContract.connect(add1).withdraw()).to.be.reverted;
    });

    it("should allow withdrawal after goal is met", async () => {
      for (let i = 0; i < 9; i++) {
        await tokenContract
          .connect(all[i])
          .approve(icoContract.address, "800000000000000000000");
        await icoContract.connect(all[i]).contribute("800000000000000000000");
      }
      expect(await icoContract.totalAccumulated()).to.be.equal(
        await icoContract.GOAL()
      );

      await icoContract.connect(owner).withdraw();
      let balance = await postDistributionBalance;
      expect(await tokenContract.balanceOf(owner.address)).to.equal(
        balance.add(await icoContract.GOAL())
      );
    });
  });
});
