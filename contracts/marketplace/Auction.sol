// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "./SaleBase.sol";

/**
 * @title Base auction contract
 * @author Sanan bin Tahir
 * @dev This is the base auction contract which implements the auction functionality
 */
contract AuctionBase is SaleBase {
    using Address for address payable;
    using Counters for Counters.Counter;

    // auction struct to keep track of the auctions
    struct Auction {
        uint256 tokenId;
        bool isArtistNFT;
        uint16 artistCut;
        bool isERC721;
        address seller;
        address nftContract;
        address buyer;
        address artist;
        uint128 startPrice;
        uint128 currentPrice;
        uint64 duration;
        uint64 startedAt;
        uint256 amount; // only relevant for ERC1155
    }

    Counters.Counter internal auctionCounter;
    // mapping for sale id to its auction
    mapping(uint256 => Auction) idToAuction;

    // The minimum percentage difference between the last bid amount and the current bid.
    uint8 public minBidIncrementPercentage = 50;

    event AuctionCreated(
        uint256 saleId,
        bool isArtistNFT,
        bool isERC721,
        uint256 amount,
        uint256 tokenId,
        uint256 startingPrice,
        uint64 startingTime,
        uint256 duration,
        address seller
    );
    event AuctionSuccessful(
        uint256 saleid,
        uint256 tokenId,
        uint256 totalPrice,
        uint256 duration,
        address winner,
        address seller
    );
    event BidCreated(
        uint256 saleId,
        uint256 tokenId,
        uint256 totalPrice,
        uint256 duration,
        address winner,
        address seller
    );

    /**
     * @dev Add the auction to the mapping and emit the AuctionCreated event, duration must meet the requirements
     * @param _auction Reference to the auction struct to add to the mapping
     */
    function _addAuction(Auction memory _auction) internal {
        // check minimum and maximum time requirements
        require(
            _auction.duration >= 1 hours && _auction.duration <= 30 days,
            "time requirement failed"
        );

        uint256 _saleId = auctionCounter.current();

        // update mapping
        idToAuction[_saleId] = _auction;

        auctionCounter.increment();

        // emit event
        emit AuctionCreated(
            _saleId,
            _auction.isArtistNFT,
            _auction.isERC721,
            _auction.amount,
            _auction.tokenId,
            _auction.currentPrice,
            _auction.startedAt,
            _auction.duration,
            _auction.seller
        );
    }

    /**
     * @dev Remove the auction from the mapping (sets everything to zero/false)
     * @param _saleId ID of the sale to remove
     */
    function _removeAuction(uint256 _saleId) internal {
        delete idToAuction[_saleId];
    }

    /**
     * @dev Internal function to check the current price of the auction
     * @param auction Reference to the auction to check price of
     * @return uint128 The current price of the auction
     */
    function _currentPrice(Auction storage auction)
        internal
        view
        returns (uint128)
    {
        return (auction.currentPrice);
    }

    /**
     * @dev Internal function to check if an auction started. By default startedAt is at 0
     * @param _auction Reference to the auction struct to check
     * @return bool Weather the auction has started
     */
    function _isOnAuction(Auction storage _auction)
        internal
        view
        returns (bool)
    {
        return (_auction.startedAt > 0 &&
            _auction.startedAt <= block.timestamp);
    }

    /**
     * @dev Internal function to implement the bid functionality
     * @param _saleId ID of the auction to bid on
     * @param _bidAmount Amount to bid
     */
    function _bid(uint256 _saleId, uint256 _bidAmount) internal {
        // get reference to the auction struct
        Auction storage auction = idToAuction[_saleId];

        // check if the item is on auction
        require(_isOnAuction(auction), "Item is not on auction");

        // check if auction time has ended
        uint256 secondsPassed = block.timestamp - auction.startedAt;
        require(secondsPassed <= auction.duration, "Auction time has ended");

        // check if bid is higher than the previous one
        uint256 price = auction.currentPrice;

        if (price == auction.startPrice) {
            require(_bidAmount >= price, "Bid is too low");
        } else {
            require(
                _bidAmount >=
                    (price + ((price * minBidIncrementPercentage) / 1000)),
                "increment not met"
            );
        }

        // update the current bid amount and the bidder address
        auction.currentPrice = uint128(_bidAmount);
        auction.buyer = msg.sender;

        // if the bid is made in the last 15 minutes, increase the duration of the
        // auction so that the timer resets to 15 minutes
        uint256 timeRemaining = auction.duration - secondsPassed;
        if (timeRemaining <= 15 minutes) {
            uint256 timeToAdd = 15 minutes - timeRemaining;
            auction.duration += uint64(timeToAdd);
        }

        // transfer the erc20 Token to this contract
        Token.transferFrom(msg.sender, address(this), _bidAmount);

        // no previous bidder if buyer is zero address
        if (auction.buyer != address(0)) {
            // return the previous bidder's bid amount
            Token.transfer(auction.buyer, price);
        }

        emit BidCreated(
            _saleId,
            auction.tokenId,
            auction.currentPrice,
            auction.duration,
            auction.buyer,
            auction.seller
        );
    }

    /**
     * @dev Internal function to finish the auction after the auction time has ended
     * @param _saleId ID of the sale to finish
     */
    function _finishAuction(uint256 _saleId) internal {
        // using storage for _isOnAuction
        Auction storage auction = idToAuction[_saleId];

        // check if token was on auction
        require(_isOnAuction(auction), "Invalid sale id");

        // check if auction time has ended
        uint256 secondsPassed = block.timestamp - auction.startedAt;
        require(secondsPassed > auction.duration, "Auction hasn't ended");

        // using struct to avoid stack too deep error
        Auction memory referenceAuction = auction;
        address _nftContract = auction.nftContract;

        // delete the auction
        _removeAuction(_saleId);

        // if there was no successful bid, return token to the seller
        if (referenceAuction.buyer == address(0)) {
            _transfer(
                _nftContract,
                referenceAuction.seller,
                referenceAuction.tokenId,
                referenceAuction.isERC721,
                referenceAuction.amount
            );

            emit AuctionSuccessful(
                _saleId,
                referenceAuction.tokenId,
                0,
                referenceAuction.duration,
                referenceAuction.seller,
                referenceAuction.seller
            );
        }
        // if there was a successful bid, pay the seller and transfer the token to the buyer
        else {
            _payout(
                referenceAuction.isArtistNFT,
                referenceAuction.artistCut,
                referenceAuction.seller,
                referenceAuction.artist,
                referenceAuction.currentPrice
            );
            _transfer(
                referenceAuction.nftContract,
                referenceAuction.buyer,
                referenceAuction.tokenId,
                referenceAuction.isERC721,
                referenceAuction.amount
            );

            emit AuctionSuccessful(
                _saleId,
                referenceAuction.tokenId,
                referenceAuction.currentPrice,
                referenceAuction.duration,
                referenceAuction.buyer,
                referenceAuction.seller
            );
        }
    }

    /**
     * @dev This is an internal function to end auction meant to only be used as a safety
     * mechanism if an NFT got locked within the contract. Can only be called by the super admin
     * after a period of 7 days has passed since the auction ended
     * @param _saleId ID of the sale to forcibly finish
     * @param _nftBeneficiary Address to send the NFT to
     * @param _paymentBeneficiary Address to send the payment to
     */
    function _forceFinishAuction(
        uint256 _saleId,
        address _nftBeneficiary,
        address _paymentBeneficiary
    ) internal {
        // using storage for _isOnAuction
        Auction storage auction = idToAuction[_saleId];

        // check if token was on auction
        require(_isOnAuction(auction), "Token was not on auction");

        // check if auction time has ended
        uint256 secondsPassed = block.timestamp - auction.startedAt;
        require(secondsPassed > auction.duration, "Auction hasn't ended");

        // check if its been more than 7 days since auction ended
        require(secondsPassed - auction.duration >= 7 days);

        // using struct to avoid stack too deep error
        Auction memory referenceAuction = auction;

        // delete the auction
        _removeAuction(_saleId);

        // transfer ether to the beneficiary
        Token.transfer(_paymentBeneficiary, referenceAuction.currentPrice);

        // transfer nft to the nft beneficiary
        _transfer(
            referenceAuction.nftContract,
            _nftBeneficiary,
            referenceAuction.tokenId,
            referenceAuction.isERC721,
            referenceAuction.amount
        );

        emit AuctionSuccessful(
            _saleId,
            referenceAuction.tokenId,
            0,
            referenceAuction.duration,
            _nftBeneficiary,
            _paymentBeneficiary
        );
    }
}

