// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {PosmTestSetup} from "v4-periphery/test/shared/PosmTestSetup.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Actions} from "v4-periphery/src/libraries/Actions.sol";
import {IHooks} from "v4-periphery/lib/v4-core/src/interfaces/IHooks.sol";
import {Currency, CurrencyLibrary} from "v4-core/types/Currency.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {LiquidityAmounts} from "@uniswap/v4-core/test/utils/LiquidityAmounts.sol";
import {ZorkitronHook} from "../src/ZorkitronHook.sol";
import "forge-std/console.sol";

contract TestZorkitronHook is Test, PosmTestSetup {
	using CurrencyLibrary for Currency;

	// Native ETH tokens are represented by address(0)
	Currency ethCurrency = Currency.wrap(address(0));

	// Our token to use in the below ETH-TOKEN pool
	MockERC20 token;
	Currency tokenCurrency; 	// Currency for the MockER20 token

	// Hook Contract
	ZorkitronHook hookContract;

	// Zorkitron Router Contract
	address zorkitronRouterAddr;

	address owner = address(this);
	bytes hookData = abi.encode(address(this));

	// Currency currency0 = Currency.wrap(address(0)); // tokenAddress1 = 0 for native ETH
	// Currency currency1 = Currency.wrap(address(token));
	PoolKey poolKey;

	function setUp() public {		
		// STEP 1 - Deploy a copy of Uniswap v4
		deployFreshManagerAndRouters();

		// STEP 2 - Deploy an instance of the NFT PositionManager
		deployPosm(manager);

		// STEP 3 - Deploy any random coin
		token = new MockERC20("Random Coin", "RCOIN", 18);		
		tokenCurrency = Currency.wrap(address(token));

		// STEP 4 - Mint a bunch of random coins to ourselves, so we have something to work with
		token.mint(address(this), 100000000000000000 ether);
		token.mint(address(1), 100000000000000000 ether);

		// STEP 5 - We will approve our random coin for spending on the modify liquidity router
		// token.approve(address(modifyLiquidityRouter), type(uint256).max);
		token.approve(address(this), type(uint256).max);
		token.approve(address(1), type(uint256).max);

		// STEP 6 - Approve currency for spending on PosM
		// This happens via approval to Permit2 first, and then Permit2 -> PosM
		// Helper function coming from PosmTestSetup.sol
		approvePosmCurrency(tokenCurrency);

		// STEP 7 - Deploy the Hook Contract
		uint160 flags = uint160(Hooks.AFTER_ADD_LIQUIDITY_FLAG);
		address hookAddress = address(flags);
		zorkitronRouterAddr = address(0x2179a60856E37dfeAacA0ab043B931fE224b27B6);

		// STEP 8 - Deploy ZorkitronRouter
		deployCodeTo(
			"ZorkitronRouter.sol", 
			abi.encode(manager),	
			zorkitronRouterAddr
		);

		// STEP 9 - Deploy code to any address of choice using the following Foundry cheatcode
		deployCodeTo(
			"ZorkitronHook.sol",
			abi.encode(manager, zorkitronRouterAddr, lpm),
			hookAddress
		);

		// Step 10 - Generate the Pool Key
		hookContract = ZorkitronHook(address(flags));
		poolKey = PoolKey(ethCurrency, tokenCurrency, 3000, 60, IHooks(hookContract));

		// STEP 11 - Initialize a new Pool
		(key, ) = initPool(
			ethCurrency,
			tokenCurrency,
			hookContract, 
			3000,
			SQRT_PRICE_1_1
		);
	}

    function test_addLiquidity() public {
		bytes memory actions = abi.encodePacked(uint8(Actions.MINT_POSITION), uint8(Actions.SETTLE_PAIR));
		bytes[] memory params = new bytes[](2);

		int24 tickLower = -60;
		int24 tickUpper = 60;
		uint128 ethToAdd = 10000 ether;
		uint128 amount0Max = ethToAdd;
		uint128 amount1Max = 10000000000000000000000;
		uint160 sqrtPriceAtTickLower = TickMath.getSqrtPriceAtTick(-60);
		uint256 liquidityDelta = LiquidityAmounts.getLiquidityForAmount0(
			sqrtPriceAtTickLower,
			SQRT_PRICE_1_1,
			ethToAdd
		);
		uint256 deadline = block.timestamp + 60;
		uint256 valueToPass = ethCurrency.isAddressZero() ? amount0Max : 0;

		// owner = recipient of minted position
		params[0] = abi.encode(
			poolKey,
			tickLower,
			tickUpper,
			liquidityDelta,
			amount0Max,
			amount1Max,
			owner, 
			hookData
		);

		params[1] = abi.encode(ethCurrency, tokenCurrency);

		lpm.modifyLiquidities{value: valueToPass}(
			abi.encode(actions, params),
			deadline
		);

        assertEq(true, true);
    }
}