// SPDX-License-Identifier: MIT
pragma solidity=0.8.26;

import {PoolKey} from "v4-core/types/PoolKey.sol";
import {IZorkitronRouter} from "./interfaces/IZorkitronRouter.sol";
import {IPositionManager} from "v4-periphery/src/PositionManager.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PositionInfo} from "v4-periphery/src/libraries/PositionInfoLibrary.sol";
import {IERC721} from "forge-std/interfaces/IERC721.sol";
import {SafeCallback} from "v4-periphery/src/base/SafeCallback.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {Actions} from "v4-periphery/src/libraries/Actions.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {LiquidityAmounts} from "@uniswap/v4-core/test/utils/LiquidityAmounts.sol";
import "forge-std/console.sol";

contract ZorkitronRouter is IZorkitronRouter, SafeCallback {
    address owner;

    // PositionManager NFT
	IPositionManager posm;

    PoolKey poolKey;

    uint256 liquidityProviderFee;
   
    constructor(
        IPoolManager _manager,
        address _zorkitronRouter,
        IPositionManager _posm
    ) SafeCallback(_manager)  {
        console.log('-----INSIDE THE ZORKITRON_ROUTER CONSTRUCTOR -----');
        posm = _posm;
    }

    function addLiquidity(
        address currency0,
        address currency1
    ) external returns(bool success) {

        PoolKey memory pool = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: liquidityProviderFee,
            tickSpacing: tickSpacing,
            hooks: hookContract
        });


        
        return true;
    }

    function depositCollateral(IPositionManager posm) external returns(bool success) {
        uint256 tokenId = posm.nextTokenId();
        
        console.log("--------- POSM Next Position Id is: ---------");
        console.log(tokenId);
        console.log("--------- POSM PositionInfo: ---------");
        console.log('----- owner iz-----');
        console.log(owner);
        
        // IERC721(address(posm)).setApprovalForAll(zorkitronGeneratorAddr, true);
        // IERC721(address(posm)).transferFrom(owner, zorkitronGeneratorAddr, tokenId);

        return true;
    }


    function _unlockCallback(bytes calldata data) internal override returns (bytes memory) {
		
    
	}


}