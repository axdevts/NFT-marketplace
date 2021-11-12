// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

contract TestTokenUpgradeable is ERC20Upgradeable {
    /**
     * @dev Initializer
     */
    function initialize() public initializer {
        __ERC20_init("TestToken", "TST");
        _mint(msg.sender, 1000000000 * 10**decimals());
    }
}
