const { expect } = require("chai");
const { ethers } = require("hardhat");
let chai = require("chai");
let chaiAsPromised = require("chai-as-promised");
chai.use(chaiAsPromised);

/**
 * DRAFT
 */
describe("Upgrade tests", () => {
  let CurrencyContract, ERC1155, UpgradeHandler, all, owner;
  let user1, user2, user3, user4, user5, user6, user7, user8, user9;

  /**
   * @dev deploy the NFT contract and mint some URI's before each test
   */
  beforeEach(async () => {
    let Token1 = await ethers.getContractFactory("EcchiGameCurrency");
    let Token2 = await ethers.getContractFactory("ERC1155Collectible");
    let Token3 = await ethers.getContractFactory("UpgradeHandler");

    [owner, user1, user2, user3, user4, user5, user6, user7, user8, user9] =
      await ethers.getSigners();

    all = [user1, user2, user3, user4, user5, user6];

    CurrencyContract = await Token1.deploy();
    ERC1155 = await Token2.deploy();
    UpgradeHandler = await Token3.deploy(
      ERC1155.address,
      CurrencyContract.address,
      654674
    );

    // approve UpgradeHandler contract
    await ERC1155.connect(owner).setApprovalForAll(
      UpgradeHandler.address,
      true
    );

    // mint 9 silver NFTs
    for (let i = 0; i < 9; i++) {
      await ERC1155.connect(owner).create(0, owner.address, 10, []);
    }

    // mint 9 silver NFTs
    for (let i = 0; i < 9; i++) {
      await ERC1155.connect(owner).create(1, owner.address, 10, []);
    }

    // mint 9 gold NFTs
    for (let i = 0; i < 9; i++) {
      await ERC1155.connect(owner).create(2, owner.address, 10, []);
    }

    // distribute shards
    await CurrencyContract.connect(owner).mintBatch(
      user1.address,
      [0, 1, 2, 3, 4],
      [120, 3, 1, 3, 1],
      []
    );
  });

  /**
   * @dev testing initialization
   */
  describe("Test adding to pools", () => {
    it("Should add new IDs to the silver pool", async () => {
      await UpgradeHandler.connect(owner).addNftToPool(100001, 3);

      let res = await UpgradeHandler.getSilverPool();
      expect(res[0]).to.be.equal(ethers.BigNumber.from("100001"));

      await UpgradeHandler.connect(owner).addNftToPool(100004, 3);
      res = await UpgradeHandler.getSilverPool();
      expect(res.length).to.be.equal(2);
      expect(res[1]).to.be.equal(ethers.BigNumber.from("100004"));
    });

    it("Should add new IDs to the gold pool", async () => {
      await UpgradeHandler.connect(owner).addNftToPool(200001, 3);

      let res = await UpgradeHandler.getGoldPool();
      expect(res[0]).to.be.equal(ethers.BigNumber.from("200001"));

      await UpgradeHandler.connect(owner).addNftToPool(200004, 3);
      res = await UpgradeHandler.getGoldPool();
      expect(res.length).to.be.equal(2);
      expect(res[1]).to.be.equal(ethers.BigNumber.from("200004"));
    });

    it("Should not add invalid IDs into the pool", async () => {
      await expect(
        UpgradeHandler.connect(owner).addNftToPool(1, 3)
      ).to.be.revertedWith("Can only add silver and gold NFTs");
    });
  });

  describe("Test Forging", () => {
    beforeEach(async () => {
      for (let i = 100001; i < 100010; i++) {
        await UpgradeHandler.connect(owner).addNftToPool(i, 1);
      }

      for (let i = 200001; i < 200010; i++) {
        await UpgradeHandler.connect(owner).addNftToPool(i, 1);
      }
    });

    it("Should forge random silver NFTs", async () => {
      // approve UpgradeHandler
      await CurrencyContract.connect(user1).setApprovalForAll(
        UpgradeHandler.address,
        true
      );

      let res = await UpgradeHandler.connect(user1).forgeSilverNFT();
      let resWait = await res.wait();
      let token = resWait.events[3].args["_tokenId"];

      expect(
        await ERC1155.balanceOf(user1.address, token.toString())
      ).to.be.equal("1");
    });

    it("Should forge random gold NFTs", async () => {
      // approve UpgradeHandler
      await CurrencyContract.connect(user1).setApprovalForAll(
        UpgradeHandler.address,
        true
      );

      let res = await UpgradeHandler.connect(user1).forgeGoldNFT();
      let resWait = await res.wait();
      let token = resWait.events[3].args["_tokenId"];

      expect(
        await ERC1155.balanceOf(user1.address, token.toString())
      ).to.be.equal("1");
    });

    it("Should not forge when no NFTs are available", async () => {
      // give enough gold shards
      await CurrencyContract.connect(owner).mintBatch(
        user1.address,
        [3, 4],
        [24, 8],
        []
      );

      // approve UpgradeHandler
      await CurrencyContract.connect(user1).setApprovalForAll(
        UpgradeHandler.address,
        true
      );

      let res = await UpgradeHandler.connect(user1).forgeGoldNFT();
      let resWait = await res.wait();
      let token = resWait.events[3].args["_tokenId"];

      for (let i = 0; i < 8; i++) {
        await UpgradeHandler.connect(user1).forgeGoldNFT();
      }

      await expect(
        UpgradeHandler.connect(user1).forgeGoldNFT()
      ).to.be.revertedWith("No gold NFTs available");

      expect(
        await ERC1155.balanceOf(user1.address, token.toString())
      ).to.be.equal("1");
    });
  });

  describe("Test Upgrading", () => {
    beforeEach(async () => {
      for (let i = 100001; i < 100010; i++) {
        await UpgradeHandler.connect(owner).addNftToPool(i, 1);
      }

      for (let i = 200001; i < 200010; i++) {
        await UpgradeHandler.connect(owner).addNftToPool(i, 1);
      }
    });

    it("Should allow upgrading NFT from game to Silver", async () => {
      // approve UpgradeHandler contract
      await ERC1155.connect(user1).setApprovalForAll(
        UpgradeHandler.address,
        true
      );
      // approve UpgradeHandler contract
      await CurrencyContract.connect(user1).setApprovalForAll(
        UpgradeHandler.address,
        true
      );

      await ERC1155.connect(owner).safeTransferFrom(
        owner.address,
        user1.address,
        1,
        1,
        []
      );

      await UpgradeHandler.connect(user1).upgradeGameToSilver(1);
      expect(await ERC1155.balanceOf(user1.address, 100001)).to.be.equal("1");
    });

    it("Should allow upgrading NFT from silver to Gold", async () => {
      // approve UpgradeHandler contract
      await ERC1155.connect(user1).setApprovalForAll(
        UpgradeHandler.address,
        true
      );
      // approve UpgradeHandler contract
      await CurrencyContract.connect(user1).setApprovalForAll(
        UpgradeHandler.address,
        true
      );

      await ERC1155.connect(owner).safeTransferFrom(
        owner.address,
        user1.address,
        100001,
        1,
        []
      );

      await UpgradeHandler.connect(user1).upgradeSilverToGold(100001);
      expect(await ERC1155.balanceOf(user1.address, 200001)).to.be.equal("1");
    });

    it("Should not allow upgrading if NFT is not available", async () => {
      // approve UpgradeHandler contract
      await ERC1155.connect(user1).setApprovalForAll(
        UpgradeHandler.address,
        true
      );
      // approve UpgradeHandler contract
      await CurrencyContract.connect(user1).setApprovalForAll(
        UpgradeHandler.address,
        true
      );

      await ERC1155.connect(owner).safeTransferFrom(
        owner.address,
        user1.address,
        100001,
        1,
        []
      );

      await UpgradeHandler.connect(user1).upgradeSilverToGold(100001);
      expect(await ERC1155.balanceOf(user1.address, 200001)).to.be.equal("1");
      await expect(
        UpgradeHandler.connect(user1).upgradeSilverToGold(100001)
      ).to.be.revertedWith("No more gold versions of this NFT");
    });
  });
});
