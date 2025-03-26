// SPDX-License-Identifier: MIT
pragma solidity=0.8.26;

import {PoolKey} from "v4-core/types/PoolKey.sol";
import {IZorkitronRouter} from "./interfaces/IZorkitronRouter.sol";
import {IPositionManager} from "v4-periphery/src/PositionManager.sol";
import {IERC721} from "forge-std/interfaces/IERC721.sol";
import {SafeCallback} from "v4-periphery/src/base/SafeCallback.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {IPoolInitializer_v4} from "v4-periphery/src/interfaces/IPoolInitializer_v4.sol";
import {IERC20} from "lib/forge-std/src/interfaces/IERC20.sol";
import {IAllowanceTransfer} from "v4-periphery/lib/permit2/src/interfaces/IAllowanceTransfer.sol";
import {IHooks} from "v4-periphery/lib/v4-core/src/interfaces/IHooks.sol";
import {Actions} from "v4-periphery/src/libraries/Actions.sol";
import {ZorkitronHook} from "../src/ZorkitronHook.sol";
import {Currency, CurrencyLibrary} from "v4-core/types/Currency.sol";
import {ZorkitronLibrary} from "./libraries/ZorkitronLibrary.sol";
import { UD60x18, intoUint256, floor, sqrt, ud60x18} from "@prb/math/src/UD60x18.sol";
import "forge-std/console.sol";

contract ZorkitronRouter is IZorkitronRouter {
    IPoolManager poolManager;
	IPositionManager posm;
    ZorkitronHook hookContract;
    PoolKey pool;
    using CurrencyLibrary for Currency;
   
    constructor(
        address _poolManager,
        address _posm
    ) {
        poolManager = IPoolManager(_poolManager);
        posm = IPositionManager(_posm);
    }

    function setHookContract(ZorkitronHook _hookContract) external {
        hookContract = _hookContract;
    }

    function initializePool(
        address _currency0,
        address _currency1,
        int24 _tickSpacing,
        uint24 _liquidityProviderFee,
        uint128 amount0Max,
        uint128 amount1Max,
        uint256 ethToSend
    ) external returns(bool success) {
        // Step 1 - Sort currencies
        (address currency0, address currency1) = ZorkitronLibrary.sortTokens(_currency0, _currency1);

        // Step 2 - Wrap currencies
        Currency currencyA = Currency.wrap(currency0);
        Currency currencyB = Currency.wrap(currency1);

        // Step 3 - If Native ETH is part of the token pair, use ADDRESS_ZERO
        // if(_currency0isETH) { currencyA = CurrencyLibrary.ADDRESS_ZERO; }

        // Step 4 - Configure the pool
        pool = PoolKey({
            currency0: currencyA,
            currency1: currencyB,
            fee: _liquidityProviderFee,
            tickSpacing: _tickSpacing,
            hooks: hookContract
        });

        // Step 5 - Calculate startingPrice
        uint160 startingPrice = calculateStartingPrice(amount0Max, amount1Max);

        // Step 6 - Call initialize - Pools are initiated with a starting price
        poolManager.initialize(pool, startingPrice);

        // Step 7 - Encode the initializePool parameters provided to multicall
        bytes[] memory params = new bytes[](1);
        params[0] = abi.encodeWithSelector(
            IPoolInitializer_v4.initializePool.selector,
            pool,
            startingPrice
        );    
        
        // Step 8 - Make a multicall
        IPositionManager(posm).multicall(params);         
        return success;
    }

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
    ) external returns(bool success) {
        // Step 1 - Sort currencies
        (address currency0, address currency1) = ZorkitronLibrary.sortTokens(_currency0, _currency1);
        
        // Step 2 - Initialize the mint-liquidity parameters
        bytes memory actions = abi.encodePacked(
            uint8(Actions.MINT_POSITION),
            uint8(Actions.SETTLE_PAIR)
        );

        // Step 3 - Encode the MINT_POSITION parameters
        bytes[] memory mintParams = new bytes[](2);
        mintParams[0] = abi.encode(
            pool,
            tickLower,
            tickUpper,
            liquidity,
            amount0Max,
            amount1Max,
            address(this), // ZorkitronRouter is recipient of LP NFT position    
            hookData
        );

        // Step 4 - Encode the SETTLE_PAIR parameters
        mintParams[1] = abi.encode(pool.currency0, pool.currency1);

        // Step 5 - Encode the modifyLiquidities call
        uint256 deadline = block.timestamp + 60;
        bytes[] memory params = new bytes[](1);
        params[0] = abi.encodeWithSelector(
            posm.modifyLiquidities.selector,
            abi.encode(actions, mintParams),
            deadline
        );

        // Step 6 - Approve the tokens by first approving the ZorkitronRouter as a spender
        IERC20(currency0).approve(address(this), type(uint256).max);
        IERC20(currency1).approve(address(this), type(uint256).max);

        // Step 7 - Then, approve the 'PositionManager' as a spender
        IAllowanceTransfer(address(this)).approve(currency0, address(posm), type(uint160).max, type(uint48).max);
        IAllowanceTransfer(address(this)).approve(currency1, address(posm), type(uint160).max, type(uint48).max);

        // Step 8 - Execute the multicall
        IPositionManager(posm).multicall(params); 
        return true;
    }
    
    //TO DO
    function removeLiquidity(address owner) external pure returns (bool success) {
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
        // This function is crucial for applications that need to manage or analyze individual 
        // liquidity positions: posm.getPositionInfo() 
        return true;
    }

    function calculateStartingPrice(
        uint128 amount0Max,
        uint128 amount1Max
    ) internal pure returns(uint160 startingPrice) {
        UD60x18 amt0Max = ud60x18(amount0Max);
        UD60x18 amt1Max = ud60x18(amount1Max);
        UD60x18 val1 = ud60x18(2);
        UD60x18 val2 = ud60x18(96);

        startingPrice = uint160(intoUint256(floor(sqrt(amt0Max.div(amt1Max))).mul(val1.pow(val2))));
    }

}