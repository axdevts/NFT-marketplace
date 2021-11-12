const { ethers, upgrades } = require("hardhat");
const { expect } = require("chai");
const chai = require("chai");
const chaiAsPromised = require("chai-as-promised");
chai.use(chaiAsPromised);
const ABI = require("../../abi/PancakeSwap.json");

// This test needs to be run on a Mainnet fork
describe("Black Market Tests", () => {
  let BlackMarketContract,
    owner,
    all,
    BUSD,
    EcchiCoin,
    PancakeRouter,
    ERC1155NFT,
    ArtistNFT;
  let startingTime;
  let user1, user2, user3, user4, user5, user6, user7, user8, user9;

  /**
   * @dev deploy the NFT contract and mint some URI's before each test
   */
  beforeEach(async () => {
    let Token2 = await ethers.getContractFactory("BlackMarketUpgradeable");
    let Token3 = await ethers.getContractFactory(
      "ERC1155CollectibleUpgradeable"
    );
    let Token4 = await ethers.getContractFactory("ArtistNFTUpgradeable");
    let Token5 = await ethers.getContractFactory("EcchiCoin");
    let Token6 = await ethers.getContractFactory("TestTokenUpgradeable");

    [owner, user1, user2, user3, user4, user5, user6, user7, user8, user9] =
      await ethers.getSigners();

    all = [user1, user2, user3, user4, user5, user6];

    PancakeRouter = new ethers.Contract(
      "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D",
      ABI.abi
    );

    //region Deploy contracts
    BUSD = await upgrades.deployProxy(Token6);
    EcchiCoin = await Token5.deploy(BUSD.address);
    ArtistNFT = await upgrades.deployProxy(Token4);
    BlackMarketContract = await upgrades.deployProxy(Token2, [
      ArtistNFT.address,
      BUSD.address,
      EcchiCoin.address,
      ethers.utils.parseEther("50"),
    ]);
    ERC1155NFT = await upgrades.deployProxy(Token3);
    //endregion

    //region Set approval for marketplace
    await ArtistNFT.connect(owner).setApprovalForAll(
      BlackMarketContract.address,
      true
    );
    await ERC1155NFT.connect(owner).setApprovalForAll(
      BlackMarketContract.address,
      true
    );
    //endregion

    //region Mint the NFTs for testing
    await ArtistNFT.connect(owner).safeMint(owner.address, owner.address, 3, [
      "def.com/1",
      "def.com/2",
      "def.com/3",
    ]);
    await ERC1155NFT.connect(owner).create(0, owner.address, 5, []);
    //endregion

    //region Add liquidity to PancakeSwap

    await BUSD.connect(owner).approve(
      PancakeRouter.address,
      "115792089237316195423570985008687907853269984665640564039457584007913129639935"
    );
    await EcchiCoin.connect(owner).approve(
      PancakeRouter.address,
      "115792089237316195423570985008687907853269984665640564039457584007913129639935"
    );

    await PancakeRouter.connect(owner).addLiquidity(
      EcchiCoin.address,
      BUSD.address,
      "500000000000000",
      "500000000000000000000000",
      "500000000000000",
      "500000000000000000000000",
      owner.address,
      Math.floor(Date.now() + 100000 / 1000)
    );
    //endregion

    //region Distribute the token for testing
    for (let i = 0; i < all.length; i++) {
      BUSD.connect(owner).transfer(
        all[i].address,
        ethers.utils.parseEther("5000")
      );
    }
    //endregion

    const blockNum = await ethers.provider.getBlockNumber();
    const block = await ethers.provider.getBlock(blockNum);
    startingTime = block.timestamp;
  });

  describe("Testing FixedPriceSale contract", () => {
    /**
     * @dev cheking that the OfficialMarketplace contract works correctly
     */
    it("Should create a fixed price sale for ERC721 and ERC1155", async () => {
      startingTime = startingTime - 100;
      // testing ERC721
      await BlackMarketContract.connect(owner).createSaleFixedPrice(
        ArtistNFT.address,
        0,
        1,
        ethers.utils.parseEther("30"),
        startingTime
      );
      expect(await ArtistNFT.ownerOf(0)).to.equal(BlackMarketContract.address);

      await BUSD.connect(user1).approve(
        BlackMarketContract.address,
        ethers.utils.parseEther("30")
      );

      await BlackMarketContract.connect(user1).buy(0);
      expect(await ArtistNFT.ownerOf(0)).to.equal(user1.address);

      // testing ERC1155 (token IDs start from 1)
      await BlackMarketContract.connect(owner).createSaleFixedPrice(
        ERC1155NFT.address,
        1,
        2,
        ethers.utils.parseEther("30"),
        startingTime
      );
      expect(
        await ERC1155NFT.balanceOf(BlackMarketContract.address, 1)
      ).to.include({ _hex: "0x02", _isBigNumber: true });

      await BUSD.connect(user1).approve(
        BlackMarketContract.address,
        ethers.utils.parseEther("30")
      );
      await BlackMarketContract.connect(user1).buy(1);
      expect(await ERC1155NFT.balanceOf(user1.address, 1)).to.include({
        _hex: "0x02",
        _isBigNumber: true,
      });

      // testing that marketplace approval only needs to be given once
      await BlackMarketContract.connect(owner).createSaleFixedPrice(
        ArtistNFT.address,
        1,
        1,
        ethers.utils.parseEther("30"),
        startingTime
      );
      expect(await ArtistNFT.ownerOf(1)).to.equal(BlackMarketContract.address);

      // approve BUSD
      await BUSD.connect(user1).approve(
        BlackMarketContract.address,
        ethers.utils.parseEther("30")
      );
      // buy with BUSD
      await BlackMarketContract.connect(user1).buy(2);
      expect(await ArtistNFT.ownerOf(1)).to.equal(user1.address);
    });

    it("Should create a bulk fixed price sale for ERC721 and ERC1155", async () => {
      await BlackMarketContract.connect(owner).createBulkSaleFixedPrice(
        ArtistNFT.address,
        [0, 1],
        [1, 1],
        [ethers.utils.parseEther("200"), ethers.utils.parseEther("300")],
        [startingTime, startingTime]
      );

      await BlackMarketContract.connect(owner).createBulkSaleFixedPrice(
        ERC1155NFT.address,
        [1, 1],
        [1, 2],
        [ethers.utils.parseEther("300"), ethers.utils.parseEther("600")],
        [startingTime, startingTime]
      );

      expect(await ArtistNFT.ownerOf(0)).to.equal(BlackMarketContract.address);
      expect(await ArtistNFT.ownerOf(1)).to.equal(BlackMarketContract.address);
      expect(
        await ERC1155NFT.balanceOf(BlackMarketContract.address, 1)
      ).to.equal(ethers.BigNumber.from("3"));

      await BUSD.connect(user2).approve(
        BlackMarketContract.address,
        ethers.utils.parseEther("300")
      );
      await BlackMarketContract.connect(user2).buy(1);

      await BUSD.connect(user2).approve(
        BlackMarketContract.address,
        ethers.utils.parseEther("200")
      );
      await BlackMarketContract.connect(user2).buy(0);

      await BUSD.connect(user3).approve(
        BlackMarketContract.address,
        ethers.utils.parseEther("300")
      );
      await BlackMarketContract.connect(user3).buy(2);

      await BUSD.connect(user4).approve(
        BlackMarketContract.address,
        ethers.utils.parseEther("600")
      );
      await BlackMarketContract.connect(user4).buy(3);
    });

    it("Should not allow user to buy for less than the sale price", async () => {
      startingTime = startingTime - 100;
      // testing ERC721
      await BlackMarketContract.connect(owner).createSaleFixedPrice(
        ArtistNFT.address,
        0,
        1,
        ethers.utils.parseEther("30"),
        startingTime
      );
      expect(await ArtistNFT.ownerOf(0)).to.equal(BlackMarketContract.address);

      await BUSD.connect(user1).approve(
        BlackMarketContract.address,
        ethers.utils.parseEther("29")
      );

      await expect(BlackMarketContract.connect(user1).buy(0)).to.be.reverted;

      // testing ERC1155 (token IDs start from 1)
      await BlackMarketContract.connect(owner).createSaleFixedPrice(
        ERC1155NFT.address,
        1,
        2,
        ethers.utils.parseEther("30"),
        startingTime
      );
      expect(
        await ERC1155NFT.balanceOf(BlackMarketContract.address, 1)
      ).to.include({ _hex: "0x02", _isBigNumber: true });

      await BUSD.connect(user1).approve(
        BlackMarketContract.address,
        ethers.utils.parseEther("29")
      );
      await expect(BlackMarketContract.connect(user1).buy(1)).to.be.reverted;
    });

    it("Should distribute cuts correctly", async () => {
      // testing ERC1155 (token IDs start from 1)
      await BlackMarketContract.connect(owner).createSaleFixedPrice(
        ERC1155NFT.address,
        1,
        3,
        ethers.utils.parseEther("30"),
        startingTime
      );
      expect(
        await ERC1155NFT.balanceOf(BlackMarketContract.address, 1)
      ).to.include({ _hex: "0x03", _isBigNumber: true });

      await BlackMarketContract.connect(owner).changeWalletAddresses(
        user7.address,
        user8.address,
        user9.address
      );

      await BUSD.connect(user1).approve(
        BlackMarketContract.address,
        ethers.utils.parseEther("30")
      );
      await BlackMarketContract.connect(user1).buy(0);
      expect(await ERC1155NFT.balanceOf(user1.address, 1)).to.include({
        _hex: "0x03",
        _isBigNumber: true,
      });
      // 1% to rewards wallet
      expect(await BUSD.balanceOf(user7.address)).to.be.equal(
        "300000000000000000"
      );
      // 0.5% to server wallet
      expect(await BUSD.balanceOf(user8.address)).to.be.equal(
        "150000000000000000"
      );
      // 0.5% to maintenance wallet
      expect(await BUSD.balanceOf(user9.address)).to.be.equal(
        "150000000000000000"
      );
    });

    it("Should add to liquidity after reaching cap", async () => {
      await BlackMarketContract.connect(owner).createSaleFixedPrice(
        ERC1155NFT.address,
        1,
        3,
        ethers.utils.parseEther("5000"),
        startingTime
      );
      expect(
        await ERC1155NFT.balanceOf(BlackMarketContract.address, 1)
      ).to.include({ _hex: "0x03", _isBigNumber: true });

      await BlackMarketContract.connect(owner).createSaleFixedPrice(
        ERC1155NFT.address,
        1,
        2,
        ethers.utils.parseEther("5000"),
        startingTime
      );
      expect(
        await ERC1155NFT.balanceOf(BlackMarketContract.address, 1)
      ).to.include({ _hex: "0x05", _isBigNumber: true });

      await BUSD.connect(user1).approve(
        BlackMarketContract.address,
        ethers.utils.parseEther("5000")
      );
      await BlackMarketContract.connect(user1).buy(0);
      expect(await ERC1155NFT.balanceOf(user1.address, 1)).to.include({
        _hex: "0x03",
        _isBigNumber: true,
      });

      await BUSD.connect(user2).approve(
        BlackMarketContract.address,
        ethers.utils.parseEther("5000")
      );
      await expect(BlackMarketContract.connect(user2).buy(1)).to.emit(
        BlackMarketContract,
        "SwapAndLiquify"
      );
      expect(await ERC1155NFT.balanceOf(user1.address, 1)).to.include({
        _hex: "0x03",
        _isBigNumber: true,
      });
    });
  });

  describe("Testing AuctionSale contract", () => {
    /**
     * @dev cheking that the AuctionSale contract works correctly
     */
    it("Should create an Auction sale", async () => {
      await BlackMarketContract.connect(owner).createSaleAuction(
        ArtistNFT.address,
        0,
        1,
        ethers.utils.parseEther("300"),
        startingTime,
        7200
      );
      expect(await ArtistNFT.ownerOf(0)).to.equal(BlackMarketContract.address);

      await BUSD.connect(user2).approve(
        BlackMarketContract.address,
        ethers.utils.parseEther("300")
      );
      await BlackMarketContract.connect(user2).bid(
        0,
        ethers.utils.parseEther("300")
      );
    });

    it("Should create a Bulk Auction sale", async () => {
      await BlackMarketContract.connect(owner).createBulkSaleAuction(
        ArtistNFT.address,
        [0, 1],
        [1, 1],
        [ethers.utils.parseEther("300"), ethers.utils.parseEther("300")],
        [startingTime, startingTime],
        [7200, 7200]
      );
      expect(await ArtistNFT.ownerOf(0)).to.equal(BlackMarketContract.address);
      expect(await ArtistNFT.ownerOf(1)).to.equal(BlackMarketContract.address);

      await BUSD.connect(user2).approve(
        BlackMarketContract.address,
        ethers.utils.parseEther("300")
      );
      await BlackMarketContract.connect(user2).bid(
        1,
        ethers.utils.parseEther("300")
      );

      await BUSD.connect(user2).approve(
        BlackMarketContract.address,
        ethers.utils.parseEther("300")
      );
      await BlackMarketContract.connect(user2).bid(
        0,
        ethers.utils.parseEther("300")
      );
    });

    /**
     * @dev checking the finishAuction function
     */
    it("Should finish Auction sale if called by owner", async () => {
      startingTime = startingTime - 7199;
      await BlackMarketContract.connect(owner).createSaleAuction(
        ArtistNFT.address,
        1,
        1,
        500,
        startingTime,
        7200
      );
      await BlackMarketContract.connect(owner).finishAuction(0);
      expect(await ArtistNFT.ownerOf(1)).to.equal(owner.address);
    });

    it("Should finish Auction sale if called by seller", async () => {
      startingTime = startingTime - 7199;
      await BlackMarketContract.connect(owner).createSaleAuction(
        ArtistNFT.address,
        2,
        1,
        500,
        startingTime,
        7200
      );
      await BlackMarketContract.connect(owner).finishAuction(0);
      expect(await ArtistNFT.ownerOf(2)).to.equal(owner.address);
    });

    /**
     * @dev checking the error cases for reject offer function
     */
    it("Should not accept bid that is too low", async () => {
      await BlackMarketContract.connect(owner).createSaleAuction(
        ArtistNFT.address,
        1,
        1,
        500,
        startingTime,
        7200
      );

      await BUSD.connect(user2).approve(BlackMarketContract.address, 499);
      await expect(
        BlackMarketContract.connect(user2).bid(0, 499)
      ).to.be.revertedWith("Bid is too low");
      expect(await ArtistNFT.ownerOf(1)).to.equal(BlackMarketContract.address);
    });

    it("Should return error if wrong sale id", async () => {
      await BlackMarketContract.connect(owner).createSaleAuction(
        ArtistNFT.address,
        0,
        1,
        500,
        startingTime,
        7200
      );
      expect(await ArtistNFT.ownerOf(0)).to.equal(BlackMarketContract.address);

      await BUSD.connect(user2).approve(BlackMarketContract.address, 500);
      await expect(
        BlackMarketContract.connect(user2).bid(1, 500)
      ).to.be.rejectedWith("Item is not on auction");
      expect(await ArtistNFT.ownerOf(0)).to.equal(BlackMarketContract.address);
    });

    it("Should return error if trying to bid before starting time", async () => {
      startingTime = startingTime + 100;
      await BlackMarketContract.connect(owner).createSaleAuction(
        ArtistNFT.address,
        1,
        1,
        500,
        startingTime,
        7200
      );

      await BUSD.connect(user2).approve(BlackMarketContract.address, 500);
      await expect(
        BlackMarketContract.connect(user2).bid(0, 500)
      ).to.be.rejectedWith("Item is not on auction");
      expect(await ArtistNFT.ownerOf(1)).to.equal(BlackMarketContract.address);
    });

    /**
     * @dev checking the error cases for finishAuction function
     */
    it("Should return error if finishAuction is called for wrong token id", async () => {
      await BlackMarketContract.connect(owner).createSaleAuction(
        ArtistNFT.address,
        1,
        1,
        500,
        startingTime,
        7200
      );
      await expect(BlackMarketContract.finishAuction(2)).to.be.rejectedWith(
        "Invalid sale id"
      );
      expect(await ArtistNFT.ownerOf(1)).to.equal(BlackMarketContract.address);
    });
  });
});
