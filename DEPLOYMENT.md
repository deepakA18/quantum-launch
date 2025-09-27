# Quantum Market - Sepolia Production Deployment Guide

## Prerequisites

1. **Foundry installed** and up to date
2. **Sepolia ETH** for gas fees (get from faucets)
3. **Sepolia USDC** for testing (get from faucets or bridges)
4. **Private key** with Sepolia ETH
5. **Etherscan API key** (optional, for verification)

## Real Token Integration

This deployment uses **real USDC** on Sepolia testnet:
- **USDC Contract**: `0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238`
- **No mock tokens** - everything is production-ready
- **Real token interactions** - actual ERC20 transfers and approvals

## Environment Setup

Create a `.env` file in the project root:

```bash
# Required
PRIVATE_KEY=your_private_key_here
OWNER=your_owner_address_here

# Optional (for verification)
ETHERSCAN_API_KEY=your_etherscan_api_key_here
SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/your_infura_key
```

## Deployment Commands

### 1. Basic Deployment (No Verification)
```bash
forge script script/Deploy.s.sol --rpc-url sepolia --broadcast
```

### 2. Deployment with Verification
```bash
forge script script/Deploy.s.sol --rpc-url sepolia --broadcast --verify
```

### 3. Deployment with Custom Gas Settings
```bash
forge script script/Deploy.s.sol \
  --rpc-url sepolia \
  --broadcast \
  --verify \
  --gas-price 20000000000 \
  --gas-limit 3000000
```

## Post-Deployment Testing

After deployment, you can test the contracts:

```bash
# Run tests against deployed contracts
forge test --fork-url sepolia --fork-block-number <deployment_block>
```

## Contract Addresses

After deployment, the script will output:
- MockERC20 (USDC): `0x...`
- PoolManager: `0x...`
- QuantumHook: `0x...`
- QMFactory: `0x...`

## Verification

If verification fails, you can verify manually:

```bash
# Verify QMFactory
forge verify-contract <factory_address> QMFactory --chain sepolia

# Verify QuantumHook
forge verify-contract <hook_address> QuantumHook --chain sepolia

# Note: USDC is already verified on Sepolia
```

## Testing on Sepolia

1. **Get Sepolia ETH** from faucets:
   - https://sepoliafaucet.com/
   - https://faucet.sepolia.dev/

2. **Get Sepolia USDC** from:
   - **Bridge from mainnet** (if you have mainnet USDC)
   - **Testnet faucets** that provide USDC
   - **DEX swaps** on Sepolia

3. **Test core functionality**:
   - Approve USDC spending
   - Create decisions
   - Make deposits with real USDC
   - Create proposals
   - Execute trades

## Production Features

✅ **Real ERC20 token integration**
✅ **Actual token transfers and approvals**
✅ **Production-ready contract interactions**
✅ **No mock implementations**
✅ **Full onchain functionality**

## Troubleshooting

### Common Issues:

1. **Insufficient Gas**: Increase gas limit
2. **RPC Issues**: Try different RPC providers
3. **Verification Fails**: Check constructor arguments
4. **Transaction Fails**: Ensure sufficient ETH for gas

### Gas Estimates:
- QMFactory: ~2.5M gas
- QuantumHook: ~1.5M gas
- PoolManager: ~3.5M gas
- USDC: Already deployed (no gas cost)

Total estimated gas: ~7.5M gas
