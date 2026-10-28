// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {BaseHook} from "uniswap-hooks/base/BaseHook.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {BalanceDeltaLibrary, BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {PoolManager} from "v4-periphery/lib/v4-core/src/PoolManager.sol";
import {IPoolManager, SwapParams, ModifyLiquidityParams} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {IPositionManager} from "v4-periphery/src/PositionManager.sol";
import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";
import {IZorkitronRouter} from "./interfaces/IZorkitronRouter.sol";
import {PositionInfo} from "v4-periphery/src/libraries/PositionInfoLibrary.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {IZorkitronRouter} from "./interfaces/IZorkitronRouter.sol";
import "forge-std/console.sol";

contract ZorkitronHook is BaseHook, ERC20, ReentrancyGuardTransient {
    IPositionManager posm;
    address zorkitronRouterAddr;

    /// @dev The pool key for the hook.  Note that the hook supports only one pool key.
    PoolKey private _poolKey;

    /// @dev Errow thrown when trying to initialize a pool that has already been initialized.
    error PoolAlreadyInitialized();

    /// @dev Error thrown when attempting to interact with a pool that has not been initialized.
    error PoolNotInitialized();

    /// @dev Error thrown when the message value doesn't match the expected amount for native ETH deposits.
    error InvalidMsgValue();

    /// @dev Error thrown when the refund fails
    error RefundFailed();

    /**
     * @dev Emitted when a `owner` adds rehypothecated `shares` to the `poolKey` pool,
     * transferring `amount0` of `currency0` and `amount1` of `currency1` to the hook.
     */
    event ReHypothecatedLiquidityAdded(
        address indexed owner, PoolKey indexed poolKey, uint256 shares, uint256 amount0, uint256 amount1
    );

    constructor(IPoolManager _poolManager, IPositionManager _posm, address _zorkitronRouterAddr)
        BaseHook(_poolManager)
        ERC20("Zorkitron","ZORK")
    {
        posm = _posm;
        zorkitronRouterAddr = _zorkitronRouterAddr;
    }

    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: true,
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

    /**
     * @dev Initialize the hook's `poolKey` pool.  The key stored by the hook is unique and
     * should not be modified so that it can safely be used across the hook's lifecycle.
     * Note that the hook supports only one pool key.  
     *  
     * WARNING: Pool initialization is permissionless and permanently binds the hook to the first key it sees,
     * so a third party can front-run it with an unintended pool.  Consider initializing the pool atomically
     * with the hook's deployment, or overriding this function to reject an unexpected key.
     */
    function _beforeInitialize(address, PoolKey calldata key, uint160) internal override returns (bytes4) {
        if (address(_poolKey.hooks) != address(0)) revert PoolAlreadyInitialized();
        _poolKey = key;
        return this.beforeInitialize.selector;
    }    

    /**
     * @dev Adds rehypothecated liquidity to their corresponding yield sources and mints `shares` to the `receiver`.
     * 
     * Liquidity is added in the ratio determined by the hook's existing balances in yield sources.
     * Assets are deposited into yield sources where they earn yield when idle and can be dynamically
     * used as pool liquidity during swaps.
     * 
     * Returns a balance `delta` representing the assets deposited into the hook.
     * 
     * Requirements:
     *  - Pool must be initialized
     *  - Pool must have been seeded (see {seedLiquidity})
     *  - Sender must have sufficient token balances
     *  - Sender must have approved the hook to spend the required tokens
     *  - Ammounts required must not exceed `amount0Max` of `currency0` and `amount1Max` of `currency1`
     */

    function addRehypothecatedLiquidity(uint256 shares, uint256 amount0Max, uint256 amount1Max)
        payable
        external 
        nonReentrant
        returns (BalanceDelta delta) 
    {
        if (address(_poolKey.hooks) == address(0)) revert PoolNotInitialized();


        _transferFromSenderToHook(_poolKey.currency0, amount0, msg.sender);
        _transferFromSenderToHook(_poolKey.currency1, amount1, msg.sender);


        // Skip zero-amount deposits, which some yield sources reject (e.g. when one side is proportionally empty)
        if (amount0 > 0) _depositToYieldSource(_poolKey.currency0, amount0);
        if (amount1 > 0) _depositToYieldSource(_poolKey.currency1, amount1);

        _mint(msg.sender, shares);

        emit ReHypothecatedLiquidityAdded(msg.sender, _poolKey, shares, amount0, amount1);
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

    /**
     * @dev Transfers the `amount` of `currency` from the `sender` to the hook
     */
    function _transferFromSenderToHook(Currency currency, uint256 amount, address sender) internal {
        if (!currency.isAddressZero()) { // If the token is NOT ETH
            IERC20(Currency.unwrap(currency)).safeTransferFrom(sender, address(this), amount);
        } else { // Else if the token IS ETH
            if (msg.value < amount) revert InvalidMsgValue();
            if (msg.value > amount) {
                (bool success,) = msg.sender.call{value: msg.value - amount}(""); //calls the receive() or fallback function on msg.sender
                if (!success) revert RefundFailed();
            }
        }
    }

}
