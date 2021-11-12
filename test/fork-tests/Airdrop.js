const { ethers, upgrades } = require("hardhat");
const { expect } = require("chai");
let chai = require("chai");
let chaiAsPromised = require("chai-as-promised");
chai.use(chaiAsPromised);
const ABI = require("../../abi/PancakeSwap.json");

describe("Airdrops", () => {
  let Airdrop, ERC1155NFT, owner, EcchiCoin, BUSD, ArtistNFT;
  let startingTime, all;
  let user1, user2, user3, user4, user5, user6, user7, user8, user9;

  /**
   * @dev deploy the NFT contract and mint some URI's before each test
   */
  beforeEach(async () => {
    let Token2 = await ethers.getContractFactory("AirdropUpgradeable");
    let Token3 = await ethers.getContractFactory(
      "ERC1155CollectibleUpgradeable"
    );
    let Token4 = await ethers.getContractFactory("ArtistNFTUpgradeable");
    let Token5 = await ethers.getContractFactory("EcchiCoin");
    let Token6 = await ethers.getContractFactory("TestTokenUpgradeable");

    [owner, user1, user2, user3, user4, user5, user6, user7, user8, user9] =
      await ethers.getSigners();

    all = [user1, user2, user3, user4, user5, user6];

    //region Deploy contracts
    BUSD = await upgrades.deployProxy(Token6);
    EcchiCoin = await Token5.deploy(BUSD.address);
    ArtistNFT = await upgrades.deployProxy(Token4);
    Airdrop = await upgrades.deployProxy(Token2, [
      BUSD.address,
      EcchiCoin.address,
    ]);
    ERC1155NFT = await upgrades.deployProxy(Token3);
    //endregion

    // exclude airdrop contract from fee
    EcchiCoin.connect(owner).excludeFromFee(Airdrop.address);

    //region Set approval for airdrop
    await ArtistNFT.connect(owner).setApprovalForAll(Airdrop.address, true);
    await ERC1155NFT.connect(owner).setApprovalForAll(Airdrop.address, true);
    //endregion

    //region Mint the NFTs for testing
    await ArtistNFT.connect(owner).safeMint(owner.address, owner.address, 6, [
      "abc.com/1",
      "abc.com/2",
      "abc.com/3",
      "abc.com/4",
      "abc.com/5",
      "abc.com/6",
    ]);
    await ERC1155NFT.connect(owner).create(0, owner.address, 5, []);
    await ERC1155NFT.connect(owner).create(1, owner.address, 10, []);
    //endregion

    const blockNum = await ethers.provider.getBlockNumber();
    const block = await ethers.provider.getBlock(blockNum);
    startingTime = block.timestamp;
  });

  describe("Test ECCHI coin airdrop", () => {
    beforeEach(async () => {
      await EcchiCoin.connect(owner).approve(Airdrop.address, "50000000000");
      await Airdrop.connect(owner).airdropEcchi(
        [user1.address, user2.address],
        [user3.address, user4.address, user5.address],
        [user6.address, user7.address, user8.address],
        "50000000000"
      );
    });

    it("Should distribute ecchi to users", async () => {
      expect(await EcchiCoin.balanceOf(Airdrop.address)).to.be.equal(
        "50000000000"
      );
    });

    it("Should allow users to claim ecchi", async () => {
      await Airdrop.connect(user1).claimEcchi(user1.address);
      await Airdrop.connect(user2).claimEcchi(user2.address);
      await Airdrop.connect(user3).claimEcchi(user3.address);
    });

    it("Should not allow users to claim ecchi more than once", async () => {
      await Airdrop.connect(user1).claimEcchi(user1.address);
      await expect(
        Airdrop.connect(user1).claimEcchi(user1.address)
      ).to.be.revertedWith("Nothing to claim");

      await Airdrop.connect(user2).claimEcchi(user2.address);
      await expect(
        Airdrop.connect(user2).claimEcchi(user2.address)
      ).to.be.revertedWith("Nothing to claim");

      await Airdrop.connect(user3).claimEcchi(user3.address);
      await expect(
        Airdrop.connect(user3).claimEcchi(user3.address)
      ).to.be.revertedWith("Nothing to claim");
    });

    it("Should distribute ecchi cuts correctly", async () => {
      await Airdrop.connect(user1).claimEcchi(user1.address);
      await Airdrop.connect(user2).claimEcchi(user2.address);
      await Airdrop.connect(user3).claimEcchi(user3.address);
      await Airdrop.connect(user4).claimEcchi(user4.address);
      await Airdrop.connect(user5).claimEcchi(user5.address);
      await Airdrop.connect(user6).claimEcchi(user6.address);

      expect(await EcchiCoin.balanceOf(user1.address)).to.be.equal(
        await EcchiCoin.balanceOf(user2.address)
      );
      expect(await EcchiCoin.balanceOf(user1.address)).to.be.equal(
        (await EcchiCoin.balanceOf(user3.address)).div("2")
      );

      const balance6 = await EcchiCoin.balanceOf(user6.address);
      const balance1 = await EcchiCoin.balanceOf(user1.address);
      expect(balance1.sub(balance6.div("3"))).to.be.within(-1, 1);
    });
  });

  describe("Test BUSD airdrop", () => {
    beforeEach(async () => {
      await BUSD.connect(owner).approve(
        Airdrop.address,
        ethers.utils.parseEther("50")
      );
      await Airdrop.connect(owner).airdropBUSD(
        [user1.address, user2.address],
        [user3.address, user4.address, user5.address],
        [user6.address, user7.address, user8.address],
        ethers.utils.parseEther("50")
      );
    });

    it("Should distribute BUSD to users", async () => {
      expect(await BUSD.balanceOf(Airdrop.address)).to.be.equal(
        ethers.utils.parseEther("50")
      );
    });

    it("Should allow users to claim BUSD", async () => {
      await Airdrop.connect(user1).claimBUSD(user1.address);
      await Airdrop.connect(user2).claimBUSD(user2.address);
      await Airdrop.connect(user3).claimBUSD(user3.address);
    });

    it("Should not allow users to claim more than once", async () => {
      await Airdrop.connect(user1).claimBUSD(user1.address);
      await expect(
        Airdrop.connect(user1).claimBUSD(user1.address)
      ).to.be.revertedWith("Nothing to claim");

      await Airdrop.connect(user2).claimBUSD(user2.address);
      await expect(
        Airdrop.connect(user2).claimBUSD(user2.address)
      ).to.be.revertedWith("Nothing to claim");

      await Airdrop.connect(user3).claimBUSD(user3.address);
      await expect(
        Airdrop.connect(user3).claimBUSD(user3.address)
      ).to.be.revertedWith("Nothing to claim");
    });

    it("Should distribute BUSD cuts correctly", async () => {
      await Airdrop.connect(user1).claimBUSD(user1.address);
      await Airdrop.connect(user2).claimBUSD(user2.address);
      await Airdrop.connect(user3).claimBUSD(user3.address);
      await Airdrop.connect(user4).claimBUSD(user4.address);
      await Airdrop.connect(user5).claimBUSD(user5.address);
      await Airdrop.connect(user6).claimBUSD(user6.address);

      expect(await BUSD.balanceOf(user1.address)).to.be.equal(
        await BUSD.balanceOf(user2.address)
      );
      expect(await BUSD.balanceOf(user1.address)).to.be.equal(
        (await BUSD.balanceOf(user3.address)).div("2")
      );

      const balance6 = await BUSD.balanceOf(user6.address);
      const balance1 = await BUSD.balanceOf(user1.address);
      expect(balance1.sub(balance6.div("3"))).to.be.within(-1, 1);
    });
  });

  describe("Test ERC721 airdrop", () => {
    it("Should distribute ERC721 NFTs", async () => {
      await Airdrop.connect(owner).airdropERC721NFT(
        [
          ArtistNFT.address,
          ArtistNFT.address,
          ArtistNFT.address,
          ArtistNFT.address,
          ArtistNFT.address,
        ],
        [0, 1, 2, 3, 4],
        [
          user1.address,
          user2.address,
          user3.address,
          user4.address,
          user5.address,
        ]
      );
      expect(await ArtistNFT.ownerOf(0)).to.be.equal(Airdrop.address);
      expect(await ArtistNFT.ownerOf(1)).to.be.equal(Airdrop.address);
      expect(await ArtistNFT.ownerOf(2)).to.be.equal(Airdrop.address);
      expect(await ArtistNFT.ownerOf(3)).to.be.equal(Airdrop.address);
      expect(await ArtistNFT.ownerOf(4)).to.be.equal(Airdrop.address);
    });

    it("Should allow users to claim ERC721 NFTs", async () => {
      await Airdrop.connect(owner).airdropERC721NFT(
        [
          ArtistNFT.address,
          ArtistNFT.address,
          ArtistNFT.address,
          ArtistNFT.address,
          ArtistNFT.address,
        ],
        [0, 1, 2, 3, 4],
        [
          user1.address,
          user2.address,
          user3.address,
          user4.address,
          user5.address,
        ]
      );
      await Airdrop.connect(user1).claimERC721(user1.address);
      await Airdrop.connect(user2).claimERC721(user2.address);
      await Airdrop.connect(user3).claimERC721(user3.address);
      await Airdrop.connect(user4).claimERC721(user4.address);
      await Airdrop.connect(user5).claimERC721(user5.address);

      expect(await ArtistNFT.ownerOf(0)).to.be.equal(user1.address);
      expect(await ArtistNFT.ownerOf(1)).to.be.equal(user2.address);
      expect(await ArtistNFT.ownerOf(2)).to.be.equal(user3.address);
      expect(await ArtistNFT.ownerOf(3)).to.be.equal(user4.address);
      expect(await ArtistNFT.ownerOf(4)).to.be.equal(user5.address);
    });

    it("Should allow one user to have multiple airdropped NFTs", async () => {
      await Airdrop.connect(owner).airdropERC721NFT(
        [
          ArtistNFT.address,
          ArtistNFT.address,
          ArtistNFT.address,
          ArtistNFT.address,
          ArtistNFT.address,
        ],
        [0, 1, 2, 3, 4],
        [
          user1.address,
          user2.address,
          user2.address,
          user3.address,
          user3.address,
        ]
      );

      await Airdrop.connect(user1).claimERC721(user1.address);
      await Airdrop.connect(user2).claimERC721(user2.address);
      await Airdrop.connect(user3).claimERC721(user3.address);

      expect(await ArtistNFT.ownerOf(0)).to.be.equal(user1.address);
      expect(await ArtistNFT.ownerOf(1)).to.be.equal(user2.address);
      expect(await ArtistNFT.ownerOf(2)).to.be.equal(user2.address);
      expect(await ArtistNFT.ownerOf(3)).to.be.equal(user3.address);
      expect(await ArtistNFT.ownerOf(4)).to.be.equal(user3.address);
    });

    it("Should not allow one user to claim multiple times", async () => {
      await Airdrop.connect(owner).airdropERC721NFT(
        [
          ArtistNFT.address,
          ArtistNFT.address,
          ArtistNFT.address,
          ArtistNFT.address,
          ArtistNFT.address,
        ],
        [0, 1, 2, 3, 4],
        [
          user1.address,
          user2.address,
          user2.address,
          user3.address,
          user3.address,
        ]
      );

      await Airdrop.connect(user1).claimERC721(user1.address);
      await Airdrop.connect(user2).claimERC721(user2.address);
      await expect(
        Airdrop.connect(user2).claimERC721(user2.address)
      ).to.be.revertedWith("Nothing to claim");
      await Airdrop.connect(user3).claimERC721(user3.address);
      await expect(
        Airdrop.connect(user2).claimERC721(user3.address)
      ).to.be.revertedWith("Nothing to claim");

      expect(await ArtistNFT.ownerOf(0)).to.be.equal(user1.address);
      expect(await ArtistNFT.ownerOf(1)).to.be.equal(user2.address);
      expect(await ArtistNFT.ownerOf(2)).to.be.equal(user2.address);
      expect(await ArtistNFT.ownerOf(3)).to.be.equal(user3.address);
      expect(await ArtistNFT.ownerOf(4)).to.be.equal(user3.address);
    });

    it("Should allow users to claim previous airdrops", async () => {
      await Airdrop.connect(owner).airdropERC721NFT(
        [ArtistNFT.address, ArtistNFT.address, ArtistNFT.address],
        [0, 1, 2],
        [user1.address, user2.address, user3.address]
      );

      await Airdrop.connect(user1).claimERC721(user1.address);
      await Airdrop.connect(user2).claimERC721(user2.address);

      expect(await ArtistNFT.ownerOf(0)).to.be.equal(user1.address);
      expect(await ArtistNFT.ownerOf(1)).to.be.equal(user2.address);
      expect(await ArtistNFT.ownerOf(2)).to.be.equal(Airdrop.address);

      await Airdrop.connect(owner).airdropERC721NFT(
        [ArtistNFT.address, ArtistNFT.address, ArtistNFT.address],
        [3, 4, 5],
        [user1.address, user2.address, user3.address]
      );

      await Airdrop.connect(user1).claimERC721(user1.address);
      await Airdrop.connect(user2).claimERC721(user2.address);
      await Airdrop.connect(user3).claimERC721(user3.address);

      expect(await ArtistNFT.ownerOf(0)).to.be.equal(user1.address);
      expect(await ArtistNFT.ownerOf(1)).to.be.equal(user2.address);
      expect(await ArtistNFT.ownerOf(2)).to.be.equal(user3.address);
      expect(await ArtistNFT.ownerOf(3)).to.be.equal(user1.address);
      expect(await ArtistNFT.ownerOf(4)).to.be.equal(user2.address);
      expect(await ArtistNFT.ownerOf(5)).to.be.equal(user3.address);
    });
  });

  describe("Test ERC1155 airdrop", () => {
    it("Should distribute ERC1155 NFTs", async () => {
      await Airdrop.connect(owner).airdropERC1155NFT(
        [
          ERC1155NFT.address,
          ERC1155NFT.address,
          ERC1155NFT.address,
          ERC1155NFT.address,
          ERC1155NFT.address,
        ],
        [1, 1, 1, 100001, 100001],
        [1, 1, 3, 5, 5],
        [
          user1.address,
          user2.address,
          user3.address,
          user4.address,
          user5.address,
        ]
      );
      expect(await ERC1155NFT.balanceOf(Airdrop.address, 1)).to.be.equal(
        ethers.BigNumber.from("5")
      );
      expect(await ERC1155NFT.balanceOf(Airdrop.address, 100001)).to.be.equal(
        ethers.BigNumber.from("10")
      );
    });

    it("Should allow users to claim ERC1155 NFTs", async () => {
      await Airdrop.connect(owner).airdropERC1155NFT(
        [
          ERC1155NFT.address,
          ERC1155NFT.address,
          ERC1155NFT.address,
          ERC1155NFT.address,
          ERC1155NFT.address,
        ],
        [1, 1, 1, 100001, 100001],
        [1, 1, 3, 5, 5],
        [
          user1.address,
          user2.address,
          user3.address,
          user4.address,
          user5.address,
        ]
      );
      await Airdrop.connect(user1).claimERC1155(user1.address);
      await Airdrop.connect(user2).claimERC1155(user2.address);
      await Airdrop.connect(user3).claimERC1155(user3.address);
      await Airdrop.connect(user4).claimERC1155(user4.address);
      await Airdrop.connect(user5).claimERC1155(user5.address);

      expect(await ERC1155NFT.balanceOf(user1.address, 1)).to.be.equal(
        ethers.BigNumber.from("1")
      );
      expect(await ERC1155NFT.balanceOf(user2.address, 1)).to.be.equal(
        ethers.BigNumber.from("1")
      );
      expect(await ERC1155NFT.balanceOf(user3.address, 1)).to.be.equal(
        ethers.BigNumber.from("3")
      );
      expect(await ERC1155NFT.balanceOf(user4.address, 100001)).to.be.equal(
        ethers.BigNumber.from("5")
      );
      expect(await ERC1155NFT.balanceOf(user5.address, 100001)).to.be.equal(
        ethers.BigNumber.from("5")
      );
    });

    it("Should allow one user to have multiple airdropped NFTs", async () => {
      await Airdrop.connect(owner).airdropERC1155NFT(
        [
          ERC1155NFT.address,
          ERC1155NFT.address,
          ERC1155NFT.address,
          ERC1155NFT.address,
          ERC1155NFT.address,
        ],
        [1, 1, 1, 100001, 100001],
        [1, 1, 3, 5, 5],
        [
          user1.address,
          user2.address,
          user2.address,
          user2.address,
          user3.address,
        ]
      );

      await Airdrop.connect(user1).claimERC1155(user1.address);
      await Airdrop.connect(user2).claimERC1155(user2.address);
      await Airdrop.connect(user3).claimERC1155(user3.address);

      expect(await ERC1155NFT.balanceOf(user1.address, 1)).to.be.equal(
        ethers.BigNumber.from("1")
      );
      expect(await ERC1155NFT.balanceOf(user2.address, 1)).to.be.equal(
        ethers.BigNumber.from("4")
      );
      expect(await ERC1155NFT.balanceOf(user3.address, 100001)).to.be.equal(
        ethers.BigNumber.from("5")
      );
      expect(await ERC1155NFT.balanceOf(user3.address, 100001)).to.be.equal(
        ethers.BigNumber.from("5")
      );
    });

    it("Should not allow one user to claim multiple times", async () => {
      await Airdrop.connect(owner).airdropERC1155NFT(
        [
          ERC1155NFT.address,
          ERC1155NFT.address,
          ERC1155NFT.address,
          ERC1155NFT.address,
          ERC1155NFT.address,
        ],
        [1, 1, 1, 100001, 100001],
        [1, 1, 3, 5, 5],
        [
          user1.address,
          user2.address,
          user2.address,
          user3.address,
          user3.address,
        ]
      );

      await Airdrop.connect(user1).claimERC1155(user1.address);
      await Airdrop.connect(user2).claimERC1155(user2.address);
      await expect(
        Airdrop.connect(user2).claimERC1155(user2.address)
      ).to.be.revertedWith("Nothing to claim");
      await Airdrop.connect(user3).claimERC1155(user3.address);
      await expect(
        Airdrop.connect(user3).claimERC1155(user3.address)
      ).to.be.revertedWith("Nothing to claim");

      expect(await ERC1155NFT.balanceOf(user1.address, 1)).to.be.equal(
        ethers.BigNumber.from("1")
      );
      expect(await ERC1155NFT.balanceOf(user2.address, 1)).to.be.equal(
        ethers.BigNumber.from("4")
      );
      expect(await ERC1155NFT.balanceOf(user3.address, 100001)).to.be.equal(
        ethers.BigNumber.from("10")
      );
    });

    it("Should allow users to claim previous airdrops", async () => {
      await Airdrop.connect(owner).airdropERC1155NFT(
        [ERC1155NFT.address, ERC1155NFT.address, ERC1155NFT.address],
        [1, 1, 1],
        [1, 1, 2],
        [user1.address, user2.address, user3.address]
      );

      await Airdrop.connect(user1).claimERC1155(user1.address);
      await Airdrop.connect(user2).claimERC1155(user2.address);

      expect(await ERC1155NFT.balanceOf(user1.address, 1)).to.be.equal(
        ethers.BigNumber.from("1")
      );
      expect(await ERC1155NFT.balanceOf(user2.address, 1)).to.be.equal(
        ethers.BigNumber.from("1")
      );
      expect(await ERC1155NFT.balanceOf(Airdrop.address, 1)).to.be.equal(
        ethers.BigNumber.from("2")
      );

      await Airdrop.connect(owner).airdropERC1155NFT(
        [ERC1155NFT.address, ERC1155NFT.address, ERC1155NFT.address],
        [1, 100001, 100001],
        [1, 5, 5],
        [user1.address, user2.address, user3.address]
      );

      await Airdrop.connect(user1).claimERC1155(user1.address);
      await Airdrop.connect(user2).claimERC1155(user2.address);
      await Airdrop.connect(user3).claimERC1155(user3.address);
      await expect(
        Airdrop.connect(user3).claimERC1155(user3.address)
      ).to.be.revertedWith("Nothing to claim");

      expect(await ERC1155NFT.balanceOf(user1.address, 1)).to.be.equal(
        ethers.BigNumber.from("2")
      );
      expect(await ERC1155NFT.balanceOf(user2.address, 1)).to.be.equal(
        ethers.BigNumber.from("1")
      );
      expect(await ERC1155NFT.balanceOf(user2.address, 100001)).to.be.equal(
        ethers.BigNumber.from("5")
      );
      expect(await ERC1155NFT.balanceOf(user3.address, 1)).to.be.equal(
        ethers.BigNumber.from("2")
      );
      expect(await ERC1155NFT.balanceOf(user3.address, 100001)).to.be.equal(
        ethers.BigNumber.from("5")
      );
    });
  });
});
