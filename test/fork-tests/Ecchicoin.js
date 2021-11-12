const IUniswapV2Router02 = require("@uniswap/v2-periphery/build/IUniswapV2Router02.json");
const { ethers, upgrades } = require("hardhat");
const { expect } = require("chai");
let chai = require("chai");
let chaiAsPromised = require("chai-as-promised");
chai.use(chaiAsPromised);
const ABI = require("../../abi/PancakeSwap.json");

describe("Coin deployment", () => {
  let owner, EcchiCoin, BUSDToken, PancakeSwap;
  let user1, user2, user3;

  beforeEach(async () => {
    let Token1 = await ethers.getContractFactory("EcchiCoin");
    let Token2 = await ethers.getContractFactory("TestToken");

    [owner, user1, user2, user3] = await ethers.getSigners();

    BUSDToken = await Token2.deploy();
    EcchiCoin = await Token1.deploy(BUSDToken.address);
    PancakeSwap = new ethers.Contract(
      "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D",
      ABI.abi
    );

    await BUSDToken.connect(owner).approve(
      PancakeSwap.address,
      "115792089237316195423570985008687907853269984665640564039457584007913129639935"
    );
    await EcchiCoin.connect(owner).approve(
      PancakeSwap.address,
      "115792089237316195423570985008687907853269984665640564039457584007913129639935"
    );
  });

  describe("Test anti-snipe", () => {
    it("Should allow owner to trade after deployment", async () => {
      await EcchiCoin.connect(owner).transfer(user1.address, "50000000000");
    });

    it("Should allow owner to trade after adding liquidity", async () => {
      await PancakeSwap.connect(owner).addLiquidity(
        EcchiCoin.address,
        BUSDToken.address,
        "500000000000000",
        "500000000000000000000000",
        "500000000000000",
        "500000000000000000000000",
        owner.address,
        Math.floor(Date.now() + 100000 / 1000)
      );

      await EcchiCoin.connect(owner).transfer(user1.address, "50000000000");
    });

    it("Should launch coin after adding liquidity", async () => {
      expect(await EcchiCoin.launched()).to.be.equal(false);

      await PancakeSwap.connect(owner).addLiquidity(
        EcchiCoin.address,
        BUSDToken.address,
        "500000000000000",
        "500000000000000000000000",
        "500000000000000",
        "500000000000000000000000",
        owner.address,
        Math.floor(Date.now() + 100000 / 1000)
      );

      expect(await EcchiCoin.launched()).to.be.equal(true);
    });

    it("Should not allow user to trade before launch", async () => {
      await EcchiCoin.connect(owner).transfer(user1.address, "50000000000");

      await expect(
        EcchiCoin.connect(user1).transfer(owner.address, "5000000000")
      ).to.be.revertedWith("Pre-Launch Protection");
    });

    it("Should allow users exempted from fees to trade before launch", async () => {
      await EcchiCoin.connect(owner).transfer(user1.address, "50000000000");

      await EcchiCoin.connect(owner).excludeFromFee(user1.address);
      await EcchiCoin.connect(user1).transfer(owner.address, "5000000000");
    });

    it("Should punish snipers with 99% liquidity fees", async () => {
      await EcchiCoin.connect(owner).transfer(user2.address, "500000000000");

      let firstBlock = await ethers.provider.getBlockNumber();
      await PancakeSwap.connect(owner).addLiquidity(
        EcchiCoin.address,
        BUSDToken.address,
        "500000000000000",
        "500000000000000000000000",
        "500000000000000",
        "500000000000000000000000",
        owner.address,
        Math.floor(Date.now() + 100000 / 1000)
      );

      await EcchiCoin.connect(user2).transfer(user3.address, "100000000000");
      expect(await EcchiCoin.balanceOf(EcchiCoin.address)).to.be.equal(
        "99000000000"
      );

      await EcchiCoin.connect(user2).approve(
        PancakeSwap.address,
        "100000000000"
      );

      await PancakeSwap.connect(
        user2
      ).swapExactTokensForTokensSupportingFeeOnTransferTokens(
        "100000000000",
        0, // accept any amount of BUSD
        [EcchiCoin.address, BUSDToken.address],
        user2.address,
        Math.floor(Date.now() / 1000)
      );
      let secondBlock = await ethers.provider.getBlockNumber();
      expect(secondBlock - firstBlock < (await EcchiCoin.deadBlocks()));

      expect(await EcchiCoin.balanceOf(EcchiCoin.address)).to.be.equal(
        "198000000000"
      );

      await network.provider.send("evm_mine");
      await network.provider.send("evm_mine");

      await EcchiCoin.connect(user2).transfer(user3.address, "100000000000");
      expect(await EcchiCoin.balanceOf(EcchiCoin.address)).to.be.equal(
        "202000000040"
      );
    });

    it("Should not punished approved", async () => {
      await EcchiCoin.connect(owner).transfer(user1.address, "300000000000");
      await EcchiCoin.connect(owner).excludeFromFee(user1.address);

      await PancakeSwap.connect(owner).addLiquidity(
        EcchiCoin.address,
        BUSDToken.address,
        "200000000000000",
        "200000000000000000000000",
        "200000000000000",
        "200000000000000000000000",
        owner.address,
        Math.floor(Date.now() + 100000 / 1000)
      );

      await EcchiCoin.connect(owner).transfer(user3.address, "200000000000");
      await EcchiCoin.connect(user1).transfer(user2.address, "200000000000");
      expect(await EcchiCoin.balanceOf(EcchiCoin.address)).to.be.equal("0");
    });
  });
});
