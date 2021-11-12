// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "./FixedPriceUpgradeable.sol";
import "../utilsUpgradeables/EnumerableMap.sol";

contract OfficialMarketUpgradeable is FixedPriceSaleUpgradeable, PausableUpgradeable {
    // Add the library methods
    using EnumerableMap for EnumerableMap.UintToAddressMap;

    bytes32 public constant LISTER_ROLE = keccak256("LISTER_ROLE");
    uint16 public constant ARTIST_CUT = 80; // 8%
    
    // this struct is only used for referencing in memory
    struct SaleReference {
        bool isArtistNFT;
        bool isERC721;
        address seller;
        address artist;
        uint256 amount;
    }

    /**
     * @dev Initializer
     */
    function initialize(
        address _artistNFTAddress,
        address _busdAddress,
        address _ecchiCoinAddress,
        uint256 _liquidityTokenThreshhold //the min number of tokens sold after which they can be added to liquidity pool
    )public initializer {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(LISTER_ROLE, msg.sender);
        __AccessControl_init();
        __ERC1155Holder_init();
        __ReentrancyGuard_init();
        __Pausable_init();
        Token = IERC20Upgradeable(_busdAddress);
        Token2 = IERC20(_ecchiCoinAddress);
        artistNFTAddress = _artistNFTAddress;
        numTokensSellToAddToLiquidity = _liquidityTokenThreshhold;
        
        // address of the platform wallet to which the platform cut will be sent
        rewardsWalletAddress = address(0xC5f4461380A5e1Fed95b9A2E0474Ee64422d20d5);
        serverWalletAddress = address(0xbf7C98F815f3aCcD7255F3595E8b27a01E336206);
        maintenanceWalletAddress = address(0x592d9D76EC0Ee77d7407764cF501214809FFCE49);
        
        // cuts are in %age * 10
        rewardsCut = 10; // 1%
        serverCut = 5; // 0.5%
        maintenanceCut = 5; // 0.5%
        liquidityCut = 10; // 1%

        swapAndLiquifyEnabled = true;
    }

    /**
     * @dev Puclic function(only admin authorized) to pause the contract
     */
    function pause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    /**
     * @dev Puclic function(only admin authorized) to unpause the contract
     */
    function unpause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    /**
     * @dev Make sure the starting time is not greater than 60 days
     * @param _startingTime starting time of the sale in UNIX timestamp
     */
    modifier onlyValidStartingTime(uint64 _startingTime) {
        if (_startingTime > block.timestamp) {
            require(
                _startingTime - block.timestamp <= 60 days,
                "Start time too far"
            );
        }
        _;
    }

    /**
     * @dev Creates the fixed price sale for the token by calling the internal fixed sale contract. Can only be called by owner.
     * Individual external contract calls are expensive so a single function is used to pass all parameters
     * @param _nftAddress Address of NFT
     * @param _tokenId ID of the token to put on auction
     * @param _amount Amount of tokens to put on sale (only relevant for ERC1155)
     * @param _fixedPrice Fixed price of the auction
     * @param _startingTime Starting time of the auction in UNIX timestamp
     */
    function createSaleFixedPrice(
        address _nftAddress,
        uint256 _tokenId,
        uint256 _amount,
        uint128 _fixedPrice,
        uint64 _startingTime
    ) public onlyValidStartingTime(_startingTime) onlyRole(LISTER_ROLE) nonReentrant whenNotPaused(){
        SaleReference memory saleReference;
        
        saleReference.isArtistNFT = _nftAddress == artistNFTAddress;

        if (saleReference.isArtistNFT) {
            require(
                IArtistNFT(_nftAddress).getIsArtistNFT(),
                "Artist contract incorrectly set"
            );
            saleReference.artist = IArtistNFT(_nftAddress).getCreator(_tokenId);
        }

        require(
            IERC165Upgradeable(_nftAddress).supportsInterface(InterfaceSignature_ERC721) ||
                IERC165Upgradeable(_nftAddress).supportsInterface(
                    InterfaceSignature_ERC1155
                ),
            "tokenContract does not support ERC721 or ERC1155 interface"
        );

        saleReference.isERC721 = IERC165Upgradeable(_nftAddress).supportsInterface(
            InterfaceSignature_ERC721
        );

        // get reference to owner before transfer
        saleReference.seller = msg.sender;

        if (saleReference.isERC721) {
            address _owner = IERC721Upgradeable(_nftAddress).ownerOf(_tokenId);
            require(_owner == msg.sender, "Not owner");

            // escrow the token into the auction smart contract
            IERC721Upgradeable(_nftAddress).safeTransferFrom(
                _owner,
                address(this),
                _tokenId
            );
        } else {
            require(
                IERC1155Upgradeable(_nftAddress).balanceOf(msg.sender, _tokenId) >=
                    _amount,
                "Sender is not owner"
            );

            IERC1155Upgradeable(_nftAddress).safeTransferFrom(
                msg.sender,
                address(this),
                _tokenId,
                _amount,
                ""
            );
        }

        // call the internal contract function to create the auction
        createFixedSale(
            saleReference.isArtistNFT,
            saleReference.isERC721,
            saleReference.artist,
            _tokenId,
            _amount, // amount is only relevant for ERC1155 tokens
            _nftAddress,
            _fixedPrice,
            _startingTime,
            saleReference.seller,
            ARTIST_CUT
        );
    }

    /**
     * @dev Creates the fixed price sale for a bulk of tokens by calling the public createSaleFixedPrice function. Can only be called by owner.
     * Individual external contract calls are expensive so a single function is used to pass all parameters
     * @param _nftAddress Address of NFT
     * @param _tokenId IDs of the tokens to put on auction
     * @param _amount Amount of each token (only relevant for ERC1155)
     * @param _fixedPrice Fixed prices of the auction
     * @param _startingTime Starting times of the auction in UNIX timestamp
     */
    function createBulkSaleFixedPrice(
        address _nftAddress,
        uint256[] memory _tokenId,
        uint256[] memory _amount,
        uint128[] memory _fixedPrice,
        uint64[] memory _startingTime
    ) external onlyRole(LISTER_ROLE) whenNotPaused(){
        uint256 _numberOfTokens = _tokenId.length;

        require(
            _fixedPrice.length == _numberOfTokens,
            "fixed prices not equal to number of tokens"
        );
        require(
            _startingTime.length == _numberOfTokens,
            "starting times not equal to number of tokens"
        );
        require(
            _amount.length == _numberOfTokens,
            "amount not equal to number of tokens"
        );

        for (uint256 i = 0; i < _numberOfTokens; i++) {
            createSaleFixedPrice(
                _nftAddress,
                _tokenId[i],
                _amount[i],
                _fixedPrice[i],
                _startingTime[i]
            );
        }
    }
}
