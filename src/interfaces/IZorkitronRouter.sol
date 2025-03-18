// SPDX-License-Identifier: MIT
pragma solidity=0.8.26;

import {IPositionManager} from "v4-periphery/src/PositionManager.sol";

interface IZorkitronRouter {
    function addLiquidity(
        address currency0,
        address currency1,
        int24 tickSpacing,
        uint24 liquidityProviderFee
    ) external returns (bool success);
    function depositCollateral(address owner) external returns (bool success);
}
