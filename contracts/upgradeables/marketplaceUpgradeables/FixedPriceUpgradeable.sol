// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./SaleBaseUpgradeable.sol";

/**
 * @title Base fixed price contract
 * @author Sanan bin Tahir
 * @dev This is the base fixed price contract which implements the internal functionality
 */
contract FixedPriceBaseUpgradeable is SaleBaseUpgradeable {
    using AddressUpgradeable for address payable;
    using CountersUpgradeable for CountersUpgradeable.Counter;

    // fixed price sale struct to keep track of the sales
    struct FixedPrice {
        uint256 tokenId;
        bool isArtistNFT;
        uint16 artistCut;
        bool isERC721;
        address seller;
        address nftContract;
        address artist;
        uint128 fixedPrice;
        uint64 startedAt;
        uint256 amount; // only relevant for ERC1155
    }

    CountersUpgradeable.Counter internal fixedSaleCounter;
    // mapping for sale id to the Fixed Sale struct
    mapping (uint256 => FixedPrice) idToFixedSale;

    event FixedSaleCreated(
        uint256 saleId,
        bool isERC721,
        uint256 tokenId,
        address nftContract,
        uint128 fixedPrice,
        uint64 startingTime,
        address seller,
        uint256 amount
    );
    event FixedSaleSuccessful(
        uint256 saleId,
        bool isERC721,
        uint256 tokenId,
        address nftContract,
        uint256 totalPrice,
        address winner,
        address seller
    );
    event FixedSaleFinished(
        uint256 saleId,
        uint256 tokenId,
        address nftContract,
        address seller
    );

    /**
     * @dev Add the sale to the mapping and emit the FixedSaleCreated event
     * @param _fixedSale Reference to the sale struct to add to the mapping
     */
    function _addFixedSale(FixedPrice memory _fixedSale)
        internal
    {
        uint256 _saleId = fixedSaleCounter.current();

        // update mapping
        idToFixedSale[_saleId] = _fixedSale;

        fixedSaleCounter.increment();

        // emit event for FixedSaleCreated
        emit FixedSaleCreated(
            _saleId,
            _fixedSale.isERC721,
            _fixedSale.tokenId,
            _fixedSale.nftContract,
            _fixedSale.fixedPrice,
            _fixedSale.startedAt,
            _fixedSale.seller,
            _fixedSale.amount
        );
    }

    /**
     * @dev Remove the sale from the mapping (sets everything to zero/false)
     * @param _saleId Id of the sale to remove
     */
    function _removeFixedSale(uint256 _saleId) internal {
        delete idToFixedSale[_saleId];
    }

    /**
     * @dev Internal function to check if a sale started. By default startedAt is at 0
     * @param _fixedSale Reference to the sale struct to check
     * @return bool Weather the sale has started
     */
    function _isOnSale(FixedPrice storage _fixedSale)
        internal
        view
        returns (bool)
    {
        return (_fixedSale.startedAt > 0 &&
            _fixedSale.startedAt <= block.timestamp);
    }

    /**
     * @dev Internal function to buy a token on sale
     * @param _saleId Id of the sale to buy
     */
    function _buy(uint256 _saleId) internal {
        // get reference to the fixed price sale struct
        FixedPrice storage fixedSale = idToFixedSale[_saleId];

        // check if the item is on sale
        require(_isOnSale(fixedSale), "Item is not on sale");

        // using struct to avoid stack too deep error
        FixedPrice memory referenceFixedSale = fixedSale;

        // delete the sale
        _removeFixedSale(_saleId);

        // pay the seller, and distribute cuts
        _payout(
            referenceFixedSale.isArtistNFT,
            referenceFixedSale.artistCut,
            referenceFixedSale.seller,
            referenceFixedSale.artist,
            referenceFixedSale.fixedPrice
        );

        // transfer the token to the buyer
        _transfer(
            referenceFixedSale.nftContract,
            msg.sender,
            referenceFixedSale.tokenId,
            referenceFixedSale.isERC721,
            referenceFixedSale.amount
        );

        emit FixedSaleSuccessful(
            _saleId,
            referenceFixedSale.isERC721,
            referenceFixedSale.tokenId,
            referenceFixedSale.nftContract,
            referenceFixedSale.fixedPrice,
            msg.sender,
            referenceFixedSale.seller
        );
    }

    /**
     * @dev Function to finish the sale. Can be called manually if no one bought the NFT.
     * @param _saleId Id of the sale to finish
     */
    function _finishFixedSale(uint256 _saleId) internal {
        FixedPrice storage fixedSale = idToFixedSale[_saleId];

        require(fixedSale.seller == msg.sender);

        // check if token was on sale
        require(fixedSale.startedAt > 0, "Item is not on sale");

        FixedPrice memory referenceFixedSale = fixedSale;

        // delete the sale
        _removeFixedSale(_saleId);

        // return the token to the seller
        _transfer(
            referenceFixedSale.nftContract,
            referenceFixedSale.seller,
            referenceFixedSale.tokenId,
            referenceFixedSale.isERC721,
            referenceFixedSale.amount
        );

        emit FixedSaleFinished(
            _saleId,
            referenceFixedSale.tokenId,
            referenceFixedSale.nftContract,
            fixedSale.seller
        );
    }
}

