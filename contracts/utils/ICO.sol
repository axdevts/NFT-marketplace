// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ICO is AccessControl {
    // role for whitelisting
    bytes32 public constant WHITELISTED = keccak256("WHITELISTED");
    uint256 public constant LIMIT_PER_USER = 800 ether;

    IERC20 private immutable BUSD;
    // Will be set to "250,000 * 10^18", made immutable for unit tests
    uint256 public immutable GOAL;

    // start time in UNIX timestamp
    uint256 public startTime;
    // duration of the ICO in seconds
    uint256 public duration;
    // total accumulated BUSD
    uint256 public totalAccumulated;
    // contribution of each address
    mapping(address => uint256) public addressToContribution;

    constructor(
        uint256 _goal,
        uint256 _startTime,
        uint256 _duration,
        address _BUSDAddress,
        address[] memory _whitelisted
    ) {
        // set the goal
        GOAL = _goal;
        // make default admin
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);

        // grant whitelist previleges
        for (uint256 i = 0; i < _whitelisted.length; i++) {
            grantRole(WHITELISTED, _whitelisted[i]);
        }

        BUSD = IERC20(_BUSDAddress);
        startTime = _startTime;
        duration = _duration;
    }

    function contribute(uint256 _amount) external onlyRole(WHITELISTED) {
        // check ICO time limit
        require(block.timestamp >= startTime, "ICO not started");
        require(block.timestamp <= startTime + duration, "ICO ended");

        // check if target has been met
        require(
            totalAccumulated + _amount <= GOAL,
            "Contribution exceeds goal"
        );

        // must be one of the 3 options
        require(_amount > 0 && _amount % 100 ether == 0 && _amount <= 800 ether, "Incorrect amount");
        require(
            addressToContribution[msg.sender] + _amount <= LIMIT_PER_USER,
            "Max limit reached"
        );

        totalAccumulated += _amount;
        addressToContribution[msg.sender] += _amount;

        BUSD.transferFrom(msg.sender, address(this), _amount);
    }

    function withdraw() external onlyRole(DEFAULT_ADMIN_ROLE) {
        // can only withdraw after ICO ends
        require(
            block.timestamp >= startTime + duration || totalAccumulated == GOAL,
            "ICO in progress"
        );
        BUSD.transfer(msg.sender, totalAccumulated);
    }

    function whitelist(address[] memory _whitelist)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        for (uint256 i = 0; i < _whitelist.length; i++) {
            grantRole(WHITELISTED, _whitelist[i]);
        }
    }
}
