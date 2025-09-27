// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";
import {PoolManager} from "v4-core/PoolManager.sol";

/**
 * @title PoolManager Deployment Script
 * @notice Deploys only the PoolManager contract
 * @dev Run with: forge script script/DeployPoolManager.s.sol --rpc-url sepolia --broadcast --verify
 */
contract DeployPoolManagerScript is Script {
    PoolManager public poolManager;
    
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        
        console.log("Deploying PoolManager to Sepolia...");
        
        // Deploy PoolManager
        poolManager = new PoolManager(msg.sender);
        console.log("PoolManager deployed at:", address(poolManager));
        
        vm.stopBroadcast();
        
        console.log("\n=== POOLMANAGER DEPLOYMENT COMPLETE ===");
        console.log("PoolManager address:", address(poolManager));
        console.log("Owner:", msg.sender);
    }
}
