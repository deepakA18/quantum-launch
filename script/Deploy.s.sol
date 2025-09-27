// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";
import {PoolManager} from "v4-core/PoolManager.sol";
import {QMFactory} from "../src/QMFactory.sol";
import {QuantumHook} from "../src/QuantumHook.sol";

/**
 * @title Quantum Market Deployment Script
 * @notice Deploys all contracts for the quantum market on Sepolia testnet
 * @dev Run with: forge script script/Deploy.s.sol --rpc-url sepolia --broadcast --verify
 */
contract DeployScript is Script {
    // Contract instances
    QMFactory public factory;
    QuantumHook public hook;
    PoolManager public poolManager;
    
    // Deployment addresses
    address public owner;
    address public depositToken; // Real token address (USDC or other)
    
    // Sepolia USDC contract address (real token)
    address public constant SEPOLIA_USDC = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;
    
    // Use a placeholder for PoolManager - deploy separately
    address public constant PLACEHOLDER_POOL_MANAGER = address(0x1111111111111111111111111111111111111111);
    
    function setUp() public {
        // Set owner from environment variable or use deployer
        owner = vm.envOr("OWNER", msg.sender);
        
        console.log("Deployment Configuration:");
        console.log("- Network: Sepolia Testnet");
        console.log("- Owner:", owner);
        console.log("- Deployer:", msg.sender);
    }
    
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        
        console.log("Starting deployment to Sepolia...");
        
        // Step 1: Set up real USDC token
        console.log("1. Using real USDC token on Sepolia...");
        depositToken = SEPOLIA_USDC;
        console.log("USDC token address:", depositToken);
        
        // Step 2: Deploy PoolManager (with size optimization)
        console.log("2. Deploying PoolManager...");
        poolManager = new PoolManager(owner);
        console.log("PoolManager deployed at:", address(poolManager));
        
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
        
        // Step 5: Configure contracts
        console.log("5. Configuring contracts...");
        
        // Note: Hook authorization will need to be done manually after deployment
        // or by the owner address directly
        console.log("Note: Hook authorization needs to be done by owner after deployment");
        
        // Step 6: Token setup complete
        console.log("6. Token setup complete - using real USDC");
        console.log("Note: You'll need to acquire USDC on Sepolia for testing");
        
        vm.stopBroadcast();
        
        // Step 7: Verification info
        console.log("\n=== DEPLOYMENT COMPLETE ===");
        console.log("Network: Sepolia Testnet");
        console.log("Owner:", owner);
        console.log("\nContract Addresses:");
        console.log("- USDC Token:", depositToken);
        console.log("- PoolManager:", address(poolManager));
        console.log("- QuantumHook:", address(hook));
        console.log("- QMFactory:", address(factory));
        
        console.log("\nNext Steps:");
        console.log("1. Authorize factory on hook (call hook.setAuthorizedFactory(factory, true) as owner)");
        console.log("2. Verify contracts on Etherscan");
        console.log("3. Get Sepolia USDC for testing");
        console.log("4. Test core functionality");
        console.log("5. Create test decisions and proposals");
        
        // Deployment info displayed above
    }
    
}
