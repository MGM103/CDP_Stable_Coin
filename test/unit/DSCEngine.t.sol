// SPDX-License-Identifier: MIT

pragma solidity ^0.8.21;

import {Test, console} from "forge-std/Test.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralisedStableCoin} from "../../src/DecentralisedStableCoin.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzepplin/contracts/mocks/ERC20Mock.sol";

contract DSCEngineTest is Test {
    address USER = makeAddr("USER");
    uint256 public constant AMOUNT_OF_COLLATERAL = 10 ether;
    uint256 public constant START_WETH_BAL = 20 ether;
    uint256 public constant WETH_PRICE = 4000e18;

    DeployDSC deployerDSC;
    HelperConfig helperConfig;
    DSCEngine dscEngine;
    DecentralisedStableCoin dsc;
    address wethToken;
    address wethUsdPriceFeed;
    address btcUsdPriceFeed;

    function setUp() public {
        deployerDSC = new DeployDSC();
        (dsc, dscEngine, helperConfig) = deployerDSC.run();

        (wethUsdPriceFeed, btcUsdPriceFeed, wethToken,,) = helperConfig.activeNetworkConfig();
        ERC20Mock(wethToken).mint(USER, START_WETH_BAL);
    }

    ///////////////////////////
    /////CONSTRUCTOR TESTS/////
    address[] tokenAddresses;
    address[] priceFeedAddresses;

    function testRevertsIfTokenAndPriceFeedLengthsAreNotEqual() public {
        tokenAddresses.push(wethToken);
        priceFeedAddresses.push(wethUsdPriceFeed);
        priceFeedAddresses.push(btcUsdPriceFeed);

        vm.expectRevert(DSCEngine.DSCEngine__InvalidCollateralConstructorParams.selector);
        new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc));
    }

    /////////////////////////////
    /////TESTING PRICE FEEDS/////
    function testGetUsdValueOfCollateralAsset() public {
        uint256 amountOfEth = 10e18; // 10 ETH collateral
        uint256 expectedUsdValueOfCollateral = 40000e18; // amount * price ($4000)
        uint256 actualUsdValueOfCollateral = dscEngine.getUsdValueOfCollateralAsset(wethToken, amountOfEth);

        assertEq(actualUsdValueOfCollateral, expectedUsdValueOfCollateral);
    }

    function testGetTokenAmountFromUsdValue() public {
        uint256 usdValue = WETH_PRICE; // $4000 usd
        uint256 expectedWethAmount = 1 ether;
        uint256 wethAmount = dscEngine.getTokenAmountFromUsdValue(wethToken, usdValue);

        assertEq(wethAmount, expectedWethAmount);
    }

    ///////////////////////////////
    /////DEPOSITING COLLATERAL/////
    function testDepositCollateralRevertsWhenZeroCollateralDeposited() public {
        vm.startPrank(USER);
        ERC20Mock(wethToken).approve(address(dscEngine), AMOUNT_OF_COLLATERAL);

        vm.expectRevert(DSCEngine.DSCEngine__RequiresMoreThanZero.selector);
        dscEngine.depositCollateral(wethToken, 0);
        vm.stopPrank();
    }

    function testRevertsIfCollateralNotPermitted() public {
        ERC20Mock invalidCollateral = new ERC20Mock("Invalid Collateral", "INVALID", USER, AMOUNT_OF_COLLATERAL);
        vm.startPrank(USER);
        vm.expectRevert(
            abi.encodeWithSelector(DSCEngine.DSCEngine__CollateralIsNotPermitted.selector, address(invalidCollateral))
        );
        dscEngine.depositCollateral(address(invalidCollateral), AMOUNT_OF_COLLATERAL);
        vm.stopPrank();
    }

    modifier depositedCollateral() {
        vm.startPrank(USER);
        ERC20Mock(wethToken).approve(address(dscEngine), AMOUNT_OF_COLLATERAL);
        dscEngine.depositCollateral(wethToken, AMOUNT_OF_COLLATERAL);
        vm.stopPrank();
        _;
    }

    function testUserDepositAndCDPInfoUpdated() public depositedCollateral {
        (uint256 dscMintedBal, uint256 collateralValUsd) = dscEngine.getCDPInformation(USER);
        uint256 expectedDscMintedBal = 0;
        uint256 expectedCollateralValUsd = dscEngine.getUsdValueOfCollateralAsset(wethToken, AMOUNT_OF_COLLATERAL);

        assertEq(dscMintedBal, expectedDscMintedBal);
        assertEq(collateralValUsd, expectedCollateralValUsd);
    }
}