/**
 * @title Fixed Price sale contract that provides external functions
 * @author Sanan bin Tahir
 * @dev Implements the external and public functions of the Fixed price implementation
 */
contract FixedPriceSaleUpgradeable is FixedPriceBaseUpgradeable  {
    /**
     * @dev Internal function to create fixed sale.
     * @param _isERC721 if sale is ERC721 token (false if it is ERC1155 token)
     * @param _tokenId ID of the token to create sale for
     * @param _amount The amount of tokens (only relevant for ERC1155 tokens)
     * @param _fixedPrice Starting price of the sale in wei
     * @param _seller Address of the seller of the NFT
     */
    function createFixedSale(
        bool _isArtistNFT,
        bool _isERC721,
        address _artist,
        uint256 _tokenId,
        uint256 _amount,
        address _nftContract,
        uint128 _fixedPrice,
        uint64 _startingTime,
        address _seller,
        uint16 _artistCut
    ) internal {
        // create and add the sale
        FixedPrice memory fixedSale = FixedPrice(
            _tokenId,
            _isArtistNFT,
            _artistCut,
            _isERC721,
            _seller,
            _nftContract,
            _artist,
            _fixedPrice,
            _startingTime,
            _amount
        );

        _addFixedSale(fixedSale);
    }

    /**
     * @dev External payable function to buy the artwork
     * @param _saleId Id of the sale to buy
     */
    function buy(uint256 _saleId) external nonReentrant {
        // do not allow sellers to buy their own artwork
        require(
            idToFixedSale[_saleId].seller != msg.sender,
            "Sellers not allowed"
        );

        Token.transferFrom(
            msg.sender,
            address(this),
            idToFixedSale[_saleId].fixedPrice
        );

        _buy(_saleId);
    }

    /**
     * @dev External function to finish the sale if no one bought it.
     * @param _saleId Id of the sale to finish
     */
    function finishFixedSale(uint256 _saleId) external nonReentrant {
        _finishFixedSale(_saleId);
    }

    /**
     * @dev External view function to get the details of a sale
     * @param _saleId Id of the sale to get details of
     * @return tokenId Id of the token on sale
     * @return tokenContract Address of the token contract
     * @return seller Address of the seller
     * @return fixedPrice Fixed Price of the sale in wei
     * @return startedAt Unix timestamp for when the sale started
     * @return amount The amount of tokens on sale (only relevant for ERC1155)
     * @return isERC721 If the sale involves ERC721 token (its ERC1155 if this is false)
     */
    function getFixedSale(uint256 _saleId)
        external
        view
        returns (
            uint256 tokenId,
            address tokenContract,
            address seller,
            uint256 fixedPrice,
            uint256 startedAt,
            uint256 amount,
            bool isERC721
        )
    {
        FixedPrice storage fixedSale = idToFixedSale[_saleId];
        require(_isOnSale(fixedSale), "Item is not on sale");
        return (
            fixedSale.tokenId,
            fixedSale.nftContract,
            fixedSale.seller,
            fixedSale.fixedPrice,
            fixedSale.startedAt,
            fixedSale.amount,
            fixedSale.isERC721
        );
    }
}
