// SPDX-License-Identifier: MIT

// Contains properties in which the contract should always hold

/* 
    INVARIANTS:

    1. The amount of DSC should always be overcollateralised
    2. Getter view functions should never revert

*/

pragma solidity ^0.8.21;

import {Test, console} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralisedStableCoin} from "../../src/DecentralisedStableCoin.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {IERC20} from "@openzepplin/contracts/token/ERC20/IERC20.sol";

contract OpenInvariantsTest is StdInvariant, Test {
    DeployDSC deployDSC;
    DSCEngine dscEngine;
    DecentralisedStableCoin dsc;
    HelperConfig helperConfig;
    address wethToken;
    address wbtcToken;

    function setUp() public {
        deployDSC = new DeployDSC();
        (dsc, dscEngine, helperConfig) = deployDSC.run();
        (,, wethToken, wbtcToken,) = helperConfig.activeNetworkConfig();

        StdInvariant.targetContract(address(dscEngine));
    }

    function invariant_dscMustBeOvercollateralisedAtAllTimes() public view {
        uint256 totalSupply = dsc.totalSupply();
        uint256 totalAmountOfwethDeposited = IERC20(wethToken).balanceOf(address(dscEngine));
        uint256 totalAmountOfwbtcDeposited = IERC20(wbtcToken).balanceOf(address(dscEngine));

        uint256 TotalAmountWethDepositedValUsd =
            dscEngine.getUsdValueOfCollateralAsset(wethToken, totalAmountOfwethDeposited);
        uint256 TotalAmountWbtcDepositedValUsd =
            dscEngine.getUsdValueOfCollateralAsset(wbtcToken, totalAmountOfwbtcDeposited);

        assert(totalSupply <= TotalAmountWbtcDepositedValUsd + TotalAmountWethDepositedValUsd);
    }
}
