// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC721, IERC165} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "../utils/IPancakeSwap.sol";

interface IArtistNFT {
    function getIsArtistNFT() external view returns (bool);

    function getCreator(uint256 _tokenId) external view returns (address);
}

contract SaleBase is
    IERC721Receiver,
    AccessControl,
    ERC1155Holder,
    ReentrancyGuard
{
    using Address for address payable;

    // ERC721 interface id
    bytes4 constant InterfaceSignature_ERC721 = bytes4(0x80ac58cd);

    // ERC1155 interface id
    bytes4 constant InterfaceSignature_ERC1155 = bytes4(0xd9b67a26);

    // the value will be initilized to 50 * 10**18 incase of official market and 20 * 10**6 * 10**9 incase of game market
    uint256 public numTokensSellToAddToLiquidity;

    // address of the platform wallet to which the platform cut will be sent
    address internal rewardsWalletAddress =
        address(0xC5f4461380A5e1Fed95b9A2E0474Ee64422d20d5);
    address internal serverWalletAddress =
        address(0xbf7C98F815f3aCcD7255F3595E8b27a01E336206);
    address internal maintenanceWalletAddress =
        address(0x592d9D76EC0Ee77d7407764cF501214809FFCE49);

    // cuts are in %age * 10
    uint16 public rewardsCut = 10; // 1%
    uint16 public serverCut = 5; // 0.5%
    uint16 public maintenanceCut = 5; // 0.5%
    uint16 public liquidityCut = 10; // 1%

    // tokens to add to liquidity
    uint256 public liquidityTokens;

    // address of the Artist NFT
    address public artistNFTAddress;

    // BUSD for official market and black market, EcchiCoin for game market
    IERC20 internal Token = IERC20(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56);
    // EcchiCoin for official market and black market, BUSD for game market
    IERC20 internal Token2;

    IPancakeRouter02 public constant pancakeRouter =
        IPancakeRouter02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);

    bool inSwapAndLiquify;
    bool public swapAndLiquifyEnabled = true;

    event MinTokensBeforeSwapUpdated(uint256 minTokensBeforeSwap);
    event SwapAndLiquifyEnabledUpdated(bool enabled);
    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensIntoLiqudity
    );

    modifier lockTheSwap() {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }

    /**
     * @dev Implementation of ERC721Receiver
     */
    function onERC721Received(
        address _operator,
        address _from,
        uint256 _tokenId,
        bytes memory _data
    ) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function changeFees(
        uint16 _rewardsCut,
        uint16 _serverCut,
        uint16 _maintenanceCut,
        uint16 _liquidityCut
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        rewardsCut = _rewardsCut;
        serverCut = _serverCut;
        maintenanceCut = _maintenanceCut;
        liquidityCut = _liquidityCut;
    }

    function changeWalletAddresses(
        address _rewardsWallet,
        address _serverWallet,
        address _maintenanceWallet
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        rewardsWalletAddress = _rewardsWallet;
        serverWalletAddress = _serverWallet;
        maintenanceWalletAddress = _maintenanceWallet;
    }

    function changeLiquidityTokenThreshhold(uint256 _liquidityTokenThreshhold)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        numTokensSellToAddToLiquidity = _liquidityTokenThreshhold;
    }

    /**
     * @dev Internal function to transfer the NFT from this contract to another address
     * @param _nftAddress Address of NFT
     * @param _receiver The address to send the NFT to
     * @param _tokenId ID of the token to transfer
     */
    function _transfer(
        address _nftAddress,
        address _receiver,
        uint256 _tokenId,
        bool _isERC721,
        uint256 _amount
    ) internal {
        if (_isERC721) {
            IERC721(_nftAddress).safeTransferFrom(
                address(this),
                _receiver,
                _tokenId
            );
        } else {
            IERC1155(_nftAddress).safeTransferFrom(
                address(this),
                _receiver,
                _tokenId,
                _amount,
                ""
            );
        }
    }

    /**
     * @dev Internal function that calculates the cuts of all parties and distributes the payment among them.
     * If the sale involves an ERC1155 token, the secondarySale will always be false
     * @param _seller Address of the seller
     * @param _amount The total amount to be split
     */
    function _payout(
        bool _isArtistNFT,
        uint16 _artistCut,
        address _seller,
        address _artist,
        uint256 _amount
    ) internal {
        uint256 liquidityBalance = liquidityTokens;
        bool overMinTokenBalance = liquidityBalance >=
            numTokensSellToAddToLiquidity;

        if (overMinTokenBalance && !inSwapAndLiquify && swapAndLiquifyEnabled) {
            liquidityBalance = numTokensSellToAddToLiquidity;
            //add liquidity
            swapAndLiquifyTokens(liquidityBalance);
        }

        uint256 artistAmount;
        // dividing by 1000 because percentages are multiplied by 10 for values < 1%
        uint256 serverAmount = (serverCut * _amount) / 1000;
        uint256 maintenanceAmount = (maintenanceCut * _amount) / 1000;
        uint256 rewardsAmount = (rewardsCut * _amount) / 1000;
        uint256 liquidityAmount = (liquidityCut * _amount) / 1000;

        if (_isArtistNFT) {
            artistAmount = (_artistCut * _amount) / 1000;
        }

        // calculate the amount to send to the seller
        uint256 sellerAmount = _amount -
            (serverAmount +
                maintenanceAmount +
                rewardsAmount +
                artistAmount +
                liquidityAmount);

        liquidityTokens += liquidityAmount;

        if (_isArtistNFT) {
            Token.transfer(_artist, artistAmount);
        }
        Token.transfer(_seller, sellerAmount);
        Token.transfer(serverWalletAddress, serverAmount);
        Token.transfer(maintenanceWalletAddress, maintenanceAmount);
        Token.transfer(rewardsWalletAddress, rewardsAmount);
    }

    /**
     * @dev this method is responsible for creating swap for BUSD and adding liquidity
     * @param tokenBalance Contract balance
     */
    function swapAndLiquifyTokens(uint256 tokenBalance) private lockTheSwap {
        // split the contract balance into halves
        uint256 half = tokenBalance / 2;
        uint256 otherHalf = tokenBalance - half;

        // capture the contract's current BUSD balance.
        // this is so that we can capture exactly the amount of ETH that the
        // swap creates, and not make the liquidity event include any ETH that
        // has been manually sent to the contract
        // uint256 initialBalance = address(this).balance;
        uint256 initialToken2Balance = Token2.balanceOf(address(this));

        // swap tokens for ETH
        // swapTokensForEth(half); // <- this breaks the ETH -> HATE swap when swap+liquify is triggered
        swapTokens(half); // <- this breaks the ETH -> HATE swap when swap+liquify is triggered

        // how much ETH did we just swap into?
        // uint256 newBalance = address(this).balance.sub(initialBalance);
        uint256 newToken2Balance = Token2.balanceOf(address(this)) -
            initialToken2Balance;

        // add liquidity to PancakeSwap
        // addLiquidity(otherHalf, newBalance);
        addLiquidity(otherHalf, newToken2Balance);

        emit SwapAndLiquify(half, newToken2Balance, otherHalf);
    }

    /**
     * @dev this method is responsible for swaping tokens in return of USDT
     * @param tokenAmount amount of token to swap
     */
    function swapTokens(uint256 tokenAmount) private {
        // generate the uniswap pair path of BUSD -> Ecchi
        address[] memory path = new address[](2);
        path[0] = address(Token);
        path[1] = address(Token2);

        Token.approve(address(pancakeRouter), tokenAmount);

        // make the swap
        pancakeRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of USDT
            path,
            address(this),
            block.timestamp
        );
    }

    /**
     * @dev this method is responsible for adding liquidity for USDT
     * @param tokenAmount amount of token to authorize pancakeRouter
     * @param token2Amount amount of USDT did we just swap into
     * @return uint256 amount of tokens
     * @return uint256 USDT value
     * @return uint256 The liquidity
     */
    function addLiquidity(uint256 tokenAmount, uint256 token2Amount)
        private
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        // approve token transfer to cover all possible scenarios
        Token.approve(address(pancakeRouter), tokenAmount);
        Token2.approve(address(pancakeRouter), token2Amount);

        // add the liquidity
        (uint256 amountToken, uint256 amountToken2, uint256 liquidity) = pancakeRouter
            .addLiquidity(
                address(Token),
                address(Token2),
                tokenAmount,
                token2Amount,
                0, // slippage is unavoidable
                0, // slippage is unavoidable
                address(this), //owner(), --- Fixed From Audit Report
                block.timestamp
            );

        return (amountToken, amountToken2, liquidity);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC1155Receiver, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
