// SPDX-License-Identifier: MIT

pragma solidity ^0.8.21;

import {ERC20Mock} from "@openzepplin/contracts/mocks/ERC20Mock.sol";
import {Script} from "forge-std/Script.sol";
import {MockV3Aggregator} from "../test/mocks/MockV3Aggregator.sol";

contract HelperConfig is Script {
    struct NetworkConfig {
        address wethUsdPriceFeed;
        address wbtcUsdPriceFeed;
        address wethToken;
        address wbtcToken;
        uint256 deployerKey;
    }

    NetworkConfig public activeNetworkConfig;
    uint256 public DEFAULT_ANVIL_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    uint8 public constant PRICE_FEED_DECIMALS = 8;
    int256 public constant WETH_USD_PRICE = 4000e8;
    int256 public constant WBTC_USD_PRICE = 70000e8;
    uint256 public constant TOKEN_INTIAL_BALANCE = 1000e8;
    string public constant WETH_NAME = "Wrapped Ether";
    string public constant WETH_SYMBOL = "WETH";
    string public constant WBTC_NAME = "Wrapped Bitcoin";
    string public constant WBTC_SYMBOL = "WBTC";

    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaNetworkConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilNetworkConfig();
        }
    }

    function getSepoliaNetworkConfig() public view returns (NetworkConfig memory) {
        return NetworkConfig({
            wethUsdPriceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306,
            wbtcUsdPriceFeed: 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43,
            wethToken: 0xdd13E55209Fd76AfE204dBda4007C227904f0a81,
            wbtcToken: 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063,
            deployerKey: vm.envUint("PRIVATE_KEY")
        });
    }

    function getOrCreateAnvilNetworkConfig() public returns (NetworkConfig memory) {
        if (activeNetworkConfig.wethUsdPriceFeed != address(0)) {
            return activeNetworkConfig;
        }

        vm.startBroadcast();
        MockV3Aggregator ethUsdPriceFeed = new MockV3Aggregator(PRICE_FEED_DECIMALS, WETH_USD_PRICE);
        MockV3Aggregator wbtcUsdPriceFeed = new MockV3Aggregator(PRICE_FEED_DECIMALS, WBTC_USD_PRICE);
        ERC20Mock wethTokenMock = new ERC20Mock(WETH_NAME, WETH_SYMBOL, msg.sender, TOKEN_INTIAL_BALANCE);
        ERC20Mock wbtcTokenMock = new ERC20Mock(WBTC_NAME, WBTC_SYMBOL, msg.sender, TOKEN_INTIAL_BALANCE);
        vm.stopBroadcast();

        return NetworkConfig({
            wethUsdPriceFeed: address(ethUsdPriceFeed),
            wbtcUsdPriceFeed: address(wbtcUsdPriceFeed),
            wethToken: address(wethTokenMock),
            wbtcToken: address(wbtcTokenMock),
            deployerKey: DEFAULT_ANVIL_KEY
        });
    }
}
