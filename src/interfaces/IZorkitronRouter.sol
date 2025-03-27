// SPDX-License-Identifier: MIT
pragma solidity=0.8.26;

import {IPositionManager} from "v4-periphery/src/PositionManager.sol";
import {ZorkitronHook} from "../ZorkitronHook.sol";

interface IZorkitronRouter {
    function addLiquidity(
        address _currency0,
        address _currency1,
        int24 tickLower,
        int24 tickUpper,
        uint256 liquidity,
        uint128 amount0Max,
        uint128 amount1Max,
        uint256 ethToSend
    ) external returns (bool success);
    function depositCollateral(address owner) external returns (bool success);
    function removeLiquidity(address owner) external returns (bool success);
    function setHookContract(address _hookContractAddr) external;
    function initializePool(
        address _currency0,
        address _currency1,
        int24 _tickSpacing,
        uint24 _liquidityProviderFee,
        uint128 amount0Max,
        uint128 amount1Max,
        uint256 ethToSend
    ) external returns(bool success);
}
