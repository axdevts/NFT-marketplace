const { ethers, upgrades } = require("hardhat");
const { expect } = require("chai");
let chai = require("chai");
let chaiAsPromised = require("chai-as-promised");
chai.use(chaiAsPromised);
const ABI = require("../../abi/PancakeSwap.json");

describe("Game Market Tests", () => {
  let GameMarketContract,
    ERC1155NFT,
    owner,
    BinanceUSD,
    EcchiCoin,
    ArtistNFT,
    PancakeSwap;
  let startingTime, all;
  let user1, user2, user3, user4, user5, user6, user7, user8, user9;

  /**
   * @dev deploy the NFT contract and mint some URI's before each test
   */
  beforeEach(async () => {
    let Token2 = await ethers.getContractFactory("GameMarketUpgradeable");
    let Token3 = await ethers.getContractFactory(
      "ERC1155CollectibleUpgradeable"
    );
    let Token4 = await ethers.getContractFactory("ArtistNFTUpgradeable");
    let Token5 = await ethers.getContractFactory("TestTokenUpgradeable");
    let Token6 = await ethers.getContractFactory("EcchiCoin");

    [owner, user1, user2, user3, user4, user5, user6, user7, user8, user9] =
      await ethers.getSigners();

    all = [user1, user2, user3, user4, user5, user6];

    PancakeSwap = new ethers.Contract(
      "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D",
      ABI.abi
    );

    BinanceUSD = await upgrades.deployProxy(Token5);
    EcchiCoin = await Token6.deploy(BinanceUSD.address);
    ArtistNFT = await upgrades.deployProxy(Token4);
    GameMarketContract = await upgrades.deployProxy(Token2, [
      ArtistNFT.address,
      BinanceUSD.address,
      EcchiCoin.address,
      5000 * 10 ** 9,
    ]);
    ERC1155NFT = await upgrades.deployProxy(Token3);

    await EcchiCoin.connect(owner).excludeFromFee(GameMarketContract.address);

    await EcchiCoin.connect(owner).approve(
      PancakeSwap.address,
      "115792089237316195423570985008687907853269984665640564039457584007913129639935"
    );
    await BinanceUSD.connect(owner).approve(
      PancakeSwap.address,
      "115792089237316195423570985008687907853269984665640564039457584007913129639935"
    );

    await PancakeSwap.connect(owner).addLiquidity(
      BinanceUSD.address,
      EcchiCoin.address,
      "500000000000000000000000",
      "500000000000000",
      "500000000000000000000000",
      "500000000000000",
      owner.address,
      Math.floor(Date.now() + 100000 / 1000)
    );

    await EcchiCoin.connect(owner).setMaxTxPercent(1000);

    // distribute the token for testing
    for (let i = 0; i < all.length; i++) {
      await EcchiCoin.connect(owner).transfer(
        all[i].address,
        "5000000000000000" //5mil
      );
    }

    await EcchiCoin.connect(owner).setMaxTxPercent(3);

    // setting marketplace approval for buyer
    await ERC1155NFT.connect(owner).setApprovalForAll(
      GameMarketContract.address,
      true
    );
    await ArtistNFT.connect(owner).setApprovalForAll(
      GameMarketContract.address,
      true
    );

    await ArtistNFT.connect(owner).safeMint(owner.address, owner.address, 5, [
      "def.com/1",
      "def.com/2",
      "def.com/3",
      "def.com/4",
      "def.com/5",
    ]);
    await ERC1155NFT.connect(owner).create(0, owner.address, 5, []);

    const blockNum = await ethers.provider.getBlockNumber();
    const block = await ethers.provider.getBlock(blockNum);
    startingTime = block.timestamp;
  });

  describe("Testing FixedPriceSale contract", () => {
    /**
     * @dev cheking that the GameMarketplace contract works correctly
     */
    it("Should create a fixed price sale for ERC721 and ERC1155", async () => {
      startingTime = startingTime - 100;
      // testing ERC721
      await GameMarketContract.connect(owner).createSaleFixedPrice(
        ArtistNFT.address,
        0,
        1,
        "30000000000",
        startingTime
      );
      expect(await ArtistNFT.ownerOf(0)).to.equal(GameMarketContract.address);

      await EcchiCoin.connect(user1).approve(
        GameMarketContract.address,
        "30000000000"
      );

      await GameMarketContract.connect(user1).buy(0);
      expect(await ArtistNFT.ownerOf(0)).to.equal(user1.address);

      // testing ERC1155 (token IDs start from 1)
      await GameMarketContract.connect(owner).createSaleFixedPrice(
        ERC1155NFT.address,
        1,
        2,
        30000000000,
        startingTime
      );
      expect(
        await ERC1155NFT.balanceOf(GameMarketContract.address, 1)
      ).to.include({ _hex: "0x02", _isBigNumber: true });

      await EcchiCoin.connect(user1).approve(
        GameMarketContract.address,
        30000000000
      );
      await GameMarketContract.connect(user1).buy(1);
      expect(await ERC1155NFT.balanceOf(user1.address, 1)).to.include({
        _hex: "0x02",
        _isBigNumber: true,
      });

      // testing that marketplace approval only needs to be given once
      await GameMarketContract.connect(owner).createSaleFixedPrice(
        ArtistNFT.address,
        1,
        1,
        30000000000,
        startingTime
      );
      expect(await ArtistNFT.ownerOf(1)).to.equal(GameMarketContract.address);

      // approve EcchiCoin
      await EcchiCoin.connect(user1).approve(
        GameMarketContract.address,
        30000000000
      );
      // buy with EcchiCoin
      await GameMarketContract.connect(user1).buy(2);
      expect(await ArtistNFT.ownerOf(1)).to.equal(user1.address);
    });

    it("Should create a bulk fixed price sale for ERC721 and ERC1155", async () => {
      await GameMarketContract.connect(owner).createBulkSaleFixedPrice(
        ArtistNFT.address,
        [0, 1],
        [1, 1],
        [200000000000, 300000000000],
        [startingTime, startingTime]
      );

      await GameMarketContract.connect(owner).createBulkSaleFixedPrice(
        ERC1155NFT.address,
        [1, 1],
        [1, 2],
        [300000000000, 600000000000],
        [startingTime, startingTime]
      );

      expect(await ArtistNFT.ownerOf(0)).to.equal(GameMarketContract.address);
      expect(await ArtistNFT.ownerOf(1)).to.equal(GameMarketContract.address);
      expect(
        await ERC1155NFT.balanceOf(GameMarketContract.address, 1)
      ).to.equal(ethers.BigNumber.from("3"));

      await EcchiCoin.connect(user2).approve(
        GameMarketContract.address,
        300000000000
      );
      await GameMarketContract.connect(user2).buy(1);

      await EcchiCoin.connect(user2).approve(
        GameMarketContract.address,
        200000000000
      );
      await GameMarketContract.connect(user2).buy(0);

      await EcchiCoin.connect(user3).approve(
        GameMarketContract.address,
        300000000000
      );
      await GameMarketContract.connect(user3).buy(2);

      await EcchiCoin.connect(user4).approve(
        GameMarketContract.address,
        600000000000
      );
      await GameMarketContract.connect(user4).buy(3);
    });

    it("Should not allow user to buy for less than the sale price", async () => {
      startingTime = startingTime - 100;
      // testing ERC721
      await GameMarketContract.connect(owner).createSaleFixedPrice(
        ArtistNFT.address,
        0,
        1,
        30000000000,
        startingTime
      );
      expect(await ArtistNFT.ownerOf(0)).to.equal(GameMarketContract.address);

      await EcchiCoin.connect(user1).approve(
        GameMarketContract.address,
        29000000000
      );

      await expect(GameMarketContract.connect(user1).buy(0)).to.be.reverted;

      // testing ERC1155 (token IDs start from 1)
      await GameMarketContract.connect(owner).createSaleFixedPrice(
        ERC1155NFT.address,
        1,
        2,
        30000000000,
        startingTime
      );
      expect(
        await ERC1155NFT.balanceOf(GameMarketContract.address, 1)
      ).to.include({ _hex: "0x02", _isBigNumber: true });

      await EcchiCoin.connect(user1).approve(
        GameMarketContract.address,
        29000000000
      );
      await expect(GameMarketContract.connect(user1).buy(1)).to.be.reverted;
    });

    it("Should distribute cuts correctly", async () => {
      // testing ERC1155 (token IDs start from 1)
      await GameMarketContract.connect(owner).createSaleFixedPrice(
        ERC1155NFT.address,
        1,
        3,
        30000000000,
        startingTime
      );
      expect(
        await ERC1155NFT.balanceOf(GameMarketContract.address, 1)
      ).to.include({ _hex: "0x03", _isBigNumber: true });

      await GameMarketContract.connect(owner).changeWalletAddresses(
        user7.address,
        user8.address,
        user9.address
      );

      await EcchiCoin.connect(user1).approve(
        GameMarketContract.address,
        30000000000
      );
      await GameMarketContract.connect(user1).buy(0);
      expect(await ERC1155NFT.balanceOf(user1.address, 1)).to.include({
        _hex: "0x03",
        _isBigNumber: true,
      });
      // 1% to rewards wallet
      expect(await EcchiCoin.balanceOf(user7.address)).to.be.equal("300000000");
      // 0.5% to server wallet
      expect(await EcchiCoin.balanceOf(user8.address)).to.be.equal("150000000");
      // 0.5% to maintenance wallet
      expect(await EcchiCoin.balanceOf(user9.address)).to.be.equal("150000000");
    });

    it("Should add to liquidity after reaching cap", async () => {
      await GameMarketContract.connect(owner).createSaleFixedPrice(
        ERC1155NFT.address,
        1,
        3,
        500000000000000, //5 hundred thousand
        startingTime
      );
      expect(
        await ERC1155NFT.balanceOf(GameMarketContract.address, 1)
      ).to.include({ _hex: "0x03", _isBigNumber: true });

      await GameMarketContract.connect(owner).createSaleFixedPrice(
        ERC1155NFT.address,
        1,
        2,
        500000000000000, //5 hundred thousand
        startingTime
      );
      expect(
        await ERC1155NFT.balanceOf(GameMarketContract.address, 1)
      ).to.include({ _hex: "0x05", _isBigNumber: true });

      await EcchiCoin.connect(user1).approve(
        GameMarketContract.address,
        500000000000000 //5 hundred thousand
      );
      await GameMarketContract.connect(user1).buy(0);
      expect(await ERC1155NFT.balanceOf(user1.address, 1)).to.include({
        _hex: "0x03",
        _isBigNumber: true,
      });

      await EcchiCoin.connect(user2).approve(
        GameMarketContract.address,
        500000000000000 //5 hundred thousand
      );
      await expect(GameMarketContract.connect(user2).buy(1)).to.emit(
        GameMarketContract,
        "SwapAndLiquify"
      );
      expect(await ERC1155NFT.balanceOf(user1.address, 1)).to.include({
        _hex: "0x03",
        _isBigNumber: true,
      });
    });
  });
});
