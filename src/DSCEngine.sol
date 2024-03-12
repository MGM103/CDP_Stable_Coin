// SPDX-License-Identifier: MIT

pragma solidity ^0.8.21;

import {DecentralisedStableCoin} from "./DecentralisedStableCoin.sol";
import {ReentrancyGuard} from "@openzepplin/contracts/security/ReentrancyGuard.sol";
import {IERC20} from "@openzepplin/contracts/token/ERC20/IERC20.sol";

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
    /**
     * ERRORS
     */
    error DSCEngine__RequiresMoreThanZero();
    error DSCEngine__InvalidCollateralConstructorParams();
    error DSCEngine__CollateralIsNotPermitted(address invalidCollateral);
    error DSCEngine__CollateralDepositFailed(address collateralToken, uint256 amountCollateral);

    /**
     * STATE VARIABLES
     */
    DecentralisedStableCoin private immutable i_dsc;
    mapping(address collateralToken => address priceFeed) private s_priceFeeds;
    mapping(address user => mapping(address collateralToken => uint256 collateralAmount)) private
        s_userCollateralDeposits;

    /**
     * EVENTS
     */
    event CollateralDeposited(address indexed user, address indexed collateralToken, uint256 indexed amountCollateral);

    /**
     * MODIFIERS
     */
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

    /**
     * FUNCTIONS
     */
    constructor(address[] memory tokenAddresses, address[] memory priceFeedAddresses, address DSCTokenAddress) {
        if (tokenAddresses.length != priceFeedAddresses.length) {
            revert DSCEngine__InvalidCollateralConstructorParams();
        }

        // USD Price feeds
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            s_priceFeeds[tokenAddresses[i]] = priceFeedAddresses[i];
        }

        i_dsc = DecentralisedStableCoin(DSCTokenAddress);
    }

    /**
     * EXTERNAL FUNCTIONS
     */
    function depositCollateralAndMintDsc() external {}

    /**
     *
     * @param collateralTokenAddress The address of the token to deposit as collateral
     * @param amountCollateral The amount of collateral tokens that are being deposited
     */
    function depositCollateral(address collateralTokenAddress, uint256 amountCollateral)
        external
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

    function mintDsc() external {}

    function burnDsc() external {}

    function liquidate() external {}

    function getHealthFactor() external view {}
}
