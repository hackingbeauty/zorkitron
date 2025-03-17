// SPDX-License-Identifier: MIT
pragma solidity=0.8.26;

import {PoolKey} from "v4-core/types/PoolKey.sol";
import {IZorkitronGenerator} from "./interfaces/IZorkitronGenerator.sol";
import {IPositionManager} from "v4-periphery/src/PositionManager.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PositionInfo} from "v4-periphery/src/libraries/PositionInfoLibrary.sol";
import {IERC721} from "forge-std/interfaces/IERC721.sol";
import "forge-std/console.sol";

// import {IPoolInitializer_v4} from "v4-core/src/interfaces/IPoolInitializer_v4.sol";
// import {IPositionManager} from "v4-periphery/src/interfaces/IPositionManager.sol";

// 8 STEPS! GOOD LUCK!
// 1 - Set up the Front-end - DONE
// STOP
// START
// 2 - Get the LP NFT transferred to the ZorkitronGenerator Smart Contract
// 3 - Convert the LP NFT into an ERC20 token type that can be used as collateral for a loan
// 4 - Deposit the collateral token into MakerDAO/SKY to generate a laon for token you can sell for ETH
// 5 - Use the loaned token and buy ETH with it
// 6 - Take the ETH and stake it into a Proof of Stake Validator
// 7 - Take the staked ETH and re-stake it into EigenLayer
// 8 - Withdraw all the original deposit plus the passive income profits & rewards!
// (PoolKey memory key, PositionInfo positionInfo) = posm.getPoolAndPositionInfo(1);

contract ZorkitronGenerator is IZorkitronGenerator {
    function depositCollateral(address owner, IPositionManager posm) external returns(bool success) {

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

    //Mint position first : https://docs.uniswap.org/contracts/v4/quickstart/manage-liquidity/mint-position
    //Docs: https://docs.uniswap.org/contracts/v4/quickstart/create-pool


    // constructor(address _positionManager) {
    //     posm =  IPositionManager(_positionManager);
    // }

    // function addLiquidity(
    //     address currency0,
    //     address currency1,
    //     address hookContract
    // ) internal returns (PositionInfo info) {   
    //     bytes[] memory params = new bytes[](2);

    //     PoolKey memory pool = PoolKey({
    //         currency0: currency0,
    //         currency1: currency1,
    //         fee: lpFee,
    //         tickSpacing: tickSpacing,
    //         hooks: hookContract
    //     });

    //     bytes memory actions = abi.encodePacked(uint8(Actions.MINT_POSITION), uint8(Actions.SETTLE_PAIR));
    //     bytes[] memory mintParams = new bytes[](2);
    //     mintParams[0] = abi.encode(pool, tickLower, tickUpper, liquidity, amount0Max, amount1Max, recipient, hookData);
    //     mintParams[1] = abi.encode(pool.currency0, pool.currency1);

    //     uint256 deadline = block.timestamp + 60;
    //     params[1] = abi.encodeWithSelector(
    //         posm.modifyLiquidities.selector, abi.encode(actions, mintParams), deadline
    //     );

    //     // approve permit2 as a spender
    //     IERC20(token).approve(address(permit2), type(uint256).max);

    //     // approve `PositionManager` as a spender
    //     IAllowanceTransfer(address(permit2)).approve(token, address(positionManager), type(uint160).max, type(uint48).max);

    //     PositionManager(posm).multicall(params);
    //     PositionManager(posm).multicall{value: ethToSend}(params);

    //     uint256 tokenId = 1111;
    //     (PoolKey memory poolKey, PositionInfo info) = getPoolAndPositionInfo(tokenId);
    //     return info;
    // }

    // function deposit(
    //     address currency0,
    //     address currency1,
    //     address hookContract
    // ) internal returns(boolean success) {
    //     require(true, "some error message");
    //     require(true, "some second error message");

    //     PositionInfo info = addLiquidity(currency0, currency1, hookContract);

        



    //     // Developer Docs: https://docs.makerdao.com/
    //     // https://github.com/makerdao
    //     // https://github.com/makerdao/developerguides
    //     // Collateral module: https://docs.makerdao.com/smart-contract-modules/collateral-module

    //     // uint daiTokens = IMakerDAO(makerDAOAddr).depositCollateral(liquidity);
    //     // so...after a deposit of liquidity...how does the Smart Contract code get access to the 
    //     // Liquidity Tokens that have been credited to the Liquidity
        
    //     daiTokens = IMakerDAO(makerDAOAddr).depositCollateral(liquidityTokens);

    //     // If this is not an ETH-TOKEN pool with this hook attached, ignore
    //     // if (!key.currency0.isAddressZero()) return (this.afterAddLiquidity.selector, delta);

    //     uint daiTokens = lockCollateral(liquidityTokens);
    //     uint ethTokens = swapDAIForETH(daiTokens);
    //     uint stakedETH = stakeETH(ethTokens);
    //     uint reStakedETH = restakeETH(stakedETH);

    //     // the hook can read what 
    //     // Mark, I think you need to use afterAddLiquidityReturnDelta hook for this
    // } 

    // function swapDAIForETH() internal returns (uint ethTokens) {
    //     require(true, "some error message");
    //     require(true, "some second error message");
    //     // IUniswapV3Router03(routerAddr).swap(daiTokens);
    // }

    // function stakeETH() internal returns (uint stakedETH) {
    //     require(true, "some error message");
    //     require(true, "some second error message");
    //     // Beacon deposit contract: https://etherscan.io/address/0x00000000219ab540356cBB839Cbe05303d7705Fa#code
    // }

    // function restakeETH() internal returns(uint reStakedETH) {
    //     require(true, "some error message");
    //     require(true, "some second error message");
    //     // Eigen Layer Smart Contract call
    // }

    // function withdrawLiquidity() external returns(uint amountTokenA, uint amountTokenB, uint returnedETH) {
    //     require(true, "some error message");
    //     require(true, "some second error message");
    //     // withdraw all the DeFi passive income
    // }
    

}