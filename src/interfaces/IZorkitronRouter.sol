// SPDX-License-Identifier: MIT
pragma solidity=0.8.26;

import {IPositionManager} from "v4-periphery/src/PositionManager.sol";

interface IZorkitronRouter {
    function addLiquidity(
        bool _currency0isETH,
        address _currency0,
        address _currency1,
        int24 tickLower,
        int24 tickUpper,
        uint256 liquidity,
        uint128 amount0Max,
        uint128 amount1Max,
        uint256 ethToSend,
        bytes calldata hookData
    ) external returns (bool success);
    function depositCollateral(address owner) external returns (bool success);
}
