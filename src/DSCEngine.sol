// SPDX-License-Identifier: MIT

pragma solidity ^0.8.21;

import {DecentralisedStableCoin} from "./DecentralisedStableCoin.sol";
import {ReentrancyGuard} from "@openzepplin/contracts/security/ReentrancyGuard.sol";
import {IERC20} from "@openzepplin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/**
 * @title DSCEngine
 * @author MGM103
 * @dev This contract is designed to be both mininal and maintain the stability of the Decentralised Stable Coin.
 * This stable coin has the following properties:
 * - Collateral: wETH & wBTC (Only exogenous assets are permitted)
 * - Minting: Algorithmic
 * - Relative Stability: Pegged to $1.00 US
 *
 * @notice This contract houses the core logic for the DSC ecosystem. This includes minting & burning the stable coin and managing the collateral.
 * @notice This contract is loosely based on MakerDAO's DSS (DAI stable coin) system.
 * @notice The system should maintain overcollateralisation, at no point should the value of the collateral be less than or equal to the value of the stable coin.
 */
contract DSCEngine is ReentrancyGuard {
    /////ERRORS/////
    error DSCEngine__RequiresMoreThanZero();
    error DSCEngine__InvalidCollateralConstructorParams();
    error DSCEngine__DscMintFailed();
    error DSCEngine__CollateralIsNotPermitted(address invalidCollateral);
    error DSCEngine__CollateralDepositFailed(address collateralToken, uint256 amountCollateral);
    error DSCEngine__HealthFactorThresholdInsufficient(uint256 healthFactor);

    /////STATE VARIABLES/////
    uint256 private constant LIQUIDATION_THRESHOLD = 50;
    uint256 private constant MINIMUM_HEALTH_FACTOR = 1;
    uint256 private constant ADDITIONAL_PRICE_FEED_PRECISION = 1e10;
    uint256 private constant TOKEN_PRECISION = 1e18;
    uint256 private constant LIQUATION_PRECISION = 100;

    DecentralisedStableCoin private immutable i_dsc;
    address[] private s_collateralAddresses;
    mapping(address collateralToken => address priceFeed) private s_priceFeeds;
    mapping(address user => mapping(address collateralToken => uint256 collateralAmount)) private
        s_userCollateralDeposits;
    mapping(address user => uint256 amountDscMinted) private s_userDscMinted;

    /////EVENTS/////
    event CollateralDeposited(address indexed user, address indexed collateralToken, uint256 indexed amountCollateral);

    /////MODIFIERS/////
    modifier moreThanZero(uint256 amount) {
        if (amount <= 0) revert DSCEngine__RequiresMoreThanZero();
        _;
    }

    modifier isPermittedCollateral(address tokenAddress) {
        if (s_priceFeeds[tokenAddress] == address(0)) {
            revert DSCEngine__CollateralIsNotPermitted(tokenAddress);
        }
        _;
    }

    /////FUNCTIONS/////
    constructor(address[] memory tokenAddresses, address[] memory priceFeedAddresses, address DSCTokenAddress) {
        if (tokenAddresses.length != priceFeedAddresses.length) {
            revert DSCEngine__InvalidCollateralConstructorParams();
        }

        // USD Price feeds
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            s_priceFeeds[tokenAddresses[i]] = priceFeedAddresses[i];
            s_collateralAddresses.push(tokenAddresses[i]);
        }

        i_dsc = DecentralisedStableCoin(DSCTokenAddress);
    }

    /////EXTERNAL FUNCTIONS/////
    function depositCollateralAndMintDsc(
        address collateralTokenAddress,
        uint256 amountCollateral,
        uint256 amountDscToMint
    ) external {
        depositCollateral(collateralTokenAddress, amountCollateral);
        mintDsc(amountDscToMint);
    }

    /**
     *
     * @param collateralTokenAddress The address of the token to deposit as collateral
     * @param amountCollateral The amount of collateral tokens that are being deposited
     */
    function depositCollateral(address collateralTokenAddress, uint256 amountCollateral)
        public
        isPermittedCollateral(collateralTokenAddress)
        moreThanZero(amountCollateral)
        nonReentrant
    {
        s_userCollateralDeposits[msg.sender][collateralTokenAddress] += amountCollateral;
        emit CollateralDeposited(msg.sender, collateralTokenAddress, amountCollateral);

        bool success = IERC20(collateralTokenAddress).transferFrom(msg.sender, address(this), amountCollateral);
        if (!success) revert DSCEngine__CollateralDepositFailed(collateralTokenAddress, amountCollateral);
    }

    function redeemCollateralForDsc() external {}

    function redeemCollateral() external {}

    /**
     * @param amountDscToMint The amount of DSC to mint
     * @notice The minter must have collateral at the value of the threshold ratio to mint DSC
     */
    function mintDsc(uint256 amountDscToMint) public moreThanZero(amountDscToMint) nonReentrant {
        s_userDscMinted[msg.sender] += amountDscToMint;
        _revertIfHealthFactorThresholdInsufficient(msg.sender);

        bool minted = i_dsc.mint(msg.sender, amountDscToMint);
        if (!minted) revert DSCEngine__DscMintFailed();
    }

    function burnDsc() external {}

    function liquidate() external {}

    function getHealthFactor() external view {}

    /////PUBLIC & EXTERNAL VIEW FUNCTIONS/////
    function getTotalCollateralValueInUsd(address user) public view returns (uint256 totalCollateralValueUsd) {
        for (uint256 i = 0; i < s_collateralAddresses.length; i++) {
            address token = s_collateralAddresses[i];
            uint256 amount = s_userCollateralDeposits[user][token];
            totalCollateralValueUsd += getUsdValueOfCollateralAsset(token, amount);
        }

        return totalCollateralValueUsd;
    }

    function getUsdValueOfCollateralAsset(address collateralTokenAddress, uint256 amountCollateral)
        public
        view
        returns (uint256)
    {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[collateralTokenAddress]);
        (, int256 price,,,) = priceFeed.latestRoundData();

        return (uint256(price) * ADDITIONAL_PRICE_FEED_PRECISION * amountCollateral) / TOKEN_PRECISION;
    }

    /////PRIVATE & INTERNAL VIEW FUNCTIONS/////
    function _getCDPInfo(address user) private view returns (uint256 dscAmountMinted, uint256 collateralValueInUsd) {
        dscAmountMinted = s_userDscMinted[user];
        collateralValueInUsd = getTotalCollateralValueInUsd(user);
    }

    /**
     * Returns numerical value of how close the user is to liquidation.
     * If the health factor is less than 1, the user is at risk of liquidation.
     * Health Factor = (Collateral Value * Liquidation Threshold) / DSC Value Minted
     *
     * @param user user who's health factor is being retrieved
     */
    function _healthFactor(address user) internal view returns (uint256) {
        (uint256 totalDscMinted, uint256 totalCollateralValueUsd) = _getCDPInfo(user);
        uint256 thresholdAdjustedCollateral = (totalCollateralValueUsd * LIQUIDATION_THRESHOLD) / LIQUATION_PRECISION;

        return (thresholdAdjustedCollateral * TOKEN_PRECISION) / totalDscMinted;
    }

    function _revertIfHealthFactorThresholdInsufficient(address user) internal view {
        uint256 userHealthFactor = _healthFactor(user);

        if (userHealthFactor < MINIMUM_HEALTH_FACTOR) {}
    }
}
