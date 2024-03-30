// SPDX-License-Identifier: MIT

pragma solidity ^0.8.21;

import {ERC20Burnable, ERC20} from "@openzepplin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzepplin/contracts/access/Ownable.sol";

contract MockFailedTransferFrom is ERC20Burnable, Ownable {
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

    function mint(address _to, uint256 _amount) external onlyOwner returns (bool) {
        if (_to == address(0)) {
            revert DecentralisedStableCoin__MintToAddressZero();
        }
        if (_amount <= 0) {
            revert DecentralisedStableCoin__MintAmountMustBeGreaterThanZero();
        }

        _mint(_to, _amount);
        return true;
    }

    function transferFrom(address, /*_from*/ address, /*_to*/ uint256 /*_amount*/ )
        public
        pure
        override
        returns (bool)
    {
        return false;
    }
}
