// SPDX-License-Identifier: MIT

pragma solidity ^0.8.21;

import {ERC20Burnable, ERC20} from "@openzepplin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzepplin/contracts/access/Ownable.sol";

contract MockFailedMint is ERC20Burnable, Ownable {
    // ERRORS
    error DecentralisedStableCoin__BurnAmountMustBeGreaterThanZero();
    error DecentralisedStableCoin__InsufficientBalanceForBurn();
    error DecentralisedStableCoin__MintAmountMustBeGreaterThanZero();
    error DecentralisedStableCoin__MintToAddressZero();

    // FUNCTIONS
    constructor() ERC20("Decentralised Stable Coin", "DSC") {}

    function burn(uint256 _amount) public override onlyOwner {
        uint256 balance = balanceOf(msg.sender);

        if (_amount == 0) {
            revert DecentralisedStableCoin__BurnAmountMustBeGreaterThanZero();
        }
        if (balance < _amount) {
            revert DecentralisedStableCoin__InsufficientBalanceForBurn();
        }

        super.burn(_amount);
    }

    function mint(address, /* _to*/ uint256 /*_amount8*/ ) external view onlyOwner returns (bool) {
        return false;
    }
}
