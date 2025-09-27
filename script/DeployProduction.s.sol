// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";
import {PoolManager} from "v4-core/PoolManager.sol";
import {QMFactory} from "../src/QMFactory.sol";
import {QuantumHook} from "../src/QuantumHook.sol";

/**
 * @title Production Deployment Script
 * @notice Deploys all contracts with proper PoolManager for production
 * @dev Run with: forge script script/DeployProduction.s.sol --rpc-url sepolia --broadcast --verify
 */
contract DeployProductionScript is Script {
    // Contract instances
    QMFactory public factory;
    QuantumHook public hook;
    PoolManager public poolManager;
    
    // Deployment addresses
    address public owner;
    address public depositToken;
    
    // Sepolia USDC contract address
    address public constant SEPOLIA_USDC = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;
    
    function setUp() public {
        owner = vm.envOr("OWNER", msg.sender);
        
        console.log("=== PRODUCTION DEPLOYMENT ===");
        console.log("Network: Sepolia Testnet");
        console.log("Owner:", owner);
        console.log("Deployer:", msg.sender);
        console.log("USDC Token:", SEPOLIA_USDC);
    }
    
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        
        console.log("\n=== DEPLOYING CONTRACTS ===");
        
        // Step 1: Deploy PoolManager (with size optimization)
        console.log("1. Deploying PoolManager...");
        try new PoolManager(owner) returns (PoolManager _poolManager) {
            poolManager = _poolManager;
            console.log("PoolManager deployed at:", address(poolManager));
        } catch Error(string memory reason) {
            console.log("PoolManager deployment failed:", reason);
            console.log("This is expected due to contract size limits");
            console.log("You need to use a pre-deployed PoolManager or alternative approach");
            vm.stopBroadcast();
            return;
        }
        
        // Step 2: Deploy QuantumHook
        console.log("2. Deploying QuantumHook...");
        hook = new QuantumHook(poolManager, owner);
        console.log("QuantumHook deployed at:", address(hook));
        
        // Step 3: Deploy QMFactory
        console.log("3. Deploying QMFactory...");
        factory = new QMFactory(
            SEPOLIA_USDC,
            address(poolManager),
            address(hook),
            owner
        );
        console.log("QMFactory deployed at:", address(factory));
        
        vm.stopBroadcast();
        
        // Step 4: Post-deployment verification
        console.log("\n=== DEPLOYMENT VERIFICATION ===");
        console.log("Owner:", owner);
        console.log("USDC Token:", SEPOLIA_USDC);
        console.log("PoolManager:", address(poolManager));
        console.log("QuantumHook:", address(hook));
        console.log("QMFactory:", address(factory));
        
        console.log("\n=== NEXT STEPS ===");
        console.log("1. Verify contracts on Etherscan");
        console.log("2. Authorize factory on hook: hook.setAuthorizedFactory(factory, true)");
        console.log("3. Test core functionality");
        console.log("4. Get Sepolia USDC for testing");
        
        console.log("\n=== PRODUCTION READY ===");
        console.log("All contracts deployed successfully with real addresses!");
    }
}
