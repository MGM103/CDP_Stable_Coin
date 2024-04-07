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
import {Handler} from "./Handler.t.sol";

contract OpenInvariantsTest is StdInvariant, Test {
    DeployDSC deployDSC;
    DSCEngine dscEngine;
    DecentralisedStableCoin dsc;
    HelperConfig helperConfig;
    Handler handler;
    address wethToken;
    address wbtcToken;

    function setUp() public {
        deployDSC = new DeployDSC();
        (dsc, dscEngine, helperConfig) = deployDSC.run();
        (,, wethToken, wbtcToken,) = helperConfig.activeNetworkConfig();

        handler = new Handler(dscEngine, dsc);

        // StdInvariant.targetContract(address(dscEngine));
        StdInvariant.targetContract(address(handler));
    }

    function invariant_dscMustBeOvercollateralisedAtAllTimes() public view {
        uint256 totalSupply = dsc.totalSupply();
        uint256 totalAmountOfwethDeposited = IERC20(wethToken).balanceOf(address(dscEngine));
        uint256 totalAmountOfwbtcDeposited = IERC20(wbtcToken).balanceOf(address(dscEngine));

        uint256 totalAmountWethDepositedValUsd =
            dscEngine.getUsdValueOfCollateralAsset(wethToken, totalAmountOfwethDeposited);
        uint256 totalAmountWbtcDepositedValUsd =
            dscEngine.getUsdValueOfCollateralAsset(wbtcToken, totalAmountOfwbtcDeposited);

        console.log("weth value: ", totalAmountWethDepositedValUsd);
        console.log("wbtc value: ", totalAmountWbtcDepositedValUsd);
        console.log("Total Dsc supply: ", totalSupply);

        assert(totalSupply <= totalAmountWbtcDepositedValUsd + totalAmountWethDepositedValUsd);
    }
}
