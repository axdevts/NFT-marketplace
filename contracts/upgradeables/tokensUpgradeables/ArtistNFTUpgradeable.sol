// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";

contract ArtistNFTUpgradeable is
    Initializable,
    ERC721Upgradeable,
    ERC721EnumerableUpgradeable,
    ERC721BurnableUpgradeable,
    ERC721URIStorageUpgradeable,
    AccessControlUpgradeable
{
    using CountersUpgradeable for CountersUpgradeable.Counter;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    CountersUpgradeable.Counter private _tokenIdCounter;
    address public NFTMarketplace;

    // mapping of token id to original creator
    mapping(uint256 => address) public tokenIdToCreator;

    event ArtistNFTMinted(
        uint256 tokenID, 
        uint256 amountMinted, 
        address contractAddress, 
        string tokenMetadataUri, 
        address creator);

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
     * @dev Initializer
     */
    function initialize() public initializer {
        __ERC721_init("ArtistNFT", "AFT");
        __ERC721Enumerable_init();
        __ERC721Burnable_init();
        __ERC721URIStorage_init();
        __AccessControl_init();
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MINTER_ROLE, msg.sender);
    }

    function safeMint(
        address to,
        address _creator,
        uint8 _numberOfCopies,
        string[] memory _tokenURI
    ) public onlyRole(MINTER_ROLE) {
        require(
            _tokenURI.length == _numberOfCopies,
            "Metadata URIs not equal to editions"
        );

        for (uint256 i = 0; i < _numberOfCopies; i++) {
            // mint the token
            _safeMint(to, _tokenIdCounter.current());

            // set token URI
            _setTokenURI(_tokenIdCounter.current(), _tokenURI[i]);

            // set token ID creator
            tokenIdToCreator[_tokenIdCounter.current()] = _creator;

            // emit event
            emit ArtistNFTMinted(
            _tokenIdCounter.current(),
            1,
            address(this),
            _tokenURI[i],
            _creator);

            // increment tokenId
            _tokenIdCounter.increment();
        }
    }

    function getIsArtistNFT() public pure returns (bool) {
        return true;
    }

    function getCreator(uint256 _tokenId) public view returns (address) {
        return tokenIdToCreator[_tokenId];
    }

    // The following functions are overrides required by Solidity.

    function _burn(uint256 tokenId)
        internal
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
    {
        super._burn(tokenId);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721Upgradeable, ERC721EnumerableUpgradeable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function setNFTMarketplaceAddress(address _address)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        NFTMarketplace = _address;
    }
}
