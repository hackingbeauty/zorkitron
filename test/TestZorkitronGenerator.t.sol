// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {PoolSwapTest} from "v4-core/test/PoolSwapTest.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";
import {PoolManager} from "v4-core/PoolManager.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {Currency, CurrencyLibrary} from "v4-core/types/Currency.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {SqrtPriceMath} from "v4-core/libraries/SqrtPriceMath.sol";
import {LiquidityAmounts} from "@uniswap/v4-core/test/utils/LiquidityAmounts.sol";
import {ZorkitronHook} from "../src/ZorkitronHook.sol";
import {ZorkitronGenerator} from "../src/ZorkitronGenerator.sol";
import "forge-std/console.sol";

contract TestZorkitronHook is Test, Deployers {
	using CurrencyLibrary for Currency;

	MockERC20 token; // our token to use in the ETH-ZORK pool

	// Native tokens are represented by address(0)
	Currency ethCurrency = Currency.wrap(address(0));
	Currency tokenCurrency;

	ZorkitronHook hook;

	function setUp() public {
		// Step 1 + 2
		// Deploy PoolManager and Router contracts
		deployFreshManagerAndRouters();

		// Deploy our TOKEN contract
		token = new MockERC20("Test Token", "TEST", 18);
		tokenCurrency = Currency.wrap(address(token));

		// Mint a bunch of TOKEN to ourselves
		token.mint(address(this), 1000 ether);

		// Deploy hook to an address that has the proper flags set
		uint160 flags = uint160(Hooks.AFTER_ADD_LIQUIDITY_FLAG);
		
		deployCodeTo(
			"ZorkitronGenerator.sol",
			abi.encode(manager, "ZORK Token", "TEST_POINTS"),
			address(flags)
		);

		// Deploy our hook
    	hook = ZorkitronHook(address(flags));

		// Approve our TOKEN for spending on the swap router and modify liquidity router
		// These variables are coming from the `Deployers` contract
		token.approve(address(swapRouter), type(uint256).max);
		token.approve(address(modifyLiquidityRouter), type(uint256).max);

		// Initialize a pool
		(key, ) = initPool(
			ethCurrency, // Currency 0 = ETH
			tokenCurrency, // Currency 1 = TOKEN
			hook, // Hook Contract
			3000, // Swap Fees
			SQRT_PRICE_1_1 // Initial Sqrt(P) value = 1
		);
	}
}

// liquidity receipt tokens...the periphery Position Manager mints the Liquidity Tokens
// in v3 and v4 the liquidty tokesn are non-fungible, they corresond to a specific range,
// so a hook