// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {HookMiner} from "@uniswap/v4-periphery/src/utils/HookMiner.sol";
import {BaseScript} from "./base/BaseScript.sol";
import {ZorkitronHook} from "../src/ZorkitronHook.sol";
import {ZorkitronRouter} from "../src/ZorkitronRouter.sol";

/// @notice Mines the address and deploys the Counter.sol Hook contract
contract DeployHookScript is BaseScript {
    function run() public {
        // hook contracts must have specific flags encoded in the address
        uint160 flags = uint160(Hooks.AFTER_ADD_LIQUIDITY_FLAG | Hooks.AFTER_REMOVE_LIQUIDITY_FLAG);

        // Mine a salt that will produce a hook address with the correct flags
        bytes memory constructorArgs = abi.encode(poolManager);
        (address hookAddress, bytes32 salt) =
            HookMiner.find(CREATE2_FACTORY, flags, type(ZorkitronHook).creationCode, constructorArgs);

        // Deploy the Zorkitron Router
        vm.startBroadcast();
        ZorkitronRouter zorkitronRouter = new ZorkitronRouter();
        vm.stopBroadcast();

        // Deploy the hook using CREATE2
        vm.startBroadcast();
        ZorkitronHook hook = new ZorkitronHook{salt: salt}(poolManager, positionManager, address(zorkitronRouter));
        vm.stopBroadcast();

        require(address(hook) == hookAddress, "DeployHookScript: Hook Address Mismatch");
    }
}
