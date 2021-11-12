// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155Upgradeable.sol";

interface IERC1155CollectibleUpgradeable is IERC1155Upgradeable {
    function burn(
        address account,
        uint256 id,
        uint256 value
    ) external;
}
