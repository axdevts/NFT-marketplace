// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "../tokens/EcchiGameCurrency.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "../tokens/IERC1155Collectible.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "../tokens/IEcchiGameCurrency.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";

/**
 * @dev Do not send NFTs to this contract directly. In order to add NFTs to the pool,
 *      call the addNftToPool() function
 */
contract UpgradeHandler is ERC1155Holder, AccessControl, IEcchiGameCurrency {
    // Add the library methods
    using EnumerableSet for EnumerableSet.UintSet;

    // Must be sorted by rarity
    enum Class {
        Game,
        Silver,
        Gold
    }

    IERC1155Collectible public immutable nftContract;
    EcchiGameCurrency public immutable gameCurrency;

    // Enumerable set for silver and gold NFTs
    EnumerableSet.UintSet private silverSet;
    EnumerableSet.UintSet private goldSet;

    uint256 private seed;

    event silverForged(uint256 _tokenId, address _to);
    event goldForged(uint256 _tokenId, address _to);

    constructor(
        IERC1155Collectible _nftContract,
        EcchiGameCurrency _gameCurrency,
        uint256 _seed
    ) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        seed = _seed;
        nftContract = _nftContract;
        gameCurrency = _gameCurrency;
    }

    function getSilverPool() public view returns (uint256[] memory) {
        return silverSet.values();
    }

    function getGoldPool() public view returns (uint256[] memory) {
        return goldSet.values();
    }

    function addNftToPool(uint256 _tokenId, uint256 _amount)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(
            _tokenId < 300000 && _tokenId > 100000,
            "Can only add silver and gold NFTs"
        );
        require(_amount > 0, "Have to add at least 1 NFT");
        bool isSilver = _tokenId < 200000;

        if (isSilver && !silverSet.contains(_tokenId)) {
            silverSet.add(_tokenId);
        } else if (!isSilver && !goldSet.contains(_tokenId)) {
            goldSet.add(_tokenId);
        }

        transfer(msg.sender, address(this), _tokenId, _amount);
    }

    function forgeSilverNFT() public {
        require(silverSet.length() > 0, "No silver NFTs available");
        require(
            gameCurrency.balanceOf(
                msg.sender,
                uint256(GameCurrency.CommonSilverShard)
            ) >= 3,
            "Not enough common shards"
        );
        require(
            gameCurrency.balanceOf(
                msg.sender,
                uint256(GameCurrency.PoweredSilverShard)
            ) >= 1,
            "Not enough powered shards"
        );

        uint256 randomId = selectRandomClassId(Class.Silver);
        uint256 randomToken = silverSet.at(randomId);

        gameCurrency.burn(
            msg.sender,
            uint256(GameCurrency.CommonSilverShard),
            3
        );
        gameCurrency.burn(
            msg.sender,
            uint256(GameCurrency.PoweredSilverShard),
            1
        );

        transfer(address(this), msg.sender, randomToken, 1);

        silverForged(randomToken, msg.sender);
    }

    function forgeGoldNFT() public {
        require(goldSet.length() > 0, "No gold NFTs available");
        require(
            gameCurrency.balanceOf(
                msg.sender,
                uint256(GameCurrency.CommonGoldShard)
            ) >= 3,
            "Not enough common shards"
        );
        require(
            gameCurrency.balanceOf(
                msg.sender,
                uint256(GameCurrency.PoweredGoldShard)
            ) >= 1,
            "Not enough powered shards"
        );

        uint256 randomId = selectRandomClassId(Class.Gold);
        uint256 randomToken = goldSet.at(randomId);

        gameCurrency.burn(msg.sender, uint256(GameCurrency.CommonGoldShard), 3);
        gameCurrency.burn(
            msg.sender,
            uint256(GameCurrency.PoweredGoldShard),
            1
        );

        transfer(address(this), msg.sender, randomToken, 1);

        goldForged(randomToken, msg.sender);
    }

    function upgradeGameToSilver(uint256 id) public {
        uint256 upgradeTokenId = id + 100000;
        require(upgradeTokenId != 0, "Invalid Id");

        require(
            nftContract.balanceOf(address(this), upgradeTokenId) > 0,
            "No more silver versions of this NFT"
        );
        require(
            gameCurrency.balanceOf(
                msg.sender,
                uint256(GameCurrency.GoldCoin)
            ) >= 20,
            "Not enough gold coins"
        );

        // burn the game NFT
        nftContract.burn(msg.sender, id, 1);
        // burn the gold coins
        gameCurrency.burn(msg.sender, uint256(GameCurrency.GoldCoin), 20);
        // transfer the upgraded NFT
        transfer(address(this), msg.sender, upgradeTokenId, 1);
    }

    function upgradeSilverToGold(uint256 id) public {
        uint256 upgradeTokenId = id + 100000;
        require(upgradeTokenId != 0, "Invalid Id");

        require(
            nftContract.balanceOf(address(this), upgradeTokenId) > 0,
            "No more gold versions of this NFT"
        );
        require(
            gameCurrency.balanceOf(
                msg.sender,
                uint256(GameCurrency.GoldCoin)
            ) >= 100,
            "Not enough gold coins"
        );

        // burn the silver NFT
        nftContract.burn(msg.sender, id, 1);
        // burn the gold coins
        gameCurrency.burn(msg.sender, uint256(GameCurrency.GoldCoin), 100);
        // transfer the upgraded NFT
        transfer(address(this), msg.sender, upgradeTokenId, 1);
    }

    function selectRandomClassId(Class _class) internal returns (uint256) {
        uint256 classLength = _class == Class.Silver
            ? silverSet.length()
            : goldSet.length();
        uint16 value = uint16(_random() % classLength);
        return value;
    }

    function transfer(
        address _from,
        address _to,
        uint256 _tokenId,
        uint256 _amount
    ) internal {
        // remove the _tokenId from the
        if (_from == address(this)) {
            uint256 balance = nftContract.balanceOf(address(this), _tokenId);
            if (balance == _amount) {
                if (goldSet.contains(_tokenId)) goldSet.remove(_tokenId);
                if (silverSet.contains(_tokenId)) silverSet.remove(_tokenId);
            }
        }

        nftContract.safeTransferFrom(_from, _to, _tokenId, _amount, "");
    }

    /**
     * @dev Pseudo-random number generator
     * NOTE: to improve randomness, generate it with an oracle
     */
    function _random() internal returns (uint256) {
        uint256 randomNumber = uint256(
            keccak256(
                abi.encodePacked(blockhash(block.number - 1), msg.sender, seed)
            )
        );
        seed = randomNumber;
        return randomNumber;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC1155Receiver, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
