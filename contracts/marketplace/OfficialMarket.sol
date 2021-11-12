// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./FixedPrice.sol";
import "../utils/EnumerableMap.sol";

contract OfficialMarket is FixedPriceSale, Pausable {
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

    constructor(
        address _artistNFTAddress,
        address _busdAddress,
        address _ecchiCoinAddress,
        uint256 _liquidityTokenThreshhold //the min number of tokens sold after which they can be added to liquidity pool
    ) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(LISTER_ROLE, msg.sender);
        Token = IERC20(_busdAddress);
        Token2 = IERC20(_ecchiCoinAddress);
        artistNFTAddress = _artistNFTAddress;
        numTokensSellToAddToLiquidity = _liquidityTokenThreshhold;
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
    )
        public
        onlyValidStartingTime(_startingTime)
        onlyRole(LISTER_ROLE)
        nonReentrant
        whenNotPaused
    {
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
            IERC165(_nftAddress).supportsInterface(InterfaceSignature_ERC721) ||
                IERC165(_nftAddress).supportsInterface(
                    InterfaceSignature_ERC1155
                ),
            "tokenContract does not support ERC721 or ERC1155 interface"
        );

        saleReference.isERC721 = IERC165(_nftAddress).supportsInterface(
            InterfaceSignature_ERC721
        );

        // get reference to owner before transfer
        saleReference.seller = msg.sender;

        if (saleReference.isERC721) {
            address _owner = IERC721(_nftAddress).ownerOf(_tokenId);
            require(_owner == msg.sender, "Not owner");

            // escrow the token into the auction smart contract
            IERC721(_nftAddress).safeTransferFrom(
                _owner,
                address(this),
                _tokenId
            );
        } else {
            require(
                IERC1155(_nftAddress).balanceOf(msg.sender, _tokenId) >=
                    _amount,
                "Sender is not owner"
            );

            IERC1155(_nftAddress).safeTransferFrom(
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
    ) external onlyRole(LISTER_ROLE) whenNotPaused {
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
