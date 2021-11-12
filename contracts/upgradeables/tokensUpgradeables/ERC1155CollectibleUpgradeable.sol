// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";

contract ERC1155CollectibleUpgradeable is
    ERC1155Upgradeable,
    AccessControlUpgradeable,
    ERC1155BurnableUpgradeable
{
    // role for creating new characters/NFTs with different IDs
    bytes32 public constant CREATOR_ROLE = keccak256("CREATOR_ROLE");
    // for utility contracts to allow minting
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    // max token ID limits for each token type
    // Game NFTs will have token IDs 1 - 99,999
    // Silver NFTs will have token IDs 100,001 - 199,999
    // Gold NFTs will have token IDs 200,001 - 299,999
    // Platinum NFTs will have token IDs 300,001 - 399,999
    // Legendary NFTs will have token IDs 400,001 - 499,999
    uint256 public constant GAME_LIMIT = 99999;
    uint256 public constant SILVER_LIMIT = 199999;
    uint256 public constant GOLD_LIMIT = 299999;
    uint256 public constant PLATINUM_LIMIT = 399999;
    uint256 public constant LEGENDARY_LIMIT = 499999;

    string public baseUri;

    enum CollectibleType {
        GAME,
        SILVER,
        GOLD,
        PLATINUM,
        LEGENDARY
    }

    uint256 public _gameTokenId;
    uint256 public _silverTokenId;
    uint256 public _goldTokenId;
    uint256 public _platinumTokenId;
    uint256 public _legendaryTokenId;

    mapping(uint256 => address) public creators;
    // total supply of every token id
    mapping(uint256 => uint256) public tokenSupply;
    // token IDs allowed to be minted publicly
    mapping(uint256 => bool) publicMintingAllowed;

    event ERC1155NFTCreated(
        uint256 tokenID,
        uint256 amountMinted,
        address contractAddress,
        string tokenMetadataUri,
        address creator,
        bool publicAllowed
    );

    event ERC1155NFTMinted(
        uint256 tokenID,
        uint256 amountMinted,
        address contractAddress,
        string tokenMetadataUri,
        address creator
    );

    /**
     * @dev Require msg.sender to be the creator of the token id
     */
    modifier creatorOrApprovedOnly(uint256 _id) {
        require(
            creators[_id] == msg.sender || hasRole(MINTER_ROLE, msg.sender),
            "ONLY_CREATOR_OR_APPROVED"
        );
        _;
    }

    modifier creatorOnly(uint256 _id) {
        require(creators[_id] == msg.sender, "ONLY_CREATOR_ALLOWED");
        _;
    }

    /**
     * @dev Require msg.sender to own more than 0 of the token id
     */
    modifier ownersOnly(uint256 _id) {
        require(balanceOf(msg.sender, _id) > 0, "ONLY_OWNERS_ALLOWED");
        _;
    }

    /**
     * @dev Initializer
     */
    function initialize() public initializer {
        __ERC1155_init("");
        __ERC1155Burnable_init();
        __AccessControl_init();
        _gameTokenId = 0;
        _silverTokenId = 100000;
        _goldTokenId = 200000;
        _platinumTokenId = 300000;
        _legendaryTokenId = 400000;
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(CREATOR_ROLE, msg.sender);
        baseUri = "https://ecchi-coin-test.s3.eu-central-1.amazonaws.com/metadata/";
    }

    function uri(uint256 _id)
        public
        view
        override(ERC1155Upgradeable)
        returns (string memory)
    {
        require(_exists(_id), "NONEXISTENT_TOKEN");
        return
            string(abi.encodePacked(baseUri, StringsUpgradeable.toString(_id)));
    }

    /**
     * @dev Returns the total quantity for a token ID
     * @param _id uint256 ID of the token to query
     * @return amount of token in existence
     */
    function totalSupply(uint256 _id) public view returns (uint256) {
        return tokenSupply[_id];
    }

    function setURI(string memory newUri) public onlyRole(DEFAULT_ADMIN_ROLE) {
        baseUri = newUri;
    }

    /**
     * @dev Creates a new token type and assigns _initialSupply to an address
     * @param _type type of the token to create (game, silver, gold, platinum or legendary)
     * @param _initialOwner address of the first owner of the token
     * @param _initialSupply amount to supply the first owner
     * @param _data Data to pass if receiver is contract
     * @return The newly created token ID
     */
    function create(
        CollectibleType _type,
        address _initialOwner,
        uint256 _initialSupply,
        bytes calldata _data
    ) public onlyRole(CREATOR_ROLE) returns (uint256) {
        uint256 _id = _getNextTokenID(_type);
        _incrementTokenTypeId(_type);
        creators[_id] = msg.sender;

        //Emit event
        emit ERC1155NFTCreated(
            _id,
            _initialSupply,
            address(this),
            uri(_id),
            msg.sender,
            _type == CollectibleType.GAME
        );

        mint(_initialOwner, _id, _initialSupply, _data);
        // only GameNFTs can be minted by anyone
        publicMintingAllowed[_id] = _type == CollectibleType.GAME;
        tokenSupply[_id] = _initialSupply;

        emit URI(uri(_id), _id);

        return _id;
    }

    /**
     * @dev Creates a batch of new token types and assigns _initialSupply to addresses
     * @param _type list of types of the token to create (game, silver, gold, platinum or legendary)
     * @param _initialOwner list of addresses of the first owner of the token
     * @param _initialSupply list of amount to supply the first owner
     * @param _data Data to pass if receiver is contract
     */
    function createBatch(
        CollectibleType[] memory _type,
        address[] memory _initialOwner,
        uint256[] memory _initialSupply,
        bytes calldata _data
    ) external onlyRole(CREATOR_ROLE) {
        require(
            _type.length == _initialOwner.length &&
                _type.length == _initialSupply.length,
            "Array length mismatch"
        );

        for (uint256 i = 0; i < _type.length; i++) {
            create(_type[i], _initialOwner[i], _initialSupply[i], _data);
        }
    }

    /**
     * @dev Allows anyone to mint some amount of tokens to an address (for game NFTs)
     * @param account      Address of the future owner of the token
     * @param id           Token ID to mint
     * @param amount       Amount of tokens to mint
     * @param data         Data to pass if receiver is contract
     */
    function publicMint(
        address account,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public {
        require(_exists(id), "NONEXISTENT_TOKEN");
        require(publicMintingAllowed[id], "Public minting not allowed");
        _mint(account, id, amount, data);
        tokenSupply[id] = tokenSupply[id] + amount;

        //Emit event
        emit ERC1155NFTMinted(id, amount, address(this), uri(id), msg.sender);
    }

    /**
     * @dev Mints some amount of tokens to an address
     * @param account      Address of the future owner of the token
     * @param id           Token ID to mint
     * @param amount       Amount of tokens to mint
     * @param data         Data to pass if receiver is contract
     */
    function mint(
        address account,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public creatorOrApprovedOnly(id) {
        require(_exists(id), "NONEXISTENT_TOKEN");
        _mint(account, id, amount, data);
        tokenSupply[id] = tokenSupply[id] + amount;

        //Emit event
        emit ERC1155NFTMinted(id, amount, address(this), uri(id), msg.sender);
    }

    /**
     * @dev Mint tokens for each id in _ids
     * @param to           The address to mint tokens to
     * @param ids          Array of ids to mint
     * @param amounts      Array of amounts of tokens to mint per id
     * @param data         Data to pass if receiver is contract
     */
    function mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public {
        for (uint256 i = 0; i < ids.length; i++) {
            uint256 _id = ids[i];
            require(creators[_id] == msg.sender, "ONLY_CREATOR_ALLOWED");
            require(_exists(_id), "NONEXISTENT_TOKEN");
            uint256 _amount = amounts[i];
            tokenSupply[_id] = tokenSupply[_id] + _amount;

            //Emit event
            emit ERC1155NFTMinted(
                _id,
                _amount,
                address(this),
                uri(_id),
                msg.sender
            );
        }
        _mintBatch(to, ids, amounts, data);
    }

    /**
     * @dev Change the creator address for given tokens
     * @param _to   Address of the new creator
     * @param _ids  Array of Token IDs to change creator
     */
    function setCreator(address _to, uint256[] memory _ids) public {
        require(_to != address(0), "INVALID_ADDRESS.");
        for (uint256 i = 0; i < _ids.length; i++) {
            uint256 id = _ids[i];
            _setCreator(_to, id);
        }
    }

    /**
     * @dev Change the creator address for given token
     * @param _to   Address of the new creator
     * @param _id   Token IDs to change creator of
     */
    function _setCreator(address _to, uint256 _id) internal creatorOnly(_id) {
        creators[_id] = _to;
    }

    /**
     * @dev Returns whether the specified token exists by checking to see if it has a creator
     * @param _id uint256 ID of the token to query the existence of
     * @return bool whether the token exists
     */
    function _exists(uint256 _id) internal view returns (bool) {
        return creators[_id] != address(0);
    }

    /**
     * @dev calculates the next token ID based on value of _type
     * @param _type Type of NFT to get next token
     * @return uint256 for the next token ID of
     */
    function _getNextTokenID(CollectibleType _type)
        private
        view
        returns (uint256)
    {
        if (_type == CollectibleType.GAME) {
            require(_gameTokenId < GAME_LIMIT, "GameNFT limit reached");
            return _gameTokenId + 1;
        } else if (_type == CollectibleType.SILVER) {
            require(_silverTokenId < SILVER_LIMIT, "SilverNFT limit reached");
            return _silverTokenId + 1;
        } else if (_type == CollectibleType.GOLD) {
            require(_goldTokenId < GOLD_LIMIT, "GoldNFT limit reached");
            return _goldTokenId + 1;
        } else if (_type == CollectibleType.PLATINUM) {
            require(
                _platinumTokenId < PLATINUM_LIMIT,
                "PlatinumNFT limit reached"
            );
            return _platinumTokenId + 1;
        } else if (_type == CollectibleType.LEGENDARY) {
            require(
                _legendaryTokenId < LEGENDARY_LIMIT,
                "LegendaryNFT limit reached"
            );
            return _legendaryTokenId + 1;
        }
        return 0;
    }

    /**
     * @dev increments the value of appropriate token id
     */
    function _incrementTokenTypeId(CollectibleType _type) private {
        if (_type == CollectibleType.GAME) {
            _gameTokenId++;
        } else if (_type == CollectibleType.SILVER) {
            _silverTokenId++;
        } else if (_type == CollectibleType.GOLD) {
            _goldTokenId++;
        } else if (_type == CollectibleType.PLATINUM) {
            _platinumTokenId++;
        } else if (_type == CollectibleType.LEGENDARY) {
            _legendaryTokenId++;
        }
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC1155Upgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
