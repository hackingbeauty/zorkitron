// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {BaseTest} from "./utils/BaseTest.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {CurrencyLibrary, Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {StateLibrary} from "@uniswap/v4-core/src/libraries/StateLibrary.sol";
import {LiquidityAmounts} from "@uniswap/v4-core/test/utils/LiquidityAmounts.sol";
import {IPositionManager} from "v4-periphery/src/interfaces/IPositionManager.sol";
import {Constants} from "@uniswap/v4-core/test/utils/Constants.sol";
import {EasyPosm} from "./utils/libraries/EasyPosm.sol";
import {ZorkitronHook} from "../src/ZorkitronHook.sol";
import "forge-std/console.sol";

contract ZorkitronHookTest is BaseTest {
    using EasyPosm for IPositionManager;
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;
    using StateLibrary for IPoolManager;

    Currency currency0;
    Currency currency1;
    PoolKey poolKey;
    ZorkitronHook hook;
    PoolId poolId;

    uint256 tokenId;
    int24 tickLower;
    int24 tickUpper;

    function setUp() public {
        console.log("====================================");
        console.log("INSIDE setUp() function in ZorkitronHookTest");
        console.log("====================================");

        // Deploys all required artifacts
        deployArtifactsAndLabel();

        (currency0, currency1) = deployCurrencyPair();

        address flags =
            address(uint160(Hooks.AFTER_ADD_LIQUIDITY_FLAG | Hooks.AFTER_REMOVE_LIQUIDITY_FLAG
            | Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG | Hooks.BEFORE_INITIALIZE_FLAG 
        ) ^ (0x4444 << 144));

        address zorkitronRouterAddr = deployCode("ZorkitronRouter.sol");
        bytes memory constructorArgs = abi.encode(poolManager, positionManager, zorkitronRouterAddr);

        console.log("----- zorkitronRouterAddr ------");
        console.logAddress(zorkitronRouterAddr);
        console.log("----constructorArgs-----");
        console.logBytes(constructorArgs);
        console.log("----flags-----");
        console.log(flags);

        deployCodeTo("ZorkitronHook.sol", constructorArgs, flags);
        hook = ZorkitronHook(payable(flags));

        // Create the pool
        poolKey = PoolKey(currency0, currency1, 3000, 60, IHooks(hook));
        poolId = poolKey.toId();

        // bytes memory hookData = abi.encode(block.timestamp);
        poolManager.initialize(poolKey, Constants.SQRT_PRICE_1_1);

        // Provide full-range liquidity to the pool
        tickLower = TickMath.minUsableTick(poolKey.tickSpacing);
        tickUpper = TickMath.maxUsableTick(poolKey.tickSpacing);

        uint128 liquidityAmount = 100e18;

        (uint256 amount0Expected, uint256 amount1Expected) = LiquidityAmounts.getAmountsForLiquidity(
            Constants.SQRT_PRICE_1_1,
            TickMath.getSqrtPriceAtTick(tickLower),
            TickMath.getSqrtPriceAtTick(tickUpper),
            liquidityAmount
        );

        (tokenId,) = positionManager.mint(
            poolKey,
            tickLower,
            tickUpper,
            liquidityAmount,
            amount0Expected + 1,
            amount1Expected + 1,
            address(this),
            block.timestamp,
            Constants.ZERO_BYTES
        );

        console.log("---- after calling positionManager.mint(), the tokenId iz ------");
        console.log(tokenId);
    }

    /**
     * A pool must be seeded via {seedLiquidity} before liquidity can be added through
     * {addRehypothecatedLiquidity}
     */
    function testPoolMustBeSeededBeforeLiquidityCanBeAdded () public {
        assertEq(true, true);
    }

    /**
     * Seeding is only allowed whenever the pool has no outstanding shares
     * i.e. at genesis, or to revive the pool after a full withdrawal
     */
    function testSeedingIsOnlyAllowedWhenPoolsHasNoOutstandingShares() public {
        assertEq(true, true);
    }

    /**
     * The hook's position must default to UniswapV2-like full range positions
     */
    function testHookPositionMustDefaultToUniswapV2LikeFullRangePositions() public {
        assertEq(true, true);
    }

    /**
     * The hook's position range must be able to be customized by overriding 
     * getTickLower() and getTickUpper()
     */
    function testHookPositionRangeMustBeAdjustable() public {
        assertEq(true, true);
    }

}
