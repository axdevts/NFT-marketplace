// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/PullPayment.sol";
import "./SaleBase.sol";
import "../utils/EnumerableMap.sol";

/**
 * @title Base open offers contract
 * @author Sanan bin Tahir
 * @dev This is the base contract which implements the open offers functionality
 */
contract OpenOffersBase is SaleBase {
    using Address for address payable;

    // Add the library methods
    using EnumerableMap for EnumerableMap.AddressToUintMap;

    struct OpenOffers {
        bool isArtistNFT;
        bool isERC721;
        address artist;
        address seller;
        address nftContract;
        uint64 startedAt;
        uint16 artistCut;
        uint256 amount;
        EnumerableMap.AddressToUintMap offers;
    }

    // this struct is only used for referencing in memory. The OpenOffers struct can not
    // be used because it is only valid in storage since it contains a nested mapping
    struct OffersReference {
        bool isArtistNFT;
        bool isERC721;
        address artist;
        address seller;
        uint16 artistCut;
        uint256 amount;
    }

    // mapping for tokenId to its sale
    mapping(address => mapping(uint256 => OpenOffers)) tokenIdToOpenOffersSale;
    // for pull payments
    mapping(address => uint256) public addressToTokenOwed;

    event OpenOffersSaleCreated(
        bool isArtistNFT,
        bool isERC721,
        uint256 amount,
        uint256 tokenId,
        address nftContract,
        uint64 startingTime,
        address seller
    );
    event OpenOffersSaleSuccessful(
        uint256 tokenId,
        address nftContract,
        uint256 totalPrice,
        address winner,
        address seller
    );
    event makeOpenOffer(
        uint256 tokenId,
        address nftContract,
        uint256 totalPrice,
        address winner,
        address seller
    );
    event rejectOpenOffer(
        uint256 tokenId,
        address nftContract,
        uint256 totalPrice,
        address loser,
        address seller
    );
    event OpenOffersSaleFinished(
        uint256 tokenId,
        address nftContract,
        address seller
    );

    /**
     * @dev Internal function to check if the sale started, by default startedAt will be 0
     *
     */
    function _isOnSale(OpenOffers storage _openSale)
        internal
        view
        returns (bool)
    {
        return (_openSale.startedAt > 0 &&
            _openSale.startedAt <= block.timestamp);
    }

    /**
     * @dev Remove the sale from the mapping (sets everything to zero/false)
     * @param _nftAddress Address of NFT
     * @param _tokenId ID of the token to remove sale of
     */
    function _removeOpenOffersSale(address _nftAddress, uint256 _tokenId)
        internal
    {
        delete tokenIdToOpenOffersSale[_nftAddress][_tokenId];
    }

    /**
     * @dev Internal that updates the mapping when a new offer is made for a token on sale
     * @param _nftAddress Address of NFT
     * @param _tokenId Id of the token to make offer on
     * @param _bidAmount The offer in wei
     */
    function _makeOffer(
        address _nftAddress,
        uint256 _tokenId,
        uint256 _bidAmount
    ) internal {
        // get reference to the open offer struct
        OpenOffers storage openSale = tokenIdToOpenOffersSale[_nftAddress][
            _tokenId
        ];

        // check if the item is on sale
        require(_isOnSale(openSale), "Item is not on sale");

        uint256 returnAmount;
        bool offerExists;

        // get reference to the amount to return
        (offerExists, returnAmount) = openSale.offers.tryGet(msg.sender);

        // update the mapping with the new offer
        openSale.offers.set(msg.sender, _bidAmount);

        // transfer the amount to this address
        Token.transferFrom(msg.sender, address(this), _bidAmount);

        // if there was a previous offer from this address, return the previous offer amount
        if (offerExists) {
            Token.transfer(msg.sender, returnAmount);
        }

        // emit event
        emit makeOpenOffer(
            _tokenId,
            openSale.nftContract,
            _bidAmount,
            msg.sender,
            openSale.seller
        );
    }

    /**
     * @dev Internal function to accept the offer of an address. Once an offer is accepted, all existing offers
     * for the token are moved into the PullPayment contract and the mapping is deleted.
     * @param _nftAddress Address of NFT
     * @param _tokenId Id of the token to accept offer of
     * @param _buyer The address of the buyer to accept offer from
     */
    function _acceptOffer(
        address _nftAddress,
        uint256 _tokenId,
        address _buyer
    ) internal nonReentrant {
        OpenOffers storage openSale = tokenIdToOpenOffersSale[_nftAddress][
            _tokenId
        ];

        require(openSale.seller == msg.sender);

        // check if token was on sale
        require(_isOnSale(openSale), "Item is not on sale");

        // check if the offer from the buyer exists
        require(openSale.offers.contains(_buyer));

        // get reference to the offer
        uint256 _payoutAmount = openSale.offers.get(_buyer);

        // remove the offer from the enumerable mapping
        openSale.offers.remove(_buyer);

        address returnAddress;
        uint256 returnAmount;

        // put the returns in the pull payments contract
        for (uint256 i = 0; i < openSale.offers.length(); i++) {
            (returnAddress, returnAmount) = openSale.offers.at(i);
            // transfer the return amount into the pull payement mapping
            addressToTokenOwed[returnAddress] += returnAmount;
        }

        // using struct to avoid stack too deep error
        OffersReference memory openSaleReference = OffersReference(
            openSale.isArtistNFT,
            openSale.isERC721,
            openSale.artist,
            openSale.seller,
            openSale.artistCut,
            openSale.amount
        );
        address _nftContract = openSale.nftContract;

        // delete the sale
        _removeOpenOffersSale(_nftAddress, _tokenId);

        // pay the seller and distribute the cuts
        _payout(
            openSaleReference.isArtistNFT,
            openSaleReference.artistCut,
            openSaleReference.seller,
            openSaleReference.artist,
            _payoutAmount
        );

        // transfer the token to the buyer
        _transfer(
            _nftContract,
            _buyer,
            _tokenId,
            openSaleReference.isERC721,
            openSaleReference.amount
        );

        // emit event
        emit OpenOffersSaleSuccessful(
            _tokenId,
            _nftContract,
            _payoutAmount,
            _buyer,
            openSaleReference.seller
        );
    }

    /**
     * @dev Internal function to cancel an offer. This is used for both rejecting and revoking offers
     * @param _nftAddress Address of NFT
     * @param _tokenId Id of the token to cancel offer of
     * @param _buyer The address to cancel bid of
     */
    function _cancelOffer(
        address _nftAddress,
        uint256 _tokenId,
        address _buyer
    ) internal {
        OpenOffers storage openSale = tokenIdToOpenOffersSale[_nftAddress][
            _tokenId
        ];

        // check if token was on sale
        require(_isOnSale(openSale), "Item is not on sale");

        // get reference to the offer, will fail if mapping doesn't exist
        uint256 _payoutAmount = openSale.offers.get(_buyer);
        address _nftContract = openSale.nftContract;

        // remove the offer from the enumerable mapping
        openSale.offers.remove(_buyer);

        // return the Token
        Token.transfer(_buyer, _payoutAmount);

        // emit event
        emit rejectOpenOffer(
            _tokenId,
            _nftContract,
            _payoutAmount,
            _buyer,
            openSale.seller
        );
    }

    /**
     * @dev Function to finish the sale. Can be called manually if there was no suitable offer
     * for the NFT.
     * @param _nftAddress Address of NFT
     * @param _tokenId Id of the token to end sale of
     */
    function _finishOpenOffersSale(address _nftAddress, uint256 _tokenId)
        internal
        nonReentrant
    {
        OpenOffers storage openSale = tokenIdToOpenOffersSale[_nftAddress][
            _tokenId
        ];

        require(
            openSale.seller == msg.sender ||
                hasRole(DEFAULT_ADMIN_ROLE, msg.sender)
        );

        // check if token was on sale
        require(openSale.startedAt > 0, "Item is not listed");

        address seller = openSale.seller;

        address returnAddress;
        uint256 returnAmount;

        // put all pending returns in the pull payments contract
        for (uint256 i = 0; i < openSale.offers.length(); i++) {
            (returnAddress, returnAmount) = openSale.offers.at(i);
            // transfer the return amount into the pull payement contract
            addressToTokenOwed[returnAddress] += returnAmount;
        }

        address _nftContract = openSale.nftContract;
        bool _isERC721 = openSale.isERC721;
        uint256 _amount = openSale.amount;

        // delete the sale
        _removeOpenOffersSale(_nftAddress, _tokenId);

        // return the token to the seller
        _transfer(_nftContract, seller, _tokenId, _isERC721, _amount);

        // emit event
        emit OpenOffersSaleFinished(_tokenId, _nftContract, openSale.seller);
    }
}

