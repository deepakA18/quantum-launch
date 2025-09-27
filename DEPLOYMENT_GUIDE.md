# 🚀 Quantum Market - Sepolia Deployment Guide

## ⚠️ Important: Contract Size Limitation

The Uniswap V4 PoolManager contract exceeds Ethereum's contract size limit (24,576 bytes). We need to deploy it separately.

## 🎯 Two-Step Deployment Process

### Step 1: Deploy Our Contracts (Minimal)

```bash
forge script script/DeployMinimal.s.sol --rpc-url sepolia --broadcast --verify
```

This deploys:
- ✅ **QuantumHook** - Our custom hook
- ✅ **QMFactory** - Main factory contract  
- ✅ **Real USDC integration** - Uses actual USDC on Sepolia

### Step 2: Deploy PoolManager Separately

```bash
forge create v4-core/PoolManager.sol:PoolManager \
  --constructor-args 0x5eE90eB846B5Bd55a14D8bA810F64986dc7D4e85 \
  --rpc-url sepolia \
  --broadcast \
  --verify
```

Replace `0x5eE90eB846B5Bd55a14D8bA810F64986dc7D4e85` with your owner address.

## 📋 Complete Deployment Commands

### 1. Environment Setup
```bash
# Copy and configure environment
cp env.example .env
# Edit .env with your values
```

### 2. Deploy Our Contracts
```bash
forge script script/DeployMinimal.s.sol \
  --rpc-url sepolia \
  --broadcast \
  --verify
```

### 3. Deploy PoolManager
```bash
forge create v4-core/PoolManager.sol:PoolManager \
  --constructor-args <YOUR_OWNER_ADDRESS> \
  --rpc-url sepolia \
  --broadcast \
  --verify
```

### 4. Update PoolManager Address
After PoolManager deployment, you'll need to update the contracts with the real PoolManager address.

## 🔧 Post-Deployment Configuration

### 1. Authorize Factory on Hook
```solidity
// Call this function on the deployed QuantumHook contract
hook.setAuthorizedFactory(factoryAddress, true);
```

### 2. Verify All Contracts
Check that all contracts are verified on Etherscan:
- QuantumHook
- QMFactory  
- PoolManager

### 3. Test with Real USDC
- Get Sepolia USDC from faucets or bridges
- Approve USDC spending for the factory
- Create test decisions and proposals

## 🎯 Production Features

✅ **Real ERC20 token integration**
✅ **No mock implementations**  
✅ **Actual token transfers**
✅ **Production-ready contracts**
✅ **Full onchain functionality**

## 🚨 Troubleshooting

### Contract Size Issues
- PoolManager is too large for single deployment
- Use the two-step deployment process above
- Consider using factory patterns for large contracts

### Gas Estimation
- Our contracts: ~10.6M gas
- PoolManager: ~20M+ gas (deploy separately)
- Total: ~30M+ gas across both deployments

### RPC Issues
If you get RPC errors, try:
```bash
# Use different RPC providers
--rpc-url https://rpc.sepolia.org
--rpc-url https://eth-sepolia.g.alchemy.com/v2/YOUR_KEY
```

## 🎉 Success!

Once deployed, you'll have a fully functional quantum market on Sepolia with:
- Real USDC integration
- Production-ready contracts
- Complete onchain functionality
- No mock implementations

Ready for mainnet deployment! 🚀
