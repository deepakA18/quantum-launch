// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {QMFactory} from "../src/QMFactory.sol";
import {QuantumHook} from "../src/QuantumHook.sol";

/**
 * @title Quantum Market Minimal Deployment Script
 * @notice Deploys only our contracts, skips PoolManager due to size limits
 * @dev Run with: forge script script/DeployMinimal.s.sol --rpc-url sepolia --broadcast --verify
 */
contract DeployMinimalScript is Script {
    // Contract instances
    QMFactory public factory;
    QuantumHook public hook;
    
    // Deployment addresses
    address public owner;
    address public depositToken; // Real token address (USDC or other)
    IPoolManager public poolManager; // PoolManager address (deploy separately)
    
    // Sepolia USDC contract address (real token)
    address public constant SEPOLIA_USDC = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;
    
    // Placeholder PoolManager - you'll need to deploy this separately
    address public constant PLACEHOLDER_POOL_MANAGER = address(0x1111111111111111111111111111111111111111);
    
    function setUp() public {
        // Set owner from environment variable or use deployer
        owner = vm.envOr("OWNER", msg.sender);
        
        console.log("Minimal Deployment Configuration:");
        console.log("- Network: Sepolia Testnet");
        console.log("- Owner:", owner);
        console.log("- Deployer:", msg.sender);
    }
    
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        
        console.log("Starting minimal deployment to Sepolia...");
        
        // Step 1: Set up real USDC token
        console.log("1. Using real USDC token on Sepolia...");
        depositToken = SEPOLIA_USDC;
        console.log("USDC token address:", depositToken);
        
        // Step 2: Use placeholder PoolManager
        console.log("2. Using placeholder PoolManager...");
        poolManager = IPoolManager(PLACEHOLDER_POOL_MANAGER);
        console.log("PoolManager address:", address(poolManager));
        console.log("WARNING: You need to deploy PoolManager separately!");
        
        // Step 3: Deploy QuantumHook
        console.log("3. Deploying QuantumHook...");
        hook = new QuantumHook(poolManager, owner);
        console.log("QuantumHook deployed at:", address(hook));
        
        // Step 4: Deploy QMFactory
        console.log("4. Deploying QMFactory...");
        factory = new QMFactory(
            depositToken,
            address(poolManager),
            address(hook),
            owner
        );
        console.log("QMFactory deployed at:", address(factory));
        
        // Step 5: Configuration note
        console.log("5. Configuration complete");
        console.log("Note: Update PoolManager address in contracts after deployment");
        
        vm.stopBroadcast();
        
        // Step 6: Deployment summary
        console.log("\n=== MINIMAL DEPLOYMENT COMPLETE ===");
        console.log("Network: Sepolia Testnet");
        console.log("Owner:", owner);
        console.log("\nContract Addresses:");
        console.log("- USDC Token:", depositToken);
        console.log("- PoolManager:", address(poolManager), "(PLACEHOLDER - deploy separately)");
        console.log("- QuantumHook:", address(hook));
        console.log("- QMFactory:", address(factory));
        
        console.log("\nNext Steps:");
        console.log("1. Deploy PoolManager separately (due to size limits)");
        console.log("2. Update PoolManager address in contracts");
        console.log("3. Authorize factory on hook");
        console.log("4. Verify contracts on Etherscan");
        console.log("5. Get Sepolia USDC for testing");
        console.log("6. Test core functionality");
        
        console.log("\nPoolManager Deployment Command:");
        console.log("forge create v4-core/PoolManager.sol:PoolManager --constructor-args", owner, "--rpc-url sepolia --broadcast --verify");
    }
}
