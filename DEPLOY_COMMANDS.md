# 🚀 Quantum Market - Sepolia Deployment Commands

## Quick Start

### 1. Set up environment variables
```bash
export PRIVATE_KEY="your_private_key_here"
export OWNER="your_owner_address_here"
export ETHERSCAN_API_KEY="your_etherscan_api_key_here"
```

### 2. Deploy to Sepolia
```bash
forge script script/Deploy.s.sol --rpc-url sepolia --broadcast --verify
```

### 3. Alternative deployment options

**Without verification:**
```bash
forge script script/Deploy.s.sol --rpc-url sepolia --broadcast
```

**With custom gas settings:**
```bash
forge script script/Deploy.s.sol \
  --rpc-url sepolia \
  --broadcast \
  --verify \
  --gas-price 20000000000 \
  --gas-limit 3000000
```

**Using environment file:**
```bash
# Create .env file with your variables
forge script script/Deploy.s.sol --rpc-url sepolia --broadcast --verify
```

## What Gets Deployed

✅ **PoolManager** - Uniswap V4 PoolManager
✅ **QuantumHook** - Custom hook for quantum mechanics  
✅ **QMFactory** - Main factory contract
✅ **Real USDC Integration** - Uses actual USDC on Sepolia

## After Deployment

1. **Save contract addresses** from the deployment output
2. **Verify contracts** on Etherscan (if not auto-verified)
3. **Get Sepolia USDC** for testing
4. **Test core functionality** with real tokens

## Production Ready Features

🎯 **No mock tokens** - Everything uses real USDC
🎯 **Real token transfers** - Actual ERC20 interactions
🎯 **Production contracts** - Ready for mainnet
🎯 **Full onchain functionality** - Complete quantum market system

## Need Help?

- Check `DEPLOYMENT.md` for detailed instructions
- Ensure you have Sepolia ETH for gas fees
- Get Sepolia USDC from testnet faucets or bridges
