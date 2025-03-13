// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {PosmTestSetup} from "v4-periphery/test/shared/PosmTestSetup.sol";
import {Deploy, IPositionDescriptor} from "v4-periphery/test/shared/Deploy.sol";
// import {PoolSwapTest} from "v4-core/test/PoolSwapTest.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";
import {PoolManager} from "v4-core/PoolManager.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {IPositionManager} from "v4-periphery/src/PositionManager.sol";
import {Currency, CurrencyLibrary} from "v4-core/types/Currency.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {SqrtPriceMath} from "v4-core/libraries/SqrtPriceMath.sol";
import {LiquidityAmounts} from "@uniswap/v4-core/test/utils/LiquidityAmounts.sol";
import {ZorkitronHook} from "../src/ZorkitronHook.sol";

import {Deploy, IPositionDescriptor} from "v4-periphery/test/shared/Deploy.sol";

import "forge-std/console.sol";

contract TestZorkitronHook is Test, Deployers, PosmTestSetup {
	using CurrencyLibrary for Currency;

	// Our token to use in the below ETH-TOKEN pool
	MockERC20 token;

	// Native ETH tokens are represented by address(0)
	Currency ethCurrency = Currency.wrap(address(0));

	// Currency for the MockER20 token
	Currency tokenCurrency;

	ZorkitronHook hookContract;

	function setUp() public {		
		// STEP 1 - Deploy a copy of Uniswap v4
		deployFreshManagerAndRouters();

		// STEP 2 - Deploy an instance of the NFT PositionManager
		IPositionManager posm = Deploy.positionManager(
            address(manager), address(permit2), 100_000, address(proxyAsImplementation), address(_WETH9), hex"03"
        );

		// STEP 3 - Deploy any random coin
		token = new MockERC20("Random Coin", "RCOIN", 18);		
		tokenCurrency = Currency.wrap(address(token));

		// STEP 4 - Mint a bunch of random coins to ourselves, so we have something to work with
		token.mint(address(this), 1000 ether);
		token.mint(address(1), 1000 ether);

		// STEP 5 - Deploy the Hook Contract
		uint160 flags = uint160(Hooks.AFTER_ADD_LIQUIDITY_FLAG);
		address hookAddress = address(flags);
		address zorkitronGeneratorAddr = address(0x2179a60856E37dfeAacA0ab043B931fE224b27B6);

		// STEP 6 - Deploy ZorkitronGenerator
		deployCodeTo("ZorkitronGenerator.sol", zorkitronGeneratorAddr);

		// STEP 7 - Deploy code to any address of choice using the following Foundry cheatcode
		deployCodeTo(
			"ZorkitronHook.sol",
			abi.encode(manager, zorkitronGeneratorAddr, posm),
			hookAddress
		);

		hookContract = ZorkitronHook(address(flags));

		// STEP 8 - We will approve our random coin for spending on the modify liquidity router
		token.approve(address(modifyLiquidityRouter), type(uint256).max);

		// STEP 9 - Initialize a new Pool
		(key, ) = initPool(
			ethCurrency,
			tokenCurrency,
			hookContract, 
			3000,
			SQRT_PRICE_1_1
		);
	}

    function test_addLiquidity() public {
		bytes memory hookData = abi.encode(address(this));

		uint160 sqrtPriceAtTickLower = TickMath.getSqrtPriceAtTick(-60);
		uint256 ethToAdd = 0.1 ether;
		uint128 liquidityDelta = LiquidityAmounts.getLiquidityForAmount0(
			sqrtPriceAtTickLower,
			SQRT_PRICE_1_1,
			ethToAdd
		);

		modifyLiquidityRouter.modifyLiquidity{value: ethToAdd}(
			key,
			IPoolManager.ModifyLiquidityParams({
				tickLower: -60,
				tickUpper: 60,
				liquidityDelta: int256(uint256(liquidityDelta)),
				salt: bytes32(0)
			}),
			hookData
		);

        assertEq(true, true);
    }
}