// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "../tokensUpgradeables/EcchiGameCurrencyUpgradeable.sol";
import "../tokensUpgradeables/ERC1155CollectibleUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

contract UpgradeNFTUpgradeable is ERC1155HolderUpgradeable, AccessControlUpgradeable {
    ERC1155CollectibleUpgradeable public nftContract;
    EcchiGameCurrencyUpgradeable public gameCurrency;

    // Must be sorted by rarity
    enum Class {
        Game,
        Silver,
        Gold
    }
    uint256 constant NUM_CLASSES = 3;
    uint256 constant INVERSE_BASIS_POINT = 10000;

    uint256 seed;

    mapping(uint256 => uint256[]) public classToTokenIds;
    // Probability in basis points (out of 10,000) of receiving each token. Must be in descending order
    mapping(uint256 => uint16[]) public classToProbabilities;

    // character mappings from game to silver NFTs
    mapping(uint256 => uint256) public gameToSilver;
    // character mappings from silver to gold NFTs
    mapping(uint256 => uint256) public silverToGold;

    /**
     * @dev Initializer
     */
    function initialize(
        ERC1155CollectibleUpgradeable _nftContract,
        EcchiGameCurrencyUpgradeable _gameCurrency,
        uint256[] memory _gameNFTs,
        uint256[] memory _silverNFTs,
        uint256[] memory _goldNFTs,
        uint16[] memory _nftProbabilities
    ) public initializer{
        __AccessControl_init();
        __ERC1155Holder_init();
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        nftContract = _nftContract;
        gameCurrency = _gameCurrency;

        setTokenIdsAndProbabilitiesForClass(
            Class.Game,
            _gameNFTs,
            _nftProbabilities
        );
        setTokenIdsAndProbabilitiesForClass(
            Class.Silver,
            _silverNFTs,
            _nftProbabilities
        );
        setTokenIdsAndProbabilitiesForClass(
            Class.Gold,
            _goldNFTs,
            _nftProbabilities
        );
    }

    /**
     * @dev Alternate way to add token ids to a class
     * Note: resets the full list for the class instead of adding each token id
     */
    function setTokenIdsAndProbabilitiesForClass(
        Class _class,
        uint256[] memory _tokenIds,
        uint16[] memory _probabilities
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(
            _tokenIds.length == _probabilities.length,
            "probabilities not equal to IDs"
        );

        uint256 classId = uint256(_class);
        classToTokenIds[classId] = _tokenIds;
        classToProbabilities[classId] = _probabilities;
    }

    function forgeGoldNFT() public {
        require(
            gameCurrency.balanceOf(msg.sender, 2) >= 3,
            "Not enough common shards"
        );
        require(
            gameCurrency.balanceOf(msg.sender, 3) >= 1,
            "Not enough powered shards"
        );
        require(
            classToTokenIds[2].length == classToProbabilities[2].length,
            "probabilities do not equal"
        );

        gameCurrency.burn(msg.sender, 2, 3);
        gameCurrency.burn(msg.sender, 3, 1);

        uint256 randomId = selectRandomClassId(2);

        nftContract.mint(msg.sender, randomId, 1, "");
    }

    function forgeSilverNFT() public {
        require(
            gameCurrency.balanceOf(msg.sender, 3) >= 3,
            "Not enough common shards"
        );
        require(
            gameCurrency.balanceOf(msg.sender, 4) >= 1,
            "Not enough powered shards"
        );

        gameCurrency.burn(msg.sender, 4, 3);
        gameCurrency.burn(msg.sender, 5, 1);

        uint256 randomId = selectRandomClassId(1);

        nftContract.mint(msg.sender, randomId, 1, "");
    }

    function upgradeGoldNFT(uint256 id) public {}

    function upgradeSilverNFT(uint256 id) public {}

    function selectRandomClassId(uint256 classId) internal returns (uint256) {
        uint16 value = uint16(_random() % INVERSE_BASIS_POINT);
        // Start at top class (length - 1)
        // skip common (0), we default to it
        for (uint256 i = classToProbabilities[classId].length - 1; i > 0; i--) {
            uint16 probability = uint16(classToProbabilities[classId][i]);
            if (value < probability) {
                return classToTokenIds[classId][i];
            } else {
                value = value - probability;
            }
        }
        return classToTokenIds[classId][0];
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
        override(ERC1155ReceiverUpgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
