// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {BaseHook} from "uniswap-hooks/base/BaseHook.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {BalanceDeltaLibrary, BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {PoolManager} from "v4-periphery/lib/v4-core/src/PoolManager.sol";
import {IPoolManager, SwapParams, ModifyLiquidityParams} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {IPositionManager} from "v4-periphery/src/PositionManager.sol";
import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";
import {SlotDerivation} from "@openzeppelin/contracts/utils/SlotDerivation.sol";
import {TransientSlot} from "@openzeppelin/contracts/utils/TransientSlot.sol";
import {TransientStateLibrary} from "@uniswap/v4-core/src/libraries/TransientStateLibrary.sol";
import {StateLibrary} from "@uniswap/v4-core/src/libraries/StateLibrary.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "@uniswap/v4-core/src/types/BeforeSwapDelta.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {SqrtPriceMath} from "@uniswap/v4-core/src/libraries/SqrtPriceMath.sol";
import {IZorkitronRouter} from "./interfaces/IZorkitronRouter.sol";
import {Position} from "@uniswap/v4-core/src/libraries/Position.sol";
import {PositionInfo} from "v4-periphery/src/libraries/PositionInfoLibrary.sol";
import {Pool} from "@uniswap/v4-core/src/libraries/Pool.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {CurrencySettler} from "./utils/CurrencySettler.sol";
import {FullMath} from "@uniswap/v4-core/src/libraries/FullMath.sol";
import {FixedPoint96} from "@uniswap/v4-core/src/libraries/FixedPoint96.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {IZorkitronRouter} from "./interfaces/IZorkitronRouter.sol";
import "forge-std/console.sol";

contract ZorkitronHook is BaseHook, ERC20, ReentrancyGuardTransient {
    IPositionManager posm;
    address zorkitronRouterAddr;
    
    using TransientStateLibrary for IPoolManager; // Wrapper that allows you to read temporary data in PoolManager
    using StateLibrary for IPoolManager; // Wrapper that allows you to read the internal state of a pool in PoolManager
    using CurrencySettler for Currency; //
    using SafeCast for *;
    using Math for uint256;
    using TransientSlot for *;
    using SlotDerivation for *;
    
    /// @dev The pool key for the hook.  Note that the hook supports only one pool key.
    PoolKey private _poolKey;

    /// @dev The address of the Vaults
    address private _vault0;
    address private _vault1;

    /**
     * @dev The ERC-7201 namespaced transient storage slot for this hook.
     * keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.ReHypothecationHook")) -1)) & ~bytes32(uint256(0xff))
     */
    bytes32 private constant REHYPOTHECATION_HOOK_SLOT = 0x23f8264cc98f1c05acfa1795f9fb9efa795bb6c05987a0477bcc1622ab5aca00;

    /// @dev The offset of the just-in-time position lower tick within {REHYPOTHECATION_HOOK_SLOT}
    uint256 private constant TICK_LOWER_OFFSET = 0;

    /// @dev The offset of the just-in-time position upper tick within {REHYPOTHECATION_HOOK_SLOT}
    uint256 private constant TICK_UPPER_OFFSET = 1;

    /// @dev The offset of the JIT lock flags within {REHYPOTHECATION_HOOK_SLOT}
    uint256 private constant JIT_LOCK_OFFSET = 2;

    /// @dev Errow thrown when trying to initialize a pool that has already been initialized.
    error PoolAlreadyInitialized();

    /// @dev Error thrown when attempting to interact with a pool that has not been initialized.
    error PoolNotInitialized();

    /// @dev Error thrown when the message value doesn't match the expected amount for native ETH deposits.
    error InvalidMsgValue();

    /// @dev Error thrown when the refund fails.
    error RefundFailed();

    /// @dev Error thrown when currency is ETH.
    error InvalidCurrency();

    /// @dev Error thrown when adding liquidity before the pool has been seeded.
    error NotSeeded();

    /// @dev Error thrown when seeding a pool that still has outstanding shares.
    error AlreadySeeded();

    /// @dev Error thrown when attempting to add or remove liquidity with zero shares.
    error ZeroShares();
    
    /// @dev Error thrown when a seed would mint fewer than the minimum safe initial `shares`, given `minShares`.
    error InsufficientSeed(uint256 shares, uint256 minShares);

    /// @dev Error thrown when the amounts of an addition or removal exceed the caller's bounds.
    error TooMuchSlippage();

    /// @dev Error thrown when a liquidity operation and the just-in-time settlement would overlap,
    /// to prevent reentrancy across the JIT lock.
    error JITLocked();

    /// @dev Errow thrown when a swap is attempted while the just-in-time position would size to zero,
    /// so the hook cannot back the swap.
    error NoUsableLiquidity();

    /**
     * @dev Emitted when a `owner` adds rehypothecated `shares` to the `poolKey` pool,
     * transferring `amount0` of `currency0` and `amount1` of `currency1` to the hook.
     */
    event ReHypothecatedLiquidityAdded(
        address indexed owner, PoolKey indexed poolKey, uint256 shares, uint256 amount0, uint256 amount1
    );

    /**
     * @dev Emitted when the addresses for the Vaults are set
     */
    event VaultsSet(address indexed vault0, address indexed vault1);

    constructor(IPoolManager _poolManager, IPositionManager _posm, address _zorkitronRouterAddr)
        BaseHook(_poolManager)
        ERC20("Zorkitron","ZORK")
    {
        posm = _posm;
        zorkitronRouterAddr = _zorkitronRouterAddr;
    }

    /**
     * @dev Set the addresses of the Vaults.
     */
    function setVaults(address vault0_, address vault1_) external {
        _vault0 = vault0_;
        _vault1 = vault1_;
        emit VaultsSet(_vault0, _vault1);
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
     * 
     * @dev Seeds the pool with its first liquidity, depositing `amount0` of `currency0` and `amount1` of
     * `currency1` into the yield sources and minting `sqrt(amount0 * amount1)` shares to the caller, in a
     * UniswapV2 like fashion.  The deposited amounts set the ratio at which {addRehypothecatedLiquidity}
     * prices every later addition.
     * 
     * Callable permissionlessly whenever the pool has not outstanding shares: at genesis, or to revive the pool
     * after a full withdrawal.  The minted shares must be at least `100 * 10 ** _decimalsOffset()`, so the supply
     * determines the virtual-shares offset used in {_shareToAmount} and the share price cannot be inflated.
     * 
     * Returns the `shares` minted and a balance `delta` representing the assets deposited into the hook.
     * 
     * NOTE: After a full withdrawal, the virtual shares' residual stays in the yield sources and the next seeder
     * can reedem it.  Consider overring this function to restrict the caller.
     * 
     * NOTE: The amounts should be provided close to the pool's current price, otherwise part of the seeded
     * liquidity may sit idel until swaps rebalance it.  See {_getLiquidityToUse}.
     * 
     * WARNING: A third party can front-run the seed with a skewed ratio that leaves the hook with negligible
     * usable liquidity.  Consider seeding atomically with pool initialization, or overriding this function
     * to restrict the caller.
     * 
     * Requirements:
     * - Pool must be initialized
     * - Pool must have no outstanding shares (`totalSupply() == 0`)
     * - Resulting shares must be at least `100 * 10 ** _decimalsOffset()`
     * - Sender must have approved the hook to spend the required tokens 
     *  
     */    
    function seedLiquidity(uint256 amount0, uint256 amount1)
        public
        payable
        nonReentrant
        returns (uint256 shares, BalanceDelta delta)
    {
        if (address(_poolKey.hooks) == address(0)) revert PoolNotInitialized();
        if (totalSupply() != 0 ) revert AlreadySeeded();

        shares = Math.sqrt(amount0 * amount1);
        uint256 minShares = 100 * 10 ** uint256(_decimalsOffset());
        if (shares < minShares) revert InsufficientSeed(shares, minShares);

        _transferFromSenderToHook(_poolKey.currency0, amount0, msg.sender);
        _transferFromSenderToHook(_poolKey.currency1, amount1, msg.sender);        

        _depositToVault(_poolKey.currency0, amount0);
        _depositToVault(_poolKey.currency1, amount1);

        _mint(msg.sender, shares);

        emit ReHypothecatedLiquidityAdded(msg.sender, _poolKey, shares, amount0, amount1);
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
        if (totalSupply() == 0) revert NotSeeded();
        if (shares == 0) revert ZeroShares();

        (uint256 amount0, uint256 amount1) = previewMint(shares);
        if (amount0 > amount0Max || amount1 > amount1Max) revert TooMuchSlippage();

        _transferFromSenderToHook(_poolKey.currency0, amount0, msg.sender);
        _transferFromSenderToHook(_poolKey.currency1, amount1, msg.sender);

        // Skip zero-amount deposits, which some yield sources reject (e.g. when one side is proportionally empty)
        if (amount0 > 0) _depositToVault(_poolKey.currency0, amount0);
        if (amount1 > 0) _depositToVault(_poolKey.currency1, amount1);

        _mint(msg.sender, shares);

        emit ReHypothecatedLiquidityAdded(msg.sender, _poolKey, shares, amount0, amount1);
    }

    // -----------------------------------------------
    // NOTE: see IHooks.sol for function documentation
    // -----------------------------------------------
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
     * @dev Hook executed before a swap operation to provide liquidity from rehypothecated assets.
     * 
     * Gets the amount of liquidity to be provided from yield sources/vaults and temporarily adds it to 
     * the pool instead thanks to Uniswap v4's Flash Accounting model.  This addition creates a currencyDelta
     * to the hook, which must be settled during the `_afterSwap` function before locking the poolManager again.
     */
    function _beforeSwap(
        address, /* sender */
        PoolKey calldata, /* key */
        SwapParams calldata, /* params */
        bytes calldata /* hookData */
    ) 
        internal
        override
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        // Take the JIT lock: block liquidity operations from reentering mid-settlement, and block a swap
        // from running inside a liquidity operation or another swap.  Released at the end of `_afterSwap`.
        if (_reentrancyGuardEntered() || _isJITLocked()) revert JITLocked();
        _setJITLocked(true);

        // Snapshot the positions tick bounds so `afterSwap` removes exactly what is added here.
        _snapshotActiveTicks();

        // Get the liquidity to be used from the amounts currently deposited into the yield sources/vaults.
        // The hook is the pool's only liquidity, so a swap that it cannot back must revert.
        uint256 liquidityToUse = _getLiquidityToUse(_activeTickLower(), _activeTickUpper());

        // slither-disable-next-line incorrect-equality
        if (liquidityToUse == 0) revert NoUsableLiquidity();
        _modifyLiquidity(liquidityToUse.toInt256());

        return (this.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
    }

    /**
     * @dev Hook executed after a swap operation to remove temporary liquidity and rebalance assets.
     * 
     * Removes the liquidity that was temporarily added in `_beforeSwap`, and resolves the hook's 
     * deltas in each currency in order to neutralize any pending debits or credits. 
     */
    function _afterSwap(
        address, /* sender */
        PoolKey calldata key, /* key */
        SwapParams calldata, /* params */
        BalanceDelta, /* delta */
        bytes calldata /* hookData */
    )
        internal
        override
        returns(bytes4, int128) 
    {
        // Remove all of the hook owned liquidity from the pool
        uint128 liquidity = _getHookPositionLiquidity();
        if (liquidity > 0) {
            _modifyLiquidity(-liquidity.toInt256());

            // Take or settle any pending deltas with the PoolManager
            _resolveHookDelta(key.currency0);
            _resolveHookDelta(key.currency1);
        }

        // Release the JIT lock once settlement (and its external yield source/vault calls) is complete.
        // _setJITLocked(false);

        return (this.afterSwap.selector, 0);
    }

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
            IERC20(Currency.unwrap(currency)).transferFrom(sender, address(this), amount);
        } else { // Else if the token IS ETH
            if (msg.value < amount) revert InvalidMsgValue();
            if (msg.value > amount) {
                (bool success,) = msg.sender.call{value: msg.value - amount}(""); //calls the receive() or fallback function on msg.sender
                if (!success) revert RefundFailed();
            }
        }
    }

    /**
     * @dev Deposits a specified `amount` of `currency` into its corresponding vault.
     * 
     * Note: Must be implemented and adapted for the desired type of yield sources, such as
     * ERC-4626 Vaults, or any custom DeFi protocol interface, optionally handling native currency.
     * 
     * Note: Must increase {_getAmountInYieldSource} by `amount` and must not revert, since a revert during a swap's
     * settlement reverts the swap.  Sources that charge fees on this call are not supported.
     */
    function _depositToVault(Currency currency, uint256 amount) internal {
        if (currency.isAddressZero()) {
            revert InvalidCurrency();
        }

        address vaultAddr = getVaultAddress(currency);
        IERC20(Currency.unwrap(currency)).approve(vaultAddr, amount);
        IERC4626(vaultAddr).deposit(amount, address(this));
    }

    /** 
     * @dev Get the addresses of the two (2) Vaults
     */
    function getVaultAddress(Currency currency) public view returns (address) {
       PoolKey memory key = _poolKey;
       if (key.currency0 == currency) return _vault0;
       if (key.currency1 == currency) return _vault1;
       revert InvalidCurrency();
    }

    /**
     * @dev Preview the amounts of currency0 and currency1 required for minting a specific amount of shares.
     * 
     * NOTE: Rounds up, benefiting current Liquidity Providers
     */
    function previewMint(uint256 shares) public view returns (uint256 amount0, uint256 amount1) {
        return _sharesToAmounts(shares, Math.Rounding.Ceil);
    }

    /**
     * @dev Calculates the amounts of currency0 and currency1 equivalent to a given amount of `shares`, as a 
     * proportional claim over the hook's balances in the yield sources, using the given rounding direction.
     * 
     * Reverts with {NotSeeded} when no shares have been minted yet, since the pool has no defined ratio
     * before {seedLiquidity}.
     */
    function _sharesToAmounts(uint256 shares, Math.Rounding rounding) 
        internal
        view
        returns (uint256 amount0, uint256 amount1)
    {
        amount0 = _shareToAmount(shares, _poolKey.currency0, rounding);
        amount1 = _shareToAmount(shares, _poolKey.currency1, rounding);
    }

    /**
     * @dev Coverts a given `shares` amount to the corresponding `currency` amount, as its proportional claim
     * over the hook's balance of `currency` in the yield source, using the given rounding direction.
     * 
     * Uses an EIP-4626-like virtual offset (see {decimalOffset}) to defend the share price against inflation,
     * so a share is worth `(balance + 1) / (totalSupply + 10 ** _decimalsOffset())` of the `currency` balance.
     * Reverts with {NotSeeded} before the pool is seeded.
     */
    function _shareToAmount(uint256 shares, Currency currency, Math.Rounding rounding)
        internal
        view
        returns (uint256 amount)
    {
        uint256 supply = totalSupply();
        if (supply == 0) revert NotSeeded();
        return shares.mulDiv(_getAmountInYieldSource(currency) + 1, supply + 10 ** uint256(_decimalsOffset()), rounding);
    }

    /**
     * @dev Gets the `amount` of `currency` deposited in its corresponding yield source.
     * 
     * Note: Must be implemented and adapted for the desired type of yield sources, such as ERC-4626 Vaults,
     * or any custom DeFi protocol interface, optionally handling native currency. 
     */
    function _getAmountInYieldSource(Currency currency) internal view returns (uint256 amount) {
        // To Do
    }

    /** 
     * @dev Returns the `amount` of `currency` that can currently be withdrawn from its yield source/vault.
     * 
     * Used to size the just-in-time liquidity provided during swaps, so the hook never provisions more than it
     * can withdraw back in the same transaction.  Share pricing instead uses {_getAmountInYieldSource}, the full
     * reported balance.
     * 
     * Defaults to {_getAmountInYieldSource}.  Override for yield sources/vaults whose immediately-withdrawable
     * amount can be below the reported balance, such as ERC-4626 `maxWithdraw`, or capped or gated sources.
     */

    function _getMaxWithdrawFromYieldSource(Currency currency) internal view returns (uint256) {
        return _getAmountInYieldSource(currency);
    }


    /**
     * @dev Calculates the `liquidity` to be provided just-in-time for incoming swaps.
     * 
     * Be default, returns the maximum liquidity that can be provided given the balances the hook can
     * currenty withdraw from the yield sources/vaults (see {getMaxWithdrawFromVault}), so the position
     * removed in `afterSwap` never exceeds what the yield sources/vaults can return in the same transaction.
     * 
     * Since the internal pool price (ratio of currency0 to currency1) must be preserved for proviing
     * liquidity to the single hook-owned position range, not necessarily all the assets in the yield sources/vaults
     * may be utilizable as liquidity if the ratio has diverged from the internal pool price
     * 
     * i.e. if the pool price is currently [1:1], but due to divergences in the yield sources/vaults the assets are
     * [100, 100], then only [100, 100] is utilizable and will be returend by this function in equivalent liquidity units,
     * as it is the maximum amount of assets utilizable given the current pool price ratio.
     * 
     * NOTE: Since liquidity is provided and withdrawn transiently during flash accounting, it can be virtually
     * inflated for performing "leveraged liquidity" strategies, which would give better pricing to swappers at
     * the cost of the profitability of LP's and increased risks.
     * 
     * @param tickLower The lower tick of the position the liquidity is sized for.
     * @param tickUpper The upper tick of the position the liquidity is sided for.  
     *  
     */
    function _getLiquidityToUse(int24 tickLower, int24 tickUpper) internal view returns (uint256) {
        // To Do
        (uint160 sqrtPriceX96,,,) = poolManager.getSlot0(_poolKey.toId());
        uint160 sqrtPriceLowerX96 = TickMath.getSqrtPriceAtTick(tickLower);
        uint160 sqrtPriceUpperX96 = TickMath.getSqrtPriceAtTick(tickUpper);

        // A position cannot take either boundary tick past the pool's per-tick gross-liquidity limit, so cap
        // the liquidity there and leave any excess backing idle.
        uint128 maxLiquidity = Pool.tickSpacingToMaxLiquidityPerTick(_poolKey.tickSpacing);

        // Each currency limits the liquidity over its side of the price.  A side is capped before its
        // liquidity is computed, so a currency that does not limit the position cannot overflow the calculation.
        uint256 liquidity0 = maxLiquidity;
        if (sqrtPriceX96 < sqrtPriceUpperX96) {
            uint160 sqrtPriceAX96 = sqrtPriceX96 > sqrtPriceLowerX96 ? sqrtPriceX96 : sqrtPriceLowerX96;
            uint256 amount0 = _getMaxWithdrawFromYieldSource(_poolKey.currency0);
            if (amount0 < SqrtPriceMath.getAmount0Delta(sqrtPriceAX96, sqrtPriceUpperX96, maxLiquidity, true)) {
                liquidity0 = FullMath.mulDiv(
                    amount0,
                    FullMath.mulDiv(sqrtPriceAX96, sqrtPriceUpperX96, FixedPoint96.Q96),
                    sqrtPriceUpperX96 - sqrtPriceAX96
                );
            }
        }

        uint256 liquidity1 = maxLiquidity;
        if (sqrtPriceX96 > sqrtPriceLowerX96) {
            uint160 sqrtPriceBX96 = sqrtPriceX96 < sqrtPriceUpperX96 ? sqrtPriceX96 : sqrtPriceUpperX96;
            uint256 amount1 = _getMaxWithdrawFromYieldSource(_poolKey.currency1);
            if (amount1 < SqrtPriceMath.getAmount1Delta(sqrtPriceLowerX96, sqrtPriceBX96, maxLiquidity, true)) {
                liquidity1 = FullMath.mulDiv(amount1, FixedPoint96.Q96, sqrtPriceBX96 - sqrtPriceLowerX96);
            }
        }

        return Math.min(Math.min(liquidity0, liquidity1), maxLiquidity);
    }

    /**
     * @dev Takes or settles any pending `currencyDelta` delta with the poolManager by transferring from the 
     * yield sources/vaults to the poolManager and vice versa, effectively neutralizing the Flash Accounting
     * deltas before being ablet to lock the poolManager again. 
     *  
     */
    function _resolveHookDelta(Currency currency) internal {
        int256 currencyDelta = poolManager.currencyDelta(address(this), currency);
        if (currencyDelta > 0) {
            currency.take(poolManager, address(this), currencyDelta.toUint256(), false);
        }
        if (currencyDelta < 0 ) {
            currency.settle(poolManager, address(this), (-currencyDelta).toUint256(), false);
        }
    }

    /**
     * 
     * @dev Returns the lower tick boundary for the hook's liquidity position.abi
     * 
     * Can be overriden to customize the tick boundary.
     */
    function getTickLower() public view virtual returns (int24) {
        return TickMath.minUsableTick(_poolKey.tickSpacing);
    }

    /**
     * 
     * @dev Returns the upper tick boundary for the hook's liquidity position
     * 
     * Can be overriden to customize the tick boundary.
     */
    function getTickUpper() public view virtual returns (int24) {
        return TickMath.maxUsableTick(_poolKey.tickSpacing);
    }

    /**
     * @dev Modifies the hook's liquidity position in the pool, at the tick bounds snapshotted for the
     * current swap (see {snapshotActiveTicks})
     * 
     * Positive liquidityDelta adds liquidity, while negative removes it.
     */
    function _modifyLiquidity(int256 liquidityDelta) internal returns (BalanceDelta delta) {
        (delta,) = poolManager.modifyLiquidity(
            _poolKey,
            ModifyLiquidityParams({
                tickLower: _activeTickLower(),
                tickUpper: _activeTickUpper(),
                liquidityDelta: liquidityDelta,
                salt: bytes32(0)
            }),
            ""
        );
    }

    /**
     * @dev Snapshots the just-in-time position's tick bounds into transient storage, so the same bounds are used
     * to add, read, and remove the position across a swap.  Called at the start of `beforeSwap`
     */
    function _snapshotActiveTicks() private {
        REHYPOTHECATION_HOOK_SLOT.offset(TICK_LOWER_OFFSET).asInt256().tstore(getTickLower());
        REHYPOTHECATION_HOOK_SLOT.offset(TICK_UPPER_OFFSET).asInt256().tstore(getTickUpper());
    }

    /// @dev The lower tick of the just-in-time position snapshotted for the current swap.
    function _activeTickLower() private view returns (int24) {
        // To Do
    }

    /// @dev The upper tick of the just-in-time position shapshotted for the current swap.
    function _activeTickUpper() private view returns (int24) {
        // To Do
    }

    /// @dev Sets whether the JIT lock (`beforeSwap` through `afterSwap`) is held.
    function _setJITLocked(bool active) private {
        REHYPOTHECATION_HOOK_SLOT.offset(JIT_LOCK_OFFSET).asBoolean().tstore(active);
    }

    /// @dev Whether the JIT lock is currently held
    function _isJITLocked() private view returns (bool) {
        return REHYPOTHECATION_HOOK_SLOT.offset(JIT_LOCK_OFFSET).asBoolean().tload();
    }

     /**
     * @dev Retrieves the current `liquidity` of the hook owned liquidity position in the `_poolKey` pool.
     * 
     * NOTE: Given that just-in-time liquidity provisioning is performed, this function will only return
     * non-zero values while the liquidity is briefly inside the pool, which is exclusively between `beforeSwap`
     * and `afterSwap`.  It will return zero in any other point in the hook lifecycle.  For determining the hook
     * balances at any other point, use {_getAmountInYieldSource}.
     */
    function _getHookPositionLiquidity() internal view returns (uint128 liquidity) {
        // Position.calculatePositionKey is a library function used to derive the unique 32-byte storage key
        // for a liquidity position inside a pool
        bytes32 positionKey = Position.calculatePositionKey(address(this), _activeTickLower(), _activeTickUpper(), bytes32(0));
        
        // getPositionLiquidity (or reading position liquidity), read the current liquidiyt units assigned to
        // a specific liquidity position  
        return poolManager.getPositionLiquidity(_poolKey.toId(), positionKey);
    }

    /**
     * @dev Returns the decimal offset used for the EIP-4626-like virtual shares that defend the share price
     * against inflation.  The initial supply mined by {seedLiquidity} is required to be at least `100 * 10 ** _decimalsOffset()`,
     * keeping the maximum share price drift around 1%.
     * 
     * Defaults to `6`, which suits most token pairs.  Can be overridden to strengthen the defense with a higher offset,
     * at the cost of a larger minimum seed, for example for high-decimal pairs.
     * 
     */
    function _decimalsOffset() internal view returns (uint8) {
        return 6;
    }

    /// @dev Allows the hook to receive native ETH from the yield sources.
    /// solhint-disable-next-line
    receive() external payable {}
}
