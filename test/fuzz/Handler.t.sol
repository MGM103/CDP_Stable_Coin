// SPDX-License-Identifier: MIT

// Defines the way in which functions are called to ensure there are no wasted runs

pragma solidity ^0.8.21;

import {Test, console} from "forge-std/Test.sol";
import {ERC20Mock} from "@openzepplin/contracts/mocks/ERC20Mock.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralisedStableCoin} from "../../src/DecentralisedStableCoin.sol";

contract Handler is Test {
    DSCEngine dscEngine;
    DecentralisedStableCoin dsc;
    ERC20Mock wethToken;
    ERC20Mock wbtcToken;

    uint256 private constant MAX_DEPOSIT_AMOUNT = type(uint96).max;
    address[] public knownDepositors;

    constructor(DSCEngine _dscEngine, DecentralisedStableCoin _dsc) {
        dscEngine = _dscEngine;
        dsc = _dsc;

        address[] memory permittedCollateralTokens = dscEngine.getPermittedCollateralTokens();
        wethToken = ERC20Mock(permittedCollateralTokens[0]);
        wbtcToken = ERC20Mock(permittedCollateralTokens[1]);
    }

    ///////////////////////
    // HANDLER FUNCTIONS //
    ///////////////////////
    function depositCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
        ERC20Mock collateralType = _getCollateralTypeFromSeed(collateralSeed);
        amountCollateral = bound(amountCollateral, 1, MAX_DEPOSIT_AMOUNT);

        vm.startPrank(msg.sender);
        collateralType.mint(msg.sender, amountCollateral);
        collateralType.approve(address(dscEngine), amountCollateral);
        dscEngine.depositCollateral(address(collateralType), amountCollateral);
        vm.stopPrank();

        knownDepositors.push(msg.sender); // Allows duplicate addresses currently
    }

    function redeemCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
        ERC20Mock collateralType = _getCollateralTypeFromSeed(collateralSeed);
        uint256 maxCollateralAmtRedeem =
            dscEngine.getUserCollateralTypeDepositAmount(msg.sender, address(collateralType));
        amountCollateral = bound(amountCollateral, 0, maxCollateralAmtRedeem);

        if (amountCollateral == 0) return; // Prevent 0 reversion

        dscEngine.redeemCollateral(address(collateralType), amountCollateral);
    }

    function mintDsc(uint256 amountDsc, uint256 userSeed) public {
        address user = _getKnownDepositor(userSeed);
        if (user == address(0)) return; // If user not found exit

        (uint256 amountDscMinted, uint256 amountCollateralValInUsd) = dscEngine.getCDPInformation(user);
        int256 maxMintAmount = int256(amountCollateralValInUsd / 2) - int256(amountDscMinted);

        if (maxMintAmount < 0) return; // If CDP underwater exit

        amountDsc = bound(amountDsc, 0, uint256(maxMintAmount));
        if (amountDsc == 0) return; // Prevent 0 reversion

        vm.startPrank(user);
        dscEngine.mintDsc(amountDsc);
        vm.stopPrank();
    }

    //////////////////////
    // HELPER FUNCTIONS //
    //////////////////////
    function _getCollateralTypeFromSeed(uint256 collateralSeed) private view returns (ERC20Mock) {
        if (collateralSeed % 2 == 0) {
            return wethToken;
        }
        return wbtcToken;
    }

    function _getKnownDepositor(uint256 depositorSeed) private view returns (address) {
        if (knownDepositors.length == 0) return address(0); // Prevent reversion on empty array
        return knownDepositors[depositorSeed % knownDepositors.length];
    }
}