/**
 * @title Auction sale contract that provides external functions
 * @author Sanan bin Tahir
 * @dev Implements the external and public functions of the auction implementation
 */
contract AuctionSale is AuctionBase {
    /**
     * @dev Internal function to create auction.
     * @param _isArtistNFT If this NFT is an artist NFT (different fees)
     * @param _isERC721 If this token is an ERC721 token
     * @param _tokenId ID of the token to create auction for
     * @param _amount Amount of tokens in this sale (only relevant for ERC1155)
     * @param _nftAddress Address of NFT
     * @param _startingPrice Starting price of the auction in wei
     * @param _duration Duration of the auction in seconds
     * @param _seller Address of the seller of the NFT
     */
    function createAuctionSale(
        bool _isArtistNFT,
        bool _isERC721,
        address _artist,
        uint256 _tokenId,
        uint256 _amount, // only relevant for ERC1155
        address _nftAddress,
        uint128 _startingPrice,
        uint64 _startingTime,
        uint64 _duration,
        address _seller,
        uint16 _artistCut
    ) internal {
        // create and add the auction
        Auction memory auction = Auction(
            _tokenId,
            _isArtistNFT,
            _artistCut,
            _isERC721,
            _seller,
            _nftAddress,
            address(0),
            _artist,
            uint128(_startingPrice),
            uint128(_startingPrice),
            uint64(_duration),
            _startingTime,
            _amount
        );
        _addAuction(auction);
    }

    /**
     * @dev External payable bid function. Sellers can not bid on their own artworks
     * @param _saleId Id of the auction to bid on
     * @param _amount amount of the erc20 token to bid
     */
    function bid(uint256 _saleId, uint256 _amount) external nonReentrant {
        // do not allow sellers to bid on their own artwork
        require(
            idToAuction[_saleId].seller != msg.sender,
            "Sellers not allowed"
        );

        _bid(_saleId, _amount);
    }

    /**
     * @dev External function to finish the auction. Currently can be called by anyone
     * @param _saleId Id of the auction to finish
     */
    function finishAuction(uint256 _saleId) external {
        _finishAuction(_saleId);
    }

    /**
     * @dev External view function to get the details of an auction
     * @param _saleId ID of the auction to get
     * @return tokenContract Address of the token contract for this auction
     * @return seller Address of the seller
     * @return buyer Address of the buyer
     * @return tokenId ID of the token listed on this auction
     * @return currentPrice Current Price of the auction in wei
     * @return duration Duration of the auction in seconds
     * @return startedAt Unix timestamp for when the auction started
     */
    function getAuction(uint256 _saleId)
        external
        view
        returns (
            address tokenContract,
            address seller,
            address buyer,
            uint256 tokenId,
            uint256 currentPrice,
            uint256 duration,
            uint256 startedAt
        )
    {
        Auction storage auction = idToAuction[_saleId];
        require(_isOnAuction(auction));
        return (
            auction.nftContract,
            auction.seller,
            auction.buyer,
            auction.tokenId,
            auction.currentPrice,
            auction.duration,
            auction.startedAt
        );
    }

    /**
     * @dev External view function to get the current price of an auction
     * @param _saleId ID of the auction to get current price of
     * @return uint128 Current price of the auction in wei
     */
    function getCurrentPrice(uint256 _saleId) external view returns (uint128) {
        Auction storage auction = idToAuction[_saleId];
        require(_isOnAuction(auction));
        return _currentPrice(auction);
    }

    /**
     * @dev This is an internal function to end auction meant to only be used as a safety
     * mechanism if an NFT got locked within the contract. Can only be called by the super admin
     * after a period f 7 days has passed since the auction ended
     * @param _saleId ID of the auction to forcibly finish
     * @param _nftBeneficiary Address to send the NFT to
     * @param _paymentBeneficiary Address to send the payment to
     */
    function forceFinishAuction(
        uint256 _saleId,
        address _nftBeneficiary,
        address _paymentBeneficiary
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _forceFinishAuction(_saleId, _nftBeneficiary, _paymentBeneficiary);
    }
}
