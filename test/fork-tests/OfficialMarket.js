const { ethers, upgrades } = require("hardhat");
const { expect } = require("chai");
let chai = require("chai");
let chaiAsPromised = require("chai-as-promised");
chai.use(chaiAsPromised);
const ABI = require("../../abi/PancakeSwap.json");

describe("Official Market Tests", () => {
  let OfficialMarketContract,
    ERC1155NFT,
    owner,
    EcchiCoin,
    BUSD,
    ArtistNFT,
    PancakeSwap;
  let startingTime, all;
  let user1, user2, user3, user4, user5, user6, user7, user8, user9;

  /**
   * @dev deploy the NFT contract and mint some URI's before each test
   */
  beforeEach(async () => {
    let Token2 = await ethers.getContractFactory("OfficialMarketUpgradeable");
    let Token3 = await ethers.getContractFactory(
      "ERC1155CollectibleUpgradeable"
    );
    let Token4 = await ethers.getContractFactory("ArtistNFTUpgradeable");
    let Token5 = await ethers.getContractFactory("EcchiCoin");
    let Token6 = await ethers.getContractFactory("TestTokenUpgradeable");

    [owner, user1, user2, user3, user4, user5, user6, user7, user8, user9] =
      await ethers.getSigners();

    all = [user1, user2, user3, user4, user5, user6];

    PancakeSwap = new ethers.Contract(
      "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D",
      ABI.abi
    );

    BUSD = await upgrades.deployProxy(Token6);
    EcchiCoin = await Token5.deploy(BUSD.address);
    ArtistNFT = await upgrades.deployProxy(Token4);
    OfficialMarketContract = await upgrades.deployProxy(Token2, [
      ArtistNFT.address,
      BUSD.address,
      EcchiCoin.address,
      ethers.utils.parseEther("50"),
    ]);
    ERC1155NFT = await upgrades.deployProxy(Token3);

    await BUSD.connect(owner).approve(
      PancakeSwap.address,
      "115792089237316195423570985008687907853269984665640564039457584007913129639935"
    );
    await EcchiCoin.connect(owner).approve(
      PancakeSwap.address,
      "115792089237316195423570985008687907853269984665640564039457584007913129639935"
    );

    await PancakeSwap.connect(owner).addLiquidity(
      EcchiCoin.address,
      BUSD.address,
      "500000000000000",
      "500000000000000000000000",
      "500000000000000",
      "500000000000000000000000",
      owner.address,
      Math.floor(Date.now() + 100000 / 1000)
    );

    // distribute the token for testing
    for (let i = 0; i < all.length; i++) {
      await BUSD.connect(owner).transfer(
        all[i].address,
        ethers.utils.parseEther("5000")
      );
    }

    // setting marketplace approval for buyer
    await ERC1155NFT.connect(owner).setApprovalForAll(
      OfficialMarketContract.address,
      true
    );
    await ArtistNFT.connect(owner).setApprovalForAll(
      OfficialMarketContract.address,
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
     * @dev cheking that the OfficialMarketplace contract works correctly
     */
    it("Should create a fixed price sale for ERC721 and ERC1155", async () => {
      startingTime = startingTime - 100;
      // testing ERC721
      await OfficialMarketContract.connect(owner).createSaleFixedPrice(
        ArtistNFT.address,
        0,
        1,
        ethers.utils.parseEther("30"),
        startingTime
      );
      expect(await ArtistNFT.ownerOf(0)).to.equal(
        OfficialMarketContract.address
      );

      await BUSD.connect(user1).approve(
        OfficialMarketContract.address,
        ethers.utils.parseEther("30")
      );

      await OfficialMarketContract.connect(user1).buy(0);
      expect(await ArtistNFT.ownerOf(0)).to.equal(user1.address);

      // testing ERC1155 (token IDs start from 1)
      await OfficialMarketContract.connect(owner).createSaleFixedPrice(
        ERC1155NFT.address,
        1,
        2,
        ethers.utils.parseEther("30"),
        startingTime
      );
      expect(
        await ERC1155NFT.balanceOf(OfficialMarketContract.address, 1)
      ).to.include({ _hex: "0x02", _isBigNumber: true });

      await BUSD.connect(user1).approve(
        OfficialMarketContract.address,
        ethers.utils.parseEther("30")
      );
      await OfficialMarketContract.connect(user1).buy(1);
      expect(await ERC1155NFT.balanceOf(user1.address, 1)).to.include({
        _hex: "0x02",
        _isBigNumber: true,
      });

      // testing that marketplace approval only needs to be given once
      await OfficialMarketContract.connect(owner).createSaleFixedPrice(
        ArtistNFT.address,
        1,
        1,
        ethers.utils.parseEther("30"),
        startingTime
      );
      expect(await ArtistNFT.ownerOf(1)).to.equal(
        OfficialMarketContract.address
      );

      // approve BUSD
      await BUSD.connect(user1).approve(
        OfficialMarketContract.address,
        ethers.utils.parseEther("30")
      );
      // buy with BUSD
      await OfficialMarketContract.connect(user1).buy(2);
      expect(await ArtistNFT.ownerOf(1)).to.equal(user1.address);
    });

    it("Should create a bulk fixed price sale for ERC721 and ERC1155", async () => {
      await OfficialMarketContract.connect(owner).createBulkSaleFixedPrice(
        ArtistNFT.address,
        [0, 1],
        [1, 1],
        [ethers.utils.parseEther("200"), ethers.utils.parseEther("300")],
        [startingTime, startingTime]
      );

      await OfficialMarketContract.connect(owner).createBulkSaleFixedPrice(
        ERC1155NFT.address,
        [1, 1],
        [1, 2],
        [ethers.utils.parseEther("300"), ethers.utils.parseEther("600")],
        [startingTime, startingTime]
      );

      expect(await ArtistNFT.ownerOf(0)).to.equal(
        OfficialMarketContract.address
      );
      expect(await ArtistNFT.ownerOf(1)).to.equal(
        OfficialMarketContract.address
      );
      expect(
        await ERC1155NFT.balanceOf(OfficialMarketContract.address, 1)
      ).to.equal(ethers.BigNumber.from("3"));

      await BUSD.connect(user2).approve(
        OfficialMarketContract.address,
        ethers.utils.parseEther("300")
      );
      await OfficialMarketContract.connect(user2).buy(1);

      await BUSD.connect(user2).approve(
        OfficialMarketContract.address,
        ethers.utils.parseEther("200")
      );
      await OfficialMarketContract.connect(user2).buy(0);

      await BUSD.connect(user3).approve(
        OfficialMarketContract.address,
        ethers.utils.parseEther("300")
      );
      await OfficialMarketContract.connect(user3).buy(2);

      await BUSD.connect(user4).approve(
        OfficialMarketContract.address,
        ethers.utils.parseEther("600")
      );
      await OfficialMarketContract.connect(user4).buy(3);
    });

    it("Should not allow user to buy for less than the sale price", async () => {
      startingTime = startingTime - 100;
      // testing ERC721
      await OfficialMarketContract.connect(owner).createSaleFixedPrice(
        ArtistNFT.address,
        0,
        1,
        ethers.utils.parseEther("30"),
        startingTime
      );
      expect(await ArtistNFT.ownerOf(0)).to.equal(
        OfficialMarketContract.address
      );

      await BUSD.connect(user1).approve(
        OfficialMarketContract.address,
        ethers.utils.parseEther("29")
      );

      await expect(OfficialMarketContract.connect(user1).buy(0)).to.be.reverted;

      // testing ERC1155 (token IDs start from 1)
      await OfficialMarketContract.connect(owner).createSaleFixedPrice(
        ERC1155NFT.address,
        1,
        2,
        ethers.utils.parseEther("30"),
        startingTime
      );
      expect(
        await ERC1155NFT.balanceOf(OfficialMarketContract.address, 1)
      ).to.include({ _hex: "0x02", _isBigNumber: true });

      await BUSD.connect(user1).approve(
        OfficialMarketContract.address,
        ethers.utils.parseEther("29")
      );
      await expect(OfficialMarketContract.connect(user1).buy(1)).to.be.reverted;
    });

    it("Should distribute cuts correctly", async () => {
      // testing ERC1155 (token IDs start from 1)
      await OfficialMarketContract.connect(owner).createSaleFixedPrice(
        ERC1155NFT.address,
        1,
        3,
        ethers.utils.parseEther("30"),
        startingTime
      );
      expect(
        await ERC1155NFT.balanceOf(OfficialMarketContract.address, 1)
      ).to.include({ _hex: "0x03", _isBigNumber: true });

      await OfficialMarketContract.connect(owner).changeWalletAddresses(
        user7.address,
        user8.address,
        user9.address
      );

      await BUSD.connect(user1).approve(
        OfficialMarketContract.address,
        ethers.utils.parseEther("30")
      );
      await OfficialMarketContract.connect(user1).buy(0);
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
      await OfficialMarketContract.connect(owner).createSaleFixedPrice(
        ERC1155NFT.address,
        1,
        3,
        ethers.utils.parseEther("5000"),
        startingTime
      );
      expect(
        await ERC1155NFT.balanceOf(OfficialMarketContract.address, 1)
      ).to.include({ _hex: "0x03", _isBigNumber: true });

      await OfficialMarketContract.connect(owner).createSaleFixedPrice(
        ERC1155NFT.address,
        1,
        2,
        ethers.utils.parseEther("5000"),
        startingTime
      );
      expect(
        await ERC1155NFT.balanceOf(OfficialMarketContract.address, 1)
      ).to.include({ _hex: "0x05", _isBigNumber: true });

      await BUSD.connect(user1).approve(
        OfficialMarketContract.address,
        ethers.utils.parseEther("5000")
      );
      await OfficialMarketContract.connect(user1).buy(0);
      expect(await ERC1155NFT.balanceOf(user1.address, 1)).to.include({
        _hex: "0x03",
        _isBigNumber: true,
      });

      await BUSD.connect(user2).approve(
        OfficialMarketContract.address,
        ethers.utils.parseEther("5000")
      );
      await expect(OfficialMarketContract.connect(user2).buy(1)).to.emit(
        OfficialMarketContract,
        "SwapAndLiquify"
      );
      expect(await ERC1155NFT.balanceOf(user1.address, 1)).to.include({
        _hex: "0x03",
        _isBigNumber: true,
      });
    });
  });
});
