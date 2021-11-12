// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155BurnableUpgradeable.sol";

contract EcchiGameCurrencyUpgradeable is ERC1155Upgradeable, OwnableUpgradeable, ERC1155BurnableUpgradeable {
    uint256 public constant GOLD_COIN = 1;
    uint256 public constant COMMON_SILVER_SHARD = 2;
    uint256 public constant POWERED_SILVER_SHARD = 3;
    uint256 public constant COMMON_GOLD_SHARD = 4;
    uint256 public constant POWERED_GOLD_SHARD = 5;

    address private upgradeContract;

    /**
     * @dev Initializer
     */
    function initialize() public initializer{
        __ERC1155_init("https://something.com/{id}");
        __Ownable_init();
        __ERC1155Burnable_init();
    }

    function setUpgradeContract(address _upgradeContract) public onlyOwner {
        upgradeContract = _upgradeContract;
    }

    function setURI(string memory newUri) public onlyOwner {
        _setURI(newUri);
    }

    function mint(
        address account,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public onlyOwner {
        setApprovalForAll(upgradeContract, true);
        _mint(account, id, amount, data);
    }

    function mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public onlyOwner {
        _mintBatch(to, ids, amounts, data);
    }
}
