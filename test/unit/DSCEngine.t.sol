// SPDX-License-Identifier: MIT

pragma solidity ^0.8.21;

import {Test, console} from "forge-std/Test.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralisedStableCoin} from "../../src/DecentralisedStableCoin.sol";
import {MockFailedTransfer} from "../mocks/MockFailedTransfer.sol";
import {MockFailedTransferFrom} from "../mocks/MockFailedTransferFrom.sol";
import {MockFailedMint} from "../mocks/MockFailedMint.sol";
import {MockDecreaseHealthFactorDSC} from "../mocks/MockDecreaseHealthFactorDSC.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzepplin/contracts/mocks/ERC20Mock.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";

contract DSCEngineTest is Test {
    // CONSTANTS
    address USER = makeAddr("USER");
    address LIQUIDATOR = makeAddr("LIQUIDATOR");
    uint256 public constant AMOUNT_OF_COLLATERAL = 10 ether;
    uint256 public constant START_WETH_BAL = 20 ether;
    uint256 public constant DEBT_TO_COVER = 20000 ether;
    uint256 public constant WETH_PRICE = 4000e18;

    // STATE VARIABLES
    DeployDSC deployerDSC;
    HelperConfig helperConfig;
    DSCEngine dscEngine;
    DecentralisedStableCoin dsc;
    address wethToken;
    address wethUsdPriceFeed;
    address btcUsdPriceFeed;

    // EVENTS
    event CollateralDeposited(address indexed user, address indexed collateralToken, uint256 indexed amountCollateral);
    event CollateralRedeemed(
        address indexed redeemedFrom,
        address indexed redeemedTo,
        address indexed collateralToken,
        uint256 amountCollateral
    );

    function setUp() public {
        deployerDSC = new DeployDSC();
        (dsc, dscEngine, helperConfig) = deployerDSC.run();

        (wethUsdPriceFeed, btcUsdPriceFeed, wethToken,,) = helperConfig.activeNetworkConfig();
        ERC20Mock(wethToken).mint(USER, START_WETH_BAL);
    }

    ///////////////////////
    // CONSTRUCTOR TESTS //
    ///////////////////////
    address[] tokenAddresses;
    address[] priceFeedAddresses;

    function testRevertsIfTokenAndPriceFeedLengthsAreNotEqual() public {
        tokenAddresses.push(wethToken);
        priceFeedAddresses.push(wethUsdPriceFeed);
        priceFeedAddresses.push(btcUsdPriceFeed);

        vm.expectRevert(DSCEngine.DSCEngine__InvalidCollateralConstructorParams.selector);
        new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc));
    }

    /////////////////////////
    // TESTING PRICE FEEDS //
    /////////////////////////
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

    ///////////////////////////
    // DEPOSITING COLLATERAL //
    ///////////////////////////
    function testDepositRevertsIfTransferFromFails() public {
        address owner = msg.sender;

        // Mock DSC setup
        vm.startPrank(owner);
        MockFailedTransferFrom mockDsc = new MockFailedTransferFrom();
        mockDsc.mint(USER, AMOUNT_OF_COLLATERAL);
        vm.stopPrank();

        // Mock DSC Engine setup
        tokenAddresses = [address(mockDsc)];
        priceFeedAddresses = [wethUsdPriceFeed];

        vm.startPrank(owner);
        DSCEngine mockDscEngine = new DSCEngine(tokenAddresses, priceFeedAddresses, address(mockDsc));
        mockDsc.transferOwnership(address(mockDscEngine));
        vm.stopPrank();

        // Test transferFrom() fails
        vm.startPrank(USER);
        ERC20Mock(address(mockDsc)).approve(address(mockDscEngine), AMOUNT_OF_COLLATERAL);
        vm.expectRevert(
            abi.encodeWithSelector(
                DSCEngine.DSCEngine__CollateralDepositTransferFailed.selector, address(mockDsc), AMOUNT_OF_COLLATERAL
            )
        );
        mockDscEngine.depositCollateral(address(mockDsc), AMOUNT_OF_COLLATERAL);
        vm.stopPrank();
    }

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

    function testCollateralDepositEventEmitted() public {
        vm.startPrank(USER);
        ERC20Mock(wethToken).approve(address(dscEngine), AMOUNT_OF_COLLATERAL);
        vm.expectEmit();
        emit CollateralDeposited(USER, wethToken, AMOUNT_OF_COLLATERAL);
        dscEngine.depositCollateral(wethToken, AMOUNT_OF_COLLATERAL);
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

    function testHealthFactorAfterDeposit() public depositedCollateral {
        (uint256 dscMintedBal, uint256 collateralValUsd) = dscEngine.getCDPInformation(USER);
        uint256 expectedHealthFactor = type(uint256).max;

        uint256 healthFactor = dscEngine.calcHealthFactor(collateralValUsd, dscMintedBal);
        assertEq(healthFactor, expectedHealthFactor);
    }

    //////////////
    // MINT DSC //
    //////////////
    function testMintDSCRevertsIfZeroDSCMinted() public {
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__RequiresMoreThanZero.selector);
        dscEngine.mintDsc(0);
        vm.stopPrank();
    }

    function testMintDscUpdatesUserDscMintedAmount() public depositedCollateral {
        vm.startPrank(USER);
        dscEngine.mintDsc(2 ether);
        vm.stopPrank();

        (uint256 dscMinted,) = dscEngine.getCDPInformation(USER);
        assertEq(dscMinted, 2 ether);
    }

    function testRevertsIfMintInvalidatesHealthFactor() public depositedCollateral {
        uint256 dscMintAmount = 40001 ether;
        (, uint256 collateralValUsd) = dscEngine.getCDPInformation(USER);
        uint256 expectedHealthFactor = dscEngine.calcHealthFactor(collateralValUsd, dscMintAmount);

        vm.startPrank(USER);
        vm.expectRevert(
            abi.encodeWithSelector(
                DSCEngine.DSCEngine__HealthFactorThresholdInsufficient.selector, expectedHealthFactor
            )
        );
        dscEngine.mintDsc(dscMintAmount);
        vm.stopPrank();
    }

    function testRevertsIfMintFails() public {
        address owner = msg.sender;

        // Mock DSC setup
        vm.prank(owner);
        MockFailedMint mockDsc = new MockFailedMint();

        // Mock DSC Engine setup
        tokenAddresses = [wethToken];
        priceFeedAddresses = [wethUsdPriceFeed];

        vm.startPrank(owner);
        DSCEngine mockDscEngine = new DSCEngine(tokenAddresses, priceFeedAddresses, address(mockDsc));
        mockDsc.transferOwnership(address(mockDscEngine));
        vm.stopPrank();

        vm.startPrank(USER);
        ERC20Mock(address(wethToken)).approve(address(mockDscEngine), AMOUNT_OF_COLLATERAL);
        mockDscEngine.depositCollateral(wethToken, AMOUNT_OF_COLLATERAL);
        vm.stopPrank();

        // Test mint() fails from dsc contract during mint
        uint256 amountDscToMint = 10000 ether;
        vm.prank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__DscMintFailed.selector);
        mockDscEngine.mintDsc(amountDscToMint);
    }

    ////////////////////////
    // DEPOSIT & MINT DSC //
    ////////////////////////
    function testRevertsDepositAndMintIfMintBreaksHealthFactor() public {
        uint256 amountDscToMint = 25000 ether;
        uint256 priceUsdCollateralDeposit = dscEngine.getUsdValueOfCollateralAsset(wethToken, AMOUNT_OF_COLLATERAL);
        uint256 expectedHealthFactor = dscEngine.calcHealthFactor(priceUsdCollateralDeposit, amountDscToMint);

        vm.startPrank(USER);
        ERC20Mock(wethToken).approve(address(dscEngine), AMOUNT_OF_COLLATERAL);
        vm.expectRevert(
            abi.encodeWithSelector(
                DSCEngine.DSCEngine__HealthFactorThresholdInsufficient.selector, expectedHealthFactor
            )
        );
        dscEngine.depositCollateralAndMintDsc(wethToken, AMOUNT_OF_COLLATERAL, amountDscToMint);
        vm.stopPrank();
    }

    modifier depositedCollateralAndMintedDsc() {
        uint256 amountDscToMint = 20000 ether;
        vm.startPrank(USER);
        ERC20Mock(wethToken).approve(address(dscEngine), AMOUNT_OF_COLLATERAL);
        dscEngine.depositCollateralAndMintDsc(wethToken, AMOUNT_OF_COLLATERAL, amountDscToMint);
        vm.stopPrank();
        _;
    }

    function testDepositAndMintUpdatesBals() public depositedCollateralAndMintedDsc {
        uint256 amountDscHeld = ERC20Mock(address(dsc)).balanceOf(USER);
        uint256 collateralDepositedValInUsd = dscEngine.getUsdValueOfCollateralAsset(wethToken, AMOUNT_OF_COLLATERAL);
        (uint256 dscAmountMinted, uint256 collateralValueInUsd) = dscEngine.getCDPInformation(USER);

        assertEq(amountDscHeld, dscAmountMinted);
        assertEq(collateralDepositedValInUsd, collateralValueInUsd);
    }

    ///////////////////////
    // REDEEM COLLATERAL //
    ///////////////////////
    function testRedeemCollateralRevertsWhenZeroCollateralRedeemed() public depositedCollateral {
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__RequiresMoreThanZero.selector);
        dscEngine.redeemCollateral(msg.sender, 0);
        vm.stopPrank();
    }

    function testRedeemCollateralEmitsEventAndUpdatesUserBal() public depositedCollateral {
        vm.startPrank(USER);
        vm.expectEmit();
        emit CollateralRedeemed(USER, USER, wethToken, AMOUNT_OF_COLLATERAL);
        dscEngine.redeemCollateral(wethToken, AMOUNT_OF_COLLATERAL);
        vm.stopPrank();

        uint256 wethCollateralBal = dscEngine.getUserCollateralTypeDepositAmount(USER, wethToken);
        assertEq(wethCollateralBal, 0);
        assertEq(ERC20Mock(wethToken).balanceOf(USER), START_WETH_BAL);
    }

    function testRevertsIfRedemptionBreaksHealthFactor() public depositedCollateralAndMintedDsc {
        uint256 redemptionAmount = 1 ether;
        uint256 collateralUsdValAfterRedemption =
            dscEngine.getUsdValueOfCollateralAsset(wethToken, AMOUNT_OF_COLLATERAL - redemptionAmount);
        (uint256 dscAmountMinted,) = dscEngine.getCDPInformation(USER);
        uint256 expectedHealthFactor = dscEngine.calcHealthFactor(collateralUsdValAfterRedemption, dscAmountMinted);

        vm.startPrank(USER);
        vm.expectRevert(
            abi.encodeWithSelector(
                DSCEngine.DSCEngine__HealthFactorThresholdInsufficient.selector, expectedHealthFactor
            )
        );
        dscEngine.redeemCollateral(wethToken, redemptionAmount);
        vm.stopPrank();
    }

    function testRedeemCollateralRevertsIfCollateralInvalid() public depositedCollateralAndMintedDsc {
        vm.startPrank(USER);
        ERC20Mock mockUsdc = new ERC20Mock("USD Circle", "USDC", USER, 100000 ether);

        vm.expectRevert(
            abi.encodeWithSelector(DSCEngine.DSCEngine__CollateralIsNotPermitted.selector, address(mockUsdc))
        );
        dscEngine.redeemCollateral(address(mockUsdc), AMOUNT_OF_COLLATERAL);
        vm.stopPrank();
    }

    function testRedeemRevertsIfTransferFails() public {
        address owner = msg.sender;

        // Mock DSC setup
        vm.startPrank(owner);
        MockFailedTransfer mockDsc = new MockFailedTransfer();
        mockDsc.mint(USER, AMOUNT_OF_COLLATERAL);
        vm.stopPrank();

        // Mock DSC Engine setup
        tokenAddresses = [address(mockDsc)];
        priceFeedAddresses = [wethUsdPriceFeed];

        vm.startPrank(owner);
        DSCEngine mockDscEngine = new DSCEngine(tokenAddresses, priceFeedAddresses, address(mockDsc));
        mockDsc.transferOwnership(address(mockDscEngine));
        vm.stopPrank();

        vm.startPrank(USER);
        ERC20Mock(address(mockDsc)).approve(address(mockDscEngine), AMOUNT_OF_COLLATERAL);
        mockDscEngine.depositCollateral(address(mockDsc), AMOUNT_OF_COLLATERAL);
        vm.stopPrank();

        // Test transfer() fails from dsc contract during mint
        vm.prank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__TransferFailed.selector);
        mockDscEngine.redeemCollateral(address(mockDsc), AMOUNT_OF_COLLATERAL);
    }

    //////////////
    // BURN DSC //
    //////////////
    function testBurnRevertsIfAmountZero() public depositedCollateralAndMintedDsc {
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__RequiresMoreThanZero.selector);
        dscEngine.burnDsc(0);
        vm.stopPrank();
    }

    function testBurnUpdatesUserDscBal() public depositedCollateralAndMintedDsc {
        uint256 expectedDscAmount = 0 ether;
        uint256 expectedHealthFactor = type(uint256).max;
        (uint256 dscAmount,) = dscEngine.getCDPInformation(USER);

        vm.startPrank(USER);
        ERC20Mock(address(dsc)).approve(address(dscEngine), dscAmount);
        dscEngine.burnDsc(dscAmount);
        vm.stopPrank();

        (uint256 finalDscAmount,) = dscEngine.getCDPInformation(USER);
        uint256 healthFactor = dscEngine.getHealthFactor(USER);

        assertEq(finalDscAmount, expectedDscAmount);
        assertEq(healthFactor, expectedHealthFactor);
    }

    function testCannotBurnMoreDscThanHeld() public depositedCollateralAndMintedDsc {
        (uint256 dscMinted,) = dscEngine.getCDPInformation(USER);
        vm.prank(USER);
        vm.expectRevert();
        dscEngine.burnDsc(dscMinted + 1 ether);
    }

    ///////////////////////////////
    // REDEEM COLLATERAL FOR DSC //
    ///////////////////////////////
    function testRedeemForDscRevertsWhenCollateralTypeInvalid() public depositedCollateralAndMintedDsc {
        (uint256 dscAmountMinted,) = dscEngine.getCDPInformation(USER);

        vm.startPrank(USER);
        ERC20Mock mockUsdc = new ERC20Mock("USD Circle", "USDC", USER, 100000 ether);

        vm.expectRevert(
            abi.encodeWithSelector(DSCEngine.DSCEngine__CollateralIsNotPermitted.selector, address(mockUsdc))
        );
        dscEngine.redeemCollateralForDsc(address(mockUsdc), AMOUNT_OF_COLLATERAL, dscAmountMinted);
        vm.stopPrank();
    }

    function testRedeemForDscRevertsWhenCollateralAmountZero() public depositedCollateralAndMintedDsc {
        vm.prank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__RequiresMoreThanZero.selector);
        dscEngine.redeemCollateralForDsc(wethToken, 0, AMOUNT_OF_COLLATERAL);
    }

    function testRedeemForDscUpdatesUserBals() public depositedCollateralAndMintedDsc {
        (uint256 dscAmountMinted, uint256 collateralValInUsd) = dscEngine.getCDPInformation(USER);

        vm.startPrank(USER);
        ERC20Mock(address(dsc)).approve(address(dscEngine), dscAmountMinted);
        dscEngine.redeemCollateralForDsc(wethToken, AMOUNT_OF_COLLATERAL, dscAmountMinted);
        vm.stopPrank();

        (dscAmountMinted, collateralValInUsd) = dscEngine.getCDPInformation(USER);
        assertEq(dscAmountMinted, 0 ether);
        assertEq(collateralValInUsd, 0 ether);
        assertEq(ERC20Mock(address(wethToken)).balanceOf(USER), START_WETH_BAL);
    }

    ///////////////
    // LIQUIDATE //
    ///////////////
    function testLiquidateRevertsIfAmountZero() public {
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__RequiresMoreThanZero.selector);
        dscEngine.liquidate(wethToken, USER, 0);
        vm.stopPrank();
    }

    function testLiquidateRevertsIfCDPHealthy() public depositedCollateralAndMintedDsc {
        // uint256 debtToCover = 1000 ether;
        ERC20Mock(address(wethToken)).mint(LIQUIDATOR, AMOUNT_OF_COLLATERAL);

        vm.startPrank(LIQUIDATOR);
        ERC20Mock(wethToken).approve(address(dscEngine), AMOUNT_OF_COLLATERAL);
        dscEngine.depositCollateralAndMintDsc(wethToken, AMOUNT_OF_COLLATERAL, DEBT_TO_COVER);
        vm.expectRevert(DSCEngine.DSCEngine__PositionNotLiquidatable.selector);
        dscEngine.liquidate(wethToken, USER, DEBT_TO_COVER);
        vm.stopPrank();
    }

    function testMustImproveHealthFactorOnLiquidation() public {
        address owner = msg.sender;
        uint256 dscMintAmount = 100 ether; // Amount dsc minted by user & liquidator
        uint256 debtToCover = 20 ether; // Debt re-paid by liquidator
        int256 ethUsdNewPrice = 18e8; // 1 ETH = $18
        uint256 collateralToCover = 1 ether; // Collateral deposited by liquidator

        // Mock DSC setup
        vm.prank(owner);
        MockDecreaseHealthFactorDSC mockDsc = new MockDecreaseHealthFactorDSC(wethUsdPriceFeed);

        // Mock DSC Engine setup
        tokenAddresses = [wethToken];
        priceFeedAddresses = [wethUsdPriceFeed];
        vm.startPrank(owner);
        DSCEngine mockDscEngine = new DSCEngine(tokenAddresses, priceFeedAddresses, address(mockDsc));
        mockDsc.transferOwnership(address(mockDscEngine));
        vm.stopPrank();

        // User CDP setup
        vm.startPrank(USER);
        ERC20Mock(wethToken).approve(address(mockDscEngine), AMOUNT_OF_COLLATERAL);
        mockDscEngine.depositCollateralAndMintDsc(wethToken, AMOUNT_OF_COLLATERAL, dscMintAmount);
        vm.stopPrank();

        // Liquidator collateral setup
        ERC20Mock(wethToken).mint(LIQUIDATOR, collateralToCover);

        // Liquidate User Position Setup
        vm.startPrank(LIQUIDATOR);
        ERC20Mock(wethToken).approve(address(mockDscEngine), collateralToCover);
        mockDscEngine.depositCollateralAndMintDsc(wethToken, collateralToCover, dscMintAmount);
        mockDsc.approve(address(mockDscEngine), debtToCover);

        // Update price to lower val to decrease health factor below threshold
        MockV3Aggregator(wethUsdPriceFeed).updateAnswer(ethUsdNewPrice);

        // Execute Liquidation
        vm.expectRevert(DSCEngine.DSCEngine__LiquidationDidNotImproveHealthFactor.selector);
        mockDscEngine.liquidate(wethToken, USER, debtToCover);
        vm.stopPrank();
    }

    modifier liquidated() {
        uint256 amountDscToMint = 20000 ether;
        int256 wethUsdNewPrice = 3999e8;

        // Setup user CDP
        vm.startPrank(USER);
        ERC20Mock(wethToken).approve(address(dscEngine), AMOUNT_OF_COLLATERAL);
        dscEngine.depositCollateralAndMintDsc(wethToken, AMOUNT_OF_COLLATERAL, amountDscToMint);
        vm.stopPrank();

        // Decrease the price of weth and bring the health factor below min threshold
        uint256 userHealthFactor = dscEngine.getHealthFactor(USER);
        MockV3Aggregator(wethUsdPriceFeed).updateAnswer(wethUsdNewPrice);
        userHealthFactor = dscEngine.getHealthFactor(USER);

        // Mint DSC and liquidate the user
        vm.startPrank(LIQUIDATOR);
        ERC20Mock(wethToken).mint(LIQUIDATOR, START_WETH_BAL);
        ERC20Mock(wethToken).approve(address(dscEngine), START_WETH_BAL);
        dscEngine.depositCollateralAndMintDsc(wethToken, START_WETH_BAL, amountDscToMint);
        dsc.approve(address(dscEngine), DEBT_TO_COVER);
        dscEngine.liquidate(wethToken, USER, DEBT_TO_COVER);
        vm.stopPrank();
        _;
    }

    function testLiquidationPayoutIsCorrect() public liquidated {
        uint256 liquidatorWethBal = ERC20Mock(wethToken).balanceOf(LIQUIDATOR);
        uint256 expectedPayout = dscEngine.getTokenAmountFromUsdValue(wethToken, DEBT_TO_COVER)
            + (dscEngine.getTokenAmountFromUsdValue(wethToken, DEBT_TO_COVER) / dscEngine.getLiquidationBonusPercentage());

        assertEq(liquidatorWethBal, expectedPayout);
    }

    function testUserStillHasCDP() public liquidated {
        uint256 liquidatedCollateralAmount = dscEngine.getTokenAmountFromUsdValue(wethToken, DEBT_TO_COVER)
            + (dscEngine.getTokenAmountFromUsdValue(wethToken, DEBT_TO_COVER) / dscEngine.getLiquidationBonusPercentage());
        uint256 expectedCollateralAmount = AMOUNT_OF_COLLATERAL - liquidatedCollateralAmount;
        uint256 expectedDscAmount = 0 ether;
        (uint256 remainingDsc, uint256 remainingCollateralValUsd) = dscEngine.getCDPInformation(USER);
        uint256 remainingCollateral = dscEngine.getTokenAmountFromUsdValue(wethToken, remainingCollateralValUsd);

        assertEq(expectedCollateralAmount, remainingCollateral);
        assertEq(expectedDscAmount, remainingDsc);
    }

    function testLiquidatorNowhasCDP() public liquidated {
        (uint256 dscAmountMinted,) = dscEngine.getCDPInformation(LIQUIDATOR);
        assertEq(dscAmountMinted, DEBT_TO_COVER);
    }
}
