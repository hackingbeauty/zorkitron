// SPDX-License-Identifier: MIT
pragma solidity=0.8.26;

import {PoolKey} from "v4-core/types/PoolKey.sol";
import {IZorkitronRouter} from "./interfaces/IZorkitronRouter.sol";
import {IPositionManager} from "v4-periphery/src/PositionManager.sol";
import {IERC721} from "forge-std/interfaces/IERC721.sol";
import {SafeCallback} from "v4-periphery/src/base/SafeCallback.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {Actions} from "v4-periphery/src/libraries/Actions.sol";
import {ZorkitronHook} from "../src/ZorkitronHook.sol";
import {Currency, CurrencyLibrary} from "v4-core/types/Currency.sol";
import "forge-std/console.sol";

contract ZorkitronRouter is IZorkitronRouter, SafeCallback {
	IPositionManager posm;
    ZorkitronHook hookContract;
    using CurrencyLibrary for Currency;
   
    constructor(
        IPoolManager _manager,
        ZorkitronHook _hookContract,
        IPositionManager _posm
    ) SafeCallback(_manager)  {
        console.log('-----INSIDE THE ZORKITRON_ROUTER CONSTRUCTOR -----');
        hookContract = _hookContract;
        posm = _posm;
    }

    function addLiquidity(
        address currency0,
        address currency1,
        int24 tickSpacing,
        uint24 liquidityProviderFee
    ) external view returns(bool success) {

        PoolKey memory poolKey = PoolKey({
            currency0: Currency.wrap(currency0),
            currency1: Currency.wrap(currency1),
            fee: liquidityProviderFee,
            tickSpacing: tickSpacing,
            hooks: hookContract
        });
        
        return true;
    }

    function depositCollateral(address owner) external view returns(bool success) {
        uint256 tokenId = posm.nextTokenId();
        
        console.log("--------- POSM Next Position Id is: ---------");
        console.log(tokenId);
        console.log('----- owner iz-----');
        console.log(owner);
        
        // IERC721(address(posm)).setApprovalForAll(zorkitronGeneratorAddr, true);
        // IERC721(address(posm)).transferFrom(owner, zorkitronGeneratorAddr, tokenId);

        return true;
    }


    function _unlockCallback(bytes calldata data) internal override returns (bytes memory) {
		
    
	}


}