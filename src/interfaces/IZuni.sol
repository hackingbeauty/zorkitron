// SPDX-License-Identifier: MIT
pragma solidity=0.8.26;

import {PositionInfo} from "v4-periphery/src/libraries/PositionInfoLibrary.sol";

interface IZuni {
    function deposit(PositionInfo positionInfo) external returns (uint256 erc20Tokens);
}
