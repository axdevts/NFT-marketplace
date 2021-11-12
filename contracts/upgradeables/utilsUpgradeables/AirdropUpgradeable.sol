// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract AirdropUpgradeable is Initializable, OwnableUpgradeable, ERC1155HolderUpgradeable, ERC721HolderUpgradeable {
    struct ERC721Airdrop {
        address nftAddress;
        uint256 tokenId;
    }

    struct ERC1155Airdrop {
        address nftAddress;
        uint256 tokenId;
        uint256 amount;
    }

    mapping(address => ERC721Airdrop[]) addressToERC721Airdrop;
    mapping(address => ERC1155Airdrop[]) addressToERC1155Airdrop;

    IERC20Upgradeable public busdToken;
    IERC20 public ecchiCoin;
    mapping(address => uint256) public ecchiToClaim;
    mapping(address => uint256) public busdToClaim;

    /**
     * @dev Initializer
     */
    function initialize(IERC20Upgradeable _busdToken, IERC20 _ecchiCoinToken) public initializer {
        __ERC1155Holder_init();
        __ERC721Holder_init();
        __Ownable_init();
        busdToken = _busdToken;
        ecchiCoin = _ecchiCoinToken;
    }

    function calculateDistribution(uint256 _amount, uint256 _squiresLength, uint256 _knightsLength, uint256 _wizardsLength)
    internal
    pure
    returns (uint256, uint256, uint256)
    {
        // calculate distribution
        uint256 _split = _squiresLength + (_knightsLength * 2) + (_wizardsLength * 3);
        uint256 _squireValue = _amount / _split;
        uint256 _knightValue = _squireValue * 2;
        uint256 _remaining = _amount - ((_squireValue * _squiresLength) + (_knightValue * _knightsLength));
        uint256 _wizardValue = _remaining / _wizardsLength;

        return (_squireValue, _knightValue, _wizardValue);
    }

    function airdropERC721NFT(
        address[] memory _nftContract,
        uint256[] memory _tokenId,
        address[] memory _recipient
    ) public {
        require(_nftContract.length == _tokenId.length, "Invalid length");
        require(_nftContract.length == _recipient.length, "Invalid length");

        for(uint256 i = 0; i < _nftContract.length; i++) {
            IERC721Upgradeable(_nftContract[i]).safeTransferFrom(msg.sender, address(this), _tokenId[i]);

            ERC721Airdrop memory airdrop = ERC721Airdrop(_nftContract[i], _tokenId[i]);
            addressToERC721Airdrop[_recipient[i]].push(airdrop);
        }
    }

    function airdropERC1155NFT(
        address[] memory _nftContract,
        uint256[] memory _tokenId,
        uint256[] memory _amount,
        address[] memory _recipient
    ) public {
        require(_nftContract.length == _tokenId.length, "Invalid length");
        require(_nftContract.length == _amount.length, "Invalid length");
        require(_nftContract.length == _recipient.length, "Invalid length");

        for(uint256 i = 0; i < _nftContract.length; i++) {
            IERC1155Upgradeable(_nftContract[i]).safeTransferFrom(msg.sender, address(this), _tokenId[i], _amount[i], "");

            ERC1155Airdrop memory airdrop = ERC1155Airdrop(_nftContract[i], _tokenId[i], _amount[i]);
            addressToERC1155Airdrop[_recipient[i]].push(airdrop);
        }
    }

    function airdropEcchi(
        address[] memory _squires,
        address[] memory _knights,
        address[] memory _wizards,
        uint256 _amount
    ) public {
        ecchiCoin.transferFrom(msg.sender, address(this), _amount);

        // calculate distribution
        (uint256 _squireValue, uint256 _knightValue, uint256 _wizardValue) = calculateDistribution(
            _amount,
            _squires.length,
            _knights.length,
            _wizards.length
        );

        for (uint i = 0; i < _squires.length; i++) {
            ecchiToClaim[_squires[i]] += _squireValue;
        }

        for (uint i = 0; i < _knights.length; i++) {
            ecchiToClaim[_knights[i]] += _knightValue;
        }

        for (uint i = 0; i < _wizards.length; i++) {
            ecchiToClaim[_wizards[i]] += _wizardValue;
        }
    }

    function airdropBUSD(
        address[] memory _squires,
        address [] memory _knights,
        address [] memory _wizards,
        uint256 _amount
    ) public {
        busdToken.transferFrom(msg.sender, address(this), _amount);

        // calculate distribution
        (uint256 _squireValue, uint256 _knightValue, uint256 _wizardValue) = calculateDistribution(
            _amount,
            _squires.length,
            _knights.length,
            _wizards.length
        );

        for (uint i = 0; i < _squires.length; i++) {
            busdToClaim[_squires[i]] += _squireValue;
        }

        for (uint i = 0; i < _knights.length; i++) {
            busdToClaim[_knights[i]] += _knightValue;
        }

        for (uint i = 0; i < _wizards.length; i++) {
            busdToClaim[_wizards[i]] += _wizardValue;
        }
    }

    function claimEcchi(address _addressToClaim) public {
        uint256 _claimValue = ecchiToClaim[_addressToClaim];
        require(_claimValue > 0, "Nothing to claim");
        ecchiToClaim[_addressToClaim] = 0;
        ecchiCoin.transfer(_addressToClaim, _claimValue);
    }

    function claimBUSD(address _addressToClaim) public {
        uint256 _claimValue = busdToClaim[_addressToClaim];
        require(_claimValue > 0, "Nothing to claim");
        busdToClaim[_addressToClaim] = 0;
        busdToken.transfer(_addressToClaim, _claimValue);
    }

    function claimERC721(address _addressToClaim) public {
        uint256 length = addressToERC721Airdrop[_addressToClaim].length;
        require(length > 0, "Nothing to claim");

        ERC721Airdrop[] memory airdrops = addressToERC721Airdrop[_addressToClaim];
        delete addressToERC721Airdrop[_addressToClaim];

        for (uint i = 0; i < length; i++) {
             IERC721Upgradeable(airdrops[i].nftAddress).safeTransferFrom(address(this), _addressToClaim, airdrops[i].tokenId);
        }
    }

    function claimERC1155(address _addressToClaim) public {
        uint256 length = addressToERC1155Airdrop[_addressToClaim].length;
        require(length > 0, "Nothing to claim");

        ERC1155Airdrop[] memory airdrops = addressToERC1155Airdrop[_addressToClaim];
        delete addressToERC1155Airdrop[_addressToClaim];

        for (uint i = 0; i < length; i++) {
            IERC1155Upgradeable(airdrops[i].nftAddress).safeTransferFrom(
                address(this),
                _addressToClaim,
                airdrops[i].tokenId,
                airdrops[i].amount,
                ""
            );
        }
    }
}
