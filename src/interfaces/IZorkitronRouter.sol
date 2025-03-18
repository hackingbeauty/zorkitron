// SPDX-License-Identifier: MIT
pragma solidity=0.8.26;

import {IPositionManager} from "v4-periphery/src/PositionManager.sol";

interface IZorkitronRouter {
    function addLiquidity() external returns (bool success);
    function depositCollateral(address lpNFT, IPositionManager posm) external returns (bool success);
}