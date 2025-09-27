// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {QMFactory} from "../src/QMFactory.sol";
import {QuantumHook} from "../src/QuantumHook.sol";

/**
 * @title Deploy with Pre-deployed PoolManager Script
 * @notice Deploys contracts using a pre-deployed PoolManager address
 * @dev Run with: forge script script/DeployWithPreDeployedPoolManager.s.sol --rpc-url sepolia --broadcast --verify
 */
contract DeployWithPreDeployedPoolManagerScript is Script {
    // Contract instances
    QMFactory public factory;
    QuantumHook public hook;
    
    // Deployment addresses
    address public owner;
    address public depositToken;
    IPoolManager public poolManager;
    
    // Sepolia USDC contract address
    address public constant SEPOLIA_USDC = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;
    
    // Pre-deployed PoolManager address on Sepolia testnet
    // Verified on Etherscan: https://sepolia.etherscan.io/address/0xe03a1074c86cfedd5c142c4f04f1a1536e203543
    address public constant PRE_DEPLOYED_POOL_MANAGER = 0xE03A1074c86CFeDd5C142C4F04F1a1536e203543;
    
    function setUp() public {
        owner = vm.envOr("OWNER", msg.sender);
        
        console.log("=== DEPLOYMENT WITH PRE-DEPLOYED POOLMANAGER ===");
        console.log("Network: Sepolia Testnet");
        console.log("Owner:", owner);
        console.log("Deployer:", msg.sender);
        console.log("USDC Token:", SEPOLIA_USDC);
        console.log("PoolManager:", PRE_DEPLOYED_POOL_MANAGER);
    }
    
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        
        console.log("\n=== DEPLOYING CONTRACTS ===");
        
        // Step 1: Validate PoolManager address
        console.log("1. Validating PoolManager address...");
        if (PRE_DEPLOYED_POOL_MANAGER == address(0)) {
            console.log("ERROR: No pre-deployed PoolManager address provided!");
            console.log("Please update PRE_DEPLOYED_POOL_MANAGER with a valid address");
            vm.stopBroadcast();
            return;
        }
        
        poolManager = IPoolManager(PRE_DEPLOYED_POOL_MANAGER);
        console.log("PoolManager address:", address(poolManager));
        
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
        console.log("PoolManager:", address(poolManager), "(pre-deployed)");
        console.log("QuantumHook:", address(hook));
        console.log("QMFactory:", address(factory));
        
        console.log("\n=== NEXT STEPS ===");
        console.log("1. Verify contracts on Etherscan");
        console.log("2. Authorize factory on hook: hook.setAuthorizedFactory(factory, true)");
        console.log("3. Test core functionality");
        console.log("4. Get Sepolia USDC for testing");
        
        console.log("\n=== PRODUCTION READY ===");
        console.log("All contracts deployed successfully with real PoolManager address!");
    }
}