// SPDX-License-Identifier: MIT

pragma solidity ^0.8.21;

import {ERC20Burnable, ERC20} from "@openzepplin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzepplin/contracts/access/Ownable.sol";

/**
 * @title DecentralisedStableCoin
 * @author MGM103
 * @notice This contract is goverened by the DSCEngine contract. This contract is the ERC-20 implementation of the stable coin.
 *
 * Collateral: wETH & wBTC
 * Minting: Algorithmic
 * Relative Stability: Pegged to $1.00 US
 *
 */
contract DecentralisedStableCoin is ERC20Burnable, Ownable {
    error DecentralisedStableCoin__BurnAmountMustBeGreaterThanZero();
    error DecentralisedStableCoin__InsufficientBalanceForBurn();
    error DecentralisedStableCoin__MintAmountMustBeGreaterThanZero();
    error DecentralisedStableCoin__MintToAddressZero();

    constructor() ERC20("Decentralised Stable Coin", "DSC") {}

    function burn(uint256 _amount) public override onlyOwner {
        uint256 balance = balanceOf(msg.sender);

        if (_amount == 0)
            revert DecentralisedStableCoin__BurnAmountMustBeGreaterThanZero();
        if (balance < _amount)
            revert DecentralisedStableCoin__InsufficientBalanceForBurn();

        super.burn(_amount);
    }

    function mint(
        address _to,
        uint256 _amount
    ) external onlyOwner returns (bool) {
        if (_to == address(0))
            revert DecentralisedStableCoin__MintToAddressZero();
        if (_amount <= 0)
            revert DecentralisedStableCoin__MintAmountMustBeGreaterThanZero();

        _mint(_to, _amount);
        return true;
    }
}
