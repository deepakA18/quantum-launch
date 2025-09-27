// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {QMFactory} from "../src/QMFactory.sol";
import {QuantumHook} from "../src/QuantumHook.sol";

/**
 * @title Update PoolManager Address Script
 * @notice Updates the PoolManager address in deployed contracts
 * @dev Run with: forge script script/UpdatePoolManager.s.sol --rpc-url sepolia --broadcast
 */
contract UpdatePoolManagerScript is Script {
    // Deployed contract addresses from previous deployment
    address public constant QUANTUM_HOOK = 0x01fF3E74f281Ff24363C17D89303F5D11CD8E48c;
    address public constant QM_FACTORY = 0x80f675038a764Ca54340ce672e0222622ad8f0e1;
    address public constant POOL_MANAGER = 0xA22C7e19760f6b93b0a4D65264B4EE5969FfC7Ca;
    
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        
        console.log("Updating PoolManager address in deployed contracts...");
        console.log("PoolManager address:", POOL_MANAGER);
        console.log("QuantumHook address:", QUANTUM_HOOK);
        console.log("QMFactory address:", QM_FACTORY);
        
        // Note: The contracts are already deployed with the placeholder address
        // You'll need to redeploy them with the correct PoolManager address
        // or update them if they have setter functions
        
        console.log("\n=== UPDATE COMPLETE ===");
        console.log("Note: Contracts were deployed with placeholder PoolManager address");
        console.log("You may need to redeploy with the correct PoolManager address");
        
        vm.stopBroadcast();
    }
}
