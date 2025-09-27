// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {QMFactory} from "../src/QMFactory.sol";
import {QuantumHook} from "../src/QuantumHook.sol";

/**
 * @title Deploy Minimal Contracts Script
 * @notice Deploys only the essential contracts without PoolManager
 * @dev Run with: forge script script/DeployMinimalContracts.s.sol --rpc-url sepolia --broadcast --verify
 */
contract DeployMinimalContractsScript is Script {
    // Contract instances
    QMFactory public factory;
    QuantumHook public hook;
    
    // Deployment addresses
    address public owner;
    address public depositToken; // Real token address (USDC or other)
    address public poolManager; // Placeholder for now
    
    // Sepolia USDC contract address (real token)
    address public constant SEPOLIA_USDC = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;
    
    // Placeholder PoolManager - will be updated later
    address public constant PLACEHOLDER_POOL_MANAGER = address(0x1111111111111111111111111111111111111111);
    
    function setUp() public {
        // Set owner from environment variable or use deployer
        owner = vm.envOr("OWNER", msg.sender);
        
        console.log("Minimal Contracts Deployment Configuration:");
        console.log("- Network: Sepolia Testnet");
        console.log("- Owner:", owner);
        console.log("- Deployer:", msg.sender);
    }
    
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        
        console.log("Starting minimal contracts deployment...");
        
        // Step 1: Set up real USDC token
        console.log("1. Using real USDC token on Sepolia...");
        depositToken = SEPOLIA_USDC;
        console.log("USDC token address:", depositToken);
        
        // Step 2: Use placeholder PoolManager for now
        console.log("2. Using placeholder PoolManager (will be updated later)...");
        poolManager = PLACEHOLDER_POOL_MANAGER;
        console.log("PoolManager address:", poolManager);
        console.log("WARNING: This is a placeholder - PoolManager needs to be deployed separately!");
        
        // Step 3: Deploy QuantumHook
        console.log("3. Deploying QuantumHook...");
        hook = new QuantumHook(IPoolManager(poolManager), owner);
        console.log("QuantumHook deployed at:", address(hook));
        
        // Step 4: Deploy QMFactory
        console.log("4. Deploying QMFactory...");
        factory = new QMFactory(
            depositToken,
            poolManager,
            address(hook),
            owner
        );
        console.log("QMFactory deployed at:", address(factory));
        
        // Step 5: Configuration complete
        console.log("5. Configuration complete");
        
        vm.stopBroadcast();
        
        // Step 6: Deployment summary
        console.log("\n=== MINIMAL DEPLOYMENT COMPLETE ===");
        console.log("Network: Sepolia Testnet");
        console.log("Owner:", owner);
        console.log("\nContract Addresses:");
        console.log("- USDC Token:", depositToken);
        console.log("- PoolManager:", poolManager, "(PLACEHOLDER - needs real deployment)");
        console.log("- QuantumHook:", address(hook));
        console.log("- QMFactory:", address(factory));
        
        console.log("\nNext Steps:");
        console.log("1. Deploy PoolManager separately (due to size limits)");
        console.log("2. Update PoolManager address in contracts");
        console.log("3. Authorize factory on hook");
        console.log("4. Verify contracts on Etherscan");
        console.log("5. Get Sepolia USDC for testing");
        console.log("6. Test core functionality");
        
        console.log("\nPoolManager Deployment Options:");
        console.log("Option 1: Use a pre-deployed PoolManager from Uniswap");
        console.log("Option 2: Deploy a minimal PoolManager implementation");
        console.log("Option 3: Use a different approach for the hook system");
    }
}