/**
 * @title Open Offers sale contract that provides external functions
 * @author Sanan bin Tahir
 * @dev Implements the external and public functions of the open offers implementation
 */
contract OpenOffersSale is OpenOffersBase {
    bool public isEcchiOpenOffersSale = true;

    /**
     * Internal function to create an Open Offers sale.
     * @param _isArtistNFT If this is an artist NFT (different fees)
     * @param _isERC721 If this is an ERC721 token (its ERC1155 if this is false)
     * @param _tokenId Id of the token to create sale for
     * @param _amount Amount of tokens. Only relevant for ERC1155
     * @param _nftAddress Address of NFT
     * @param _startingTime Starting time of the sale
     * @param _seller Address of the owner of the artwork
     */
    function createOpenOffersSale(
        bool _isArtistNFT,
        bool _isERC721,
        address _artist,
        uint256 _tokenId,
        uint256 _amount,
        address _nftAddress,
        uint64 _startingTime,
        address _seller,
        uint16 _artistCut
    ) internal {
        OpenOffers storage openOffers = tokenIdToOpenOffersSale[_nftAddress][
            _tokenId
        ];

        openOffers.isArtistNFT = _isArtistNFT;
        openOffers.isERC721 = _isERC721;
        openOffers.artist = _artist;
        openOffers.seller = _seller;
        openOffers.nftContract = _nftAddress;
        openOffers.startedAt = _startingTime;
        openOffers.artistCut = _artistCut;
        openOffers.amount = _amount;

        // emit event
        emit OpenOffersSaleCreated(
            _isArtistNFT,
            _isERC721,
            _amount,
            _tokenId,
            openOffers.nftContract,
            openOffers.startedAt,
            openOffers.seller
        );
    }

    /**
     * @dev External function that allows others to make offers for an artwork
     * @param _nftAddress Address of NFT
     * @param _tokenId Id of the token to make offer for
     */
    function makeOffer(
        address _nftAddress,
        uint256 _tokenId,
        uint256 _amount
    ) external {
        // do not allow sellers to make offers on their own artwork
        require(
            tokenIdToOpenOffersSale[_nftAddress][_tokenId].seller != msg.sender,
            "Sellers not allowed"
        );

        _makeOffer(_nftAddress, _tokenId, _amount);
    }

    /**
     * @dev External function to allow a seller to accept an offer
     * @param _nftAddress Address of NFT
     * @param _tokenId Id of the token to accept offer of
     * @param _buyer Address of the buyer to accept offer of
     */
    function acceptOffer(
        address _nftAddress,
        uint256 _tokenId,
        address _buyer
    ) external {
        _acceptOffer(_nftAddress, _tokenId, _buyer);
    }

    /**
     * @dev External function for taking out owed Token using the pull payments mechanism
     */
    function withdraw() external nonReentrant {
        uint256 owed = addressToTokenOwed[msg.sender];

        require(owed > 0, "Nothing to pull");
        addressToTokenOwed[msg.sender] = 0;
        // transfer the Token
        Token.transfer(msg.sender, addressToTokenOwed[msg.sender]);
    }

    /**
     * @dev External function to reject a particular offer and return the ether
     * @param _nftAddress Address of NFT
     * @param _tokenId Id of the token to reject offer of
     * @param _buyer Address of the buyer to reject offer of
     */
    function rejectOffer(
        address _nftAddress,
        uint256 _tokenId,
        address _buyer
    ) external {
        // only owner can reject an offer
        require(
            tokenIdToOpenOffersSale[_nftAddress][_tokenId].seller == msg.sender
        );
        _cancelOffer(_nftAddress, _tokenId, _buyer);
    }

    /**
     * @dev External function to allow buyers to revoke their offers
     * @param _nftAddress Address of NFT
     * @param _tokenId Id of the token to revoke offer of
     */
    function revokeOffer(address _nftAddress, uint256 _tokenId) external {
        _cancelOffer(_nftAddress, _tokenId, msg.sender);
    }

    /**
     * @dev External function to finish the sale if no one bought it. Can only be called by the owner
     * @param _nftAddress Address of NFT
     * @param _tokenId ID of the token to finish sale of
     */
    function finishOpenOffersSale(address _nftAddress, uint256 _tokenId)
        external
    {
        _finishOpenOffersSale(_nftAddress, _tokenId);
    }
}
