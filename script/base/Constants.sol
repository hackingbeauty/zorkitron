// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

library Constants {
    address constant POOL_MANAGER = 0xE03A1074c86CFeDd5C142C4F04F1a1536e203543;
    address constant POSITION_MANAGER = 0x429ba70129df741B2Ca2a85BC3A2a3328e5c09b4;
    address constant CREATE2_DEPLOYER = 0x4e59b44847b379578588920cA78FbF26c0B4956C;
    address constant DAI_TOKEN_ADDRESS = 0x68194a729C2450ad26072b3D33ADaCbcef39D574;
    address constant ETH_TOKEN_ADDRESS = address(0);
    int24 constant TICK_SPACING = 1;
    uint24 constant LIQUIDITY_PROVIDER_FEE = 3000;
    uint128 constant AMOUNT_O_MAX = 1;
    uint128 constant AMOUNT_1_MAX = 1;
    uint256 constant ETH_TO_SEND = 2 ether;
}