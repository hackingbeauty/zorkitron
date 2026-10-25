// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IZorkitronRouter} from "./interfaces/IZorkitronRouter.sol";
import "forge-std/console.sol";

contract ZorkitronRouter is IZorkitronRouter {
    function depositLiquidity(uint256 tokenId) external returns (bool success) {
        console.log("---- inside depositLiquidity, the tokenId iz: ----");
        console.log(tokenId);

        return false;
    }

    function removeLiquidity(address owner) external returns (bool success) {
        return false;
    }
}
