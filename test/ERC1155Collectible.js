const { ethers, upgrades } = require("hardhat");
const { expect } = require("chai");
let chai = require("chai");
let chaiAsPromised = require("chai-as-promised");
chai.use(chaiAsPromised);

describe("ERC1155Collectible tests", () => {
  let ERC1155NFT, owner;
  let user1, user2, user3, user4, user5, user6, user7, user8, user9;

  beforeEach(async () => {
    let Token1 = await ethers.getContractFactory("ERC1155Collectible");

    [owner, user1, user2, user3, user4, user5, user6, user7, user8, user9] =
      await ethers.getSigners();

    ERC1155NFT = await Token1.deploy();
  });

  describe("Test minting", () => {
    it("Should mint all NFT types", async () => {
      await ERC1155NFT.connect(owner).create(0, owner.address, 10, []);
      expect(await ERC1155NFT.balanceOf(owner.address, 1)).to.be.equal("10");

      await ERC1155NFT.connect(owner).create(1, owner.address, 10, []);
      expect(await ERC1155NFT.balanceOf(owner.address, 100001)).to.be.equal(
        "10"
      );

      await ERC1155NFT.connect(owner).create(2, owner.address, 10, []);
      expect(await ERC1155NFT.balanceOf(owner.address, 200001)).to.be.equal(
        "10"
      );

      await ERC1155NFT.connect(owner).create(3, owner.address, 10, []);
      expect(await ERC1155NFT.balanceOf(owner.address, 300001)).to.be.equal(
        "10"
      );

      await ERC1155NFT.connect(owner).create(4, owner.address, 10, []);
      expect(await ERC1155NFT.balanceOf(owner.address, 400001)).to.be.equal(
        "10"
      );
    });

    it("Should not mint NFT types that are not allowed", async () => {
      await expect(ERC1155NFT.connect(owner).create(5, owner.address, 10, []))
        .to.be.reverted;
    });

    it("Should allow public minting of Game NFTs", async () => {
      await ERC1155NFT.connect(owner).create(0, owner.address, 10, []);
      expect(await ERC1155NFT.balanceOf(owner.address, 1)).to.be.equal("10");

      await ERC1155NFT.connect(user1).publicMint(user1.address, 1, 100, []);
      expect(await ERC1155NFT.balanceOf(user1.address, 1)).to.be.equal("100");
    });

    it("Should not allow public minting of silver NFTs", async () => {
      await ERC1155NFT.connect(owner).create(1, owner.address, 10, []);
      expect(await ERC1155NFT.balanceOf(owner.address, 100001)).to.be.equal(
        "10"
      );

      await expect(
        ERC1155NFT.connect(user1).publicMint(user1.address, 100001, 100, [])
      ).to.be.revertedWith("Public minting not allowed");
    });

    it("Should allow creator to mint more silver NFTs", async () => {
      await ERC1155NFT.connect(owner).create(1, owner.address, 10, []);
      expect(await ERC1155NFT.balanceOf(owner.address, 100001)).to.be.equal(
        "10"
      );

      await ERC1155NFT.connect(owner).mint(owner.address, 100001, 100, []);
      expect(await ERC1155NFT.balanceOf(owner.address, 100001)).to.be.equal(
        "110"
      );
    });
  });
});
