// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Hooks} from "v4-core/libraries/Hooks.sol";
import {PoolManager} from "v4-periphery/lib/v4-core/src/PoolManager.sol";
import {HookMiner} from "v4-periphery/src/utils/HookMiner.sol";
import {Constants} from "./base/Constants.sol";
import {ZorkitronRouter} from "../src/ZorkitronRouter.sol";
import {ZorkitronHook} from "../src/ZorkitronHook.sol";
import {MockERC20} from "src/MockERC20.sol";
import "forge-std/Script.sol";

/// @notice Mines the address and deploys the PointsHook.sol Hook contract
contract DeployZorkitronScript is Script {
    PoolManager manager = PoolManager(Constants.POOL_MANAGER);

    function setUp() public {
        // Get the deployer's private key from the environment
        uint256 privateKey = vm.envUint("METAMASK_PRIVATE_KEY");

        // Start a broadcast to deploy to the Sepolia testnet
        vm.startBroadcast(privateKey);

        // Deploy the Router using CREATE2
        bytes32 routerSalt = keccak256(abi.encodePacked(
            Constants.POOL_MANAGER,
            Constants.POSITION_MANAGER
        ));
        ZorkitronRouter zorkitronRouter = new ZorkitronRouter{salt: routerSalt}(
            Constants.POOL_MANAGER,
            Constants.POSITION_MANAGER
        );

        // Set up the Hook flags you wish to enable
        uint160 flags = uint160(Hooks.AFTER_ADD_LIQUIDITY_FLAG | Hooks.AFTER_REMOVE_LIQUIDITY_FLAG);

        // Mine a salt that will generate a Hook address with the correct flags
        (address hookAddress, bytes32 salt) = HookMiner.find(
            Constants.CREATE2_DEPLOYER,
            flags,
            type(ZorkitronHook).creationCode,
            abi.encode(Constants.POOL_MANAGER, zorkitronRouter)
        );

        // Deploy the Hook using CREATE2
        ZorkitronHook zorkitronHook = new ZorkitronHook{salt: salt}(
           PoolManager(Constants.POOL_MANAGER),
           address(zorkitronRouter)
        );
        require(address(zorkitronHook) == hookAddress, "DeployZorkitronScript: hook address mismatch");

        // Set the Hook contract in the Router
        zorkitronRouter.setHookContract(address(zorkitronHook));

        // Mint DAI tokens for testing
        MockERC20 daiToken = new MockERC20("DAI", "DAI", 18, 1_000_000 ether);

        // Initialize a new Liquidity Pool
        zorkitronRouter.initializePool(
            address(0),             // address _currency0 - ETH
            address(daiToken),      // address _currency1 - DAI
            10,                     // TICK_SPACING
            500,                    // LIQUIDITY_PROVIDER_FEE
            1,                      // AMOUNT_O_MAX
            1000,                   // AMOUNT_1_MAX
            Constants.ETH_TO_SEND
        );

        // Stop the broadcast
        vm.stopBroadcast();

        // Print the contract addresses
        console.log("ZorkitronHook Contract deployed to:", address(zorkitronHook));
        console.log("ZorkitronRouter Contract deployed to:", address(zorkitronRouter));
    }

    function run() pure public {
        console.log("Hello");
    }

}