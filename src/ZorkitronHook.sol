// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {BaseHook} from "uniswap-hooks/base/BaseHook.sol";
import {ERC20} from "solmate/src/tokens/ERC20.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {BalanceDeltaLibrary, BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {PoolManager} from "v4-periphery/lib/v4-core/src/PoolManager.sol";
import {IPoolManager, SwapParams, ModifyLiquidityParams} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {IPositionManager} from "v4-periphery/src/PositionManager.sol";
import {IZorkitronRouter} from "./interfaces/IZorkitronRouter.sol";
import {PositionInfo} from "v4-periphery/src/libraries/PositionInfoLibrary.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {IZorkitronRouter} from "./interfaces/IZorkitronRouter.sol";
import "forge-std/console.sol";

contract ZorkitronHook is BaseHook {
    IPositionManager posm;
    address zorkitronRouterAddr;

    constructor(IPoolManager _poolManager, IPositionManager _posm, address _zorkitronRouterAddr)
        BaseHook(_poolManager)
    {
        posm = _posm;
        zorkitronRouterAddr = _zorkitronRouterAddr;
    }

    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: false,
            beforeAddLiquidity: false,
            afterAddLiquidity: true,
            beforeRemoveLiquidity: false,
            afterRemoveLiquidity: true,
            beforeSwap: true,
            afterSwap: true,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    



    // -----------------------------------------------
    // NOTE: see IHooks.sol for function documentation
    // -----------------------------------------------

    function _afterAddLiquidity(
        address sender,
        PoolKey calldata key,
        ModifyLiquidityParams calldata params,
        BalanceDelta delta,
        BalanceDelta feesAccrued,
        bytes calldata hookData
    ) internal override returns (bytes4, BalanceDelta) {
        console.log("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!");
        console.log("INSIDE _afterAddLiquidity HOOK!!!!");
        console.log("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!");

        uint256 tokenId = uint256(params.salt);
        console.log("---- tokenId ----");
        console.log(tokenId);

        IZorkitronRouter(zorkitronRouterAddr).depositLiquidity(tokenId);

        (PoolKey memory poolKey, PositionInfo positionInfo) = posm.getPoolAndPositionInfo(tokenId);

        uint128 liquidity = posm.getPositionLiquidity(tokenId);

        console.log("---------------------------------");
        console.log("poolKey iz:");
        console.logBytes32(positionInfo.poolId());
        console.log("liquidity :");
        console.log(liquidity);
        console.log("---------------------------------");

        uint256 nextTokenId = posm.nextTokenId();

        console.log("---- nextTokenId ----");
        console.log(nextTokenId);

        // Steps:
        // 1 - Get NFT LP token, or Claim token or whatever
        // 2 - Deposit the LP Tokens as collateral on Revert Lend or AAVE (or some other protocol), in exchange for DAI
        // 3 - Exchange DAI for ETH
        // 4 - Stake ETH into Lido (or Rocketpool), or your own Ethereum Validator Node

        // Insert code here for depositing v4 NFT Position in exchange for DAI

        // Insert code here for exchanging DAI for ETH

        // Insert code here for depositing ETH into Lido

        return (BaseHook.afterAddLiquidity.selector, delta);
    }

    function _afterRemoveLiquidity(
        address sender,
        PoolKey calldata key,
        ModifyLiquidityParams calldata params,
        BalanceDelta delta,
        BalanceDelta feesAccrued,
        bytes calldata hookData
    ) internal override returns (bytes4, BalanceDelta) {
        // Steps:
        // 1 - Unstake ETH that was staked/deposited into a Proof Of Stake Validator (or RocketPool, Lido, etc.)
        // 2 - Transfer unstaked ETH into AAVE (or other), and withdraw LP tokens that were used as collateral
        // 3 - Conver the LP Tokens back into either the NFT Liquidity Token or Claim Token
        // 4 - Send the Profit to the LP, and send the withdrawal fee to YOUR address

        return (BaseHook.afterAddLiquidity.selector, delta);
    }
}
