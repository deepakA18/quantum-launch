// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {QMFactory} from "../src/QMFactory.sol";
import {QuantumHook} from "../src/QuantumHook.sol";

/**
 * @title Deploy with Pre-deployed PoolManager Script
 * @notice Deploys contracts using a pre-deployed PoolManager
 * @dev Run with: forge script script/DeployWithPreDeployedPoolManager.s.sol --rpc-url sepolia --broadcast --verify
 */
contract DeployWithPreDeployedPoolManagerScript is Script {
    // Contract instances
    QMFactory public factory;
    QuantumHook public hook;
    
    // Deployment addresses
    address public owner;
    address public depositToken; // Real token address (USDC or other)
    IPoolManager public poolManager; // Pre-deployed PoolManager
    
    // Sepolia USDC contract address (real token)
    address public constant SEPOLIA_USDC = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;
    
    // Pre-deployed PoolManager on Sepolia (if available)
    // Note: You may need to deploy PoolManager separately or use a different approach
    address public constant PRE_DEPLOYED_POOL_MANAGER = address(0x0000000000000000000000000000000000000000);
    
    function setUp() public {
        // Set owner from environment variable or use deployer
        owner = vm.envOr("OWNER", msg.sender);
        
        console.log("Deployment with Pre-deployed PoolManager Configuration:");
        console.log("- Network: Sepolia Testnet");
        console.log("- Owner:", owner);
        console.log("- Deployer:", msg.sender);
    }
    
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        
        console.log("Starting deployment with pre-deployed PoolManager...");
        
        // Step 1: Set up real USDC token
        console.log("1. Using real USDC token on Sepolia...");
        depositToken = SEPOLIA_USDC;
        console.log("USDC token address:", depositToken);
        
        // Step 2: Use pre-deployed PoolManager
        console.log("2. Using pre-deployed PoolManager...");
        poolManager = IPoolManager(PRE_DEPLOYED_POOL_MANAGER);
        console.log("PoolManager address:", address(poolManager));
        
        if (address(poolManager) == address(0)) {
            console.log("WARNING: No pre-deployed PoolManager found!");
            console.log("You need to deploy PoolManager separately or use a different approach.");
            vm.stopBroadcast();
            return;
        }
        
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
        
        // Step 5: Configuration complete
        console.log("5. Configuration complete");
        
        vm.stopBroadcast();
        
        // Step 6: Deployment summary
        console.log("\n=== DEPLOYMENT COMPLETE ===");
        console.log("Network: Sepolia Testnet");
        console.log("Owner:", owner);
        console.log("\nContract Addresses:");
        console.log("- USDC Token:", depositToken);
        console.log("- PoolManager:", address(poolManager), "(pre-deployed)");
        console.log("- QuantumHook:", address(hook));
        console.log("- QMFactory:", address(factory));
        
        console.log("\nNext Steps:");
        console.log("1. Deploy PoolManager separately if not pre-deployed");
        console.log("2. Authorize factory on hook");
        console.log("3. Verify contracts on Etherscan");
        console.log("4. Get Sepolia USDC for testing");
        console.log("5. Test core functionality");
    }
}
