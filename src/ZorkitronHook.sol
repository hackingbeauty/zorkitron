// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {BaseHook} from "v4-periphery/src/utils/BaseHook.sol";
import {ERC20} from "solmate/src/tokens/ERC20.sol";
import {CurrencyLibrary, Currency} from "v4-core/types/Currency.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {BalanceDeltaLibrary, BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {IPositionManager} from "v4-periphery/src/PositionManager.sol";
import {PositionInfo} from "v4-periphery/src/libraries/PositionInfoLibrary.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {IZorkitronRouter} from "./interfaces/IZorkitronRouter.sol";
import {SafeCallback} from "v4-periphery/src/base/SafeCallback.sol";
import "forge-std/console.sol";

contract ZorkitronHook is BaseHook {
	// Use CurrencyLibrary and BalanceDeltaLibrary
	// to add some helper functions over the Currency and BalanceDelta
	// data types 
	using CurrencyLibrary for Currency;
    using BalanceDeltaLibrary for BalanceDelta;

    address zorkitronRouter;
    IPositionManager posm;
    mapping(address => PositionInfo info) public collateralDeposited;

	// Initialize BaseHook and ERC20
    constructor(
        IPoolManager _manager,
        address _zorkitronRouter,
        IPositionManager _posm
    ) BaseHook(_manager)  {
        zorkitronRouter = _zorkitronRouter;
        posm = _posm;
    }

	// Set up hook permissions to return `true`
	// for the two hook functions we are using
    function getHookPermissions()
        public
        pure
        override
        returns (Hooks.Permissions memory)
    {
        return
            Hooks.Permissions({
                beforeInitialize: false,
                afterInitialize: false,
                beforeAddLiquidity: false,
                beforeRemoveLiquidity: false,
                afterAddLiquidity: true,
                afterRemoveLiquidity: false,
                beforeSwap: false,
                afterSwap: false,
                beforeDonate: false,
                afterDonate: false,
                beforeSwapReturnDelta: false,
                afterSwapReturnDelta: false,
                afterAddLiquidityReturnDelta: false,
                afterRemoveLiquidityReturnDelta: false
            });
    }

	// Stub implementation for `afterAddLiquidity`
	function _afterAddLiquidity(
        address,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata,
        BalanceDelta delta,
		BalanceDelta,
        bytes calldata hookData
    ) internal override onlyPoolManager returns (bytes4, BalanceDelta) {
        address owner = abi.decode(hookData, (address));
        console.log("--------- OWNER of deposited liquidity is: ---------");
        console.log(owner);

        // First, check that the pool in question is a pool with ETH as one of the tokens.
        // If currency0 is address(0), then we know its Native ETH.
        // Native ETH will always be currency0/address(0).
        if(!key.currency0.isAddressZero()) return (this.afterAddLiquidity.selector, delta);

        // This function is crucial for applications that need to manage or analyze individual 
        // liquidity positions: posm.getPositionInfo() 

        IZorkitronRouter(zorkitronRouter).depositCollateral(owner, posm);

        return (this.afterAddLiquidity.selector, delta);
    }

    // Helper function to generate hookData in the format we care about
    function getHookData(
        address owner
    ) public pure returns (bytes memory) {
        return abi.encode(owner);
    }
}