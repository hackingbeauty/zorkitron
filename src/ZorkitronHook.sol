// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import {BaseHook} from "v4-periphery/src/utils/BaseHook.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Currency, CurrencyLibrary} from "v4-core/types/Currency.sol";
import {StateLibrary} from "v4-core/libraries/StateLibrary.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {FixedPointMathLib} from "solmate/src/utils/FixedPointMathLib.sol";

contract ZorkitronHook is BaseHook, ERC1155 {
    // Constructor
    constructor() {}

    // BaseHook Functions
    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: true,
            beforeAddLiquidity: false,
            afterAddLiquidity: true,
            beforeRemoveLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: false,
            afterSwap: false,
            beforeDonate: false,
            afterDone: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        }); 
    }

    function afterAddLiquidity(
        address sender,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        BalanceDelta,
        bytes calldata
    ) external override onlyPoolManager returns (bytes4, int128) {
        // If this is not an ETH-TOKEN pool with this hook attached, ignore
        if (!key.currency0.isAddressZero()) return (this.afterAddLiquidity.selector, delta);

        uint daiTokens = lockCollateral(liquidityTokens);
        uint ethTokens = swapDAIForETH(daiTokens);
        uint stakedEth = stakeETH(ethTokens);
        uint reStakedETH = restakeETH(stakedETH);

        return (this.afterAddLiquidity.selector, 0);
    }

    function lockCollateral(liquidityTokens) internal returns(uint daiTokens) {
        // Developer Docs: https://docs.makerdao.com/
        // https://github.com/makerdao
        // https://github.com/makerdao/developerguides
        // Collateral module: https://docs.makerdao.com/smart-contract-modules/collateral-module

        // uint daiTokens = IMakerDAO(makerDAOAddr).depositCollateral(liquidity);
        // so...after a deposit of liquidity...how does the Smart Contract code get access to the 
        // Liquidity Tokens that have been credited to the Liquidity

        uint daiTokens = IMakerDAO(makerDAOAddr).depositCollateral(liquidityTokens);
    } 

    function swapDAIForETH() internal returns () {
        // IUniswapV3Router03(routerAddr).swap(daiTokens);
    }

    function stakeETH() internal returns () {
        // Beacon deposit contract: https://etherscan.io/address/0x00000000219ab540356cBB839Cbe05303d7705Fa#code
    }

    function restakeETH() internal returns() {
        // Eigen Layer Smart Contract call
    }

    function withdrawLiquidity() external returns() {
        // withdraw all the DeFi passive income
    }

}