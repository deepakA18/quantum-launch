# Quantum Market - Contract ABIs

This folder contains the ABIs (Application Binary Interfaces) for all deployed contracts on Sepolia testnet.

## Deployed Contract Addresses

| Contract | Address | ABI File | Description |
|----------|---------|----------|-------------|
| **PoolManager** | `0xE03A1074c86CFeDd5C142C4F04F1a1536e203543` | `PoolManager.json` | Pre-deployed Uniswap v4 PoolManager |
| **QuantumHook** | `0x15df43E9c4bc309a39227bBc6De5054Cb3DC0025` | `QuantumHook.json` | Custom hook for quantum market logic |
| **QMFactory** | `0x6124f03F5D4B32a2163BA5E55C973ADC57E4e755` | `QMFactory.json` | Main factory contract for creating decisions |
| **MathUtils** | `0xe557394ac7d7e414cdee58ba0984a782b4debc1e` | `MathUtils.json` | Utility library for mathematical operations |
| **IPoolManager** | N/A | `IPoolManager.json` | Interface for PoolManager contract |

## Network Information

- **Network**: Sepolia Testnet
- **Chain ID**: 11155111
- **Owner**: `0x5eE90eB846B5Bd55a14D8bA810F64986dc7D4e85`
- **USDC Token**: `0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238`

## Usage

These ABIs can be used with:
- Web3.js
- Ethers.js
- Hardhat
- Foundry
- Any Ethereum development framework

## Example Usage

```javascript
// Using ethers.js
const quantumHookABI = require('./QuantumHook.json');
const hook = new ethers.Contract(
  '0x15df43E9c4bc309a39227bBc6De5054Cb3DC0025',
  quantumHookABI.abi,
  provider
);
```

## Verification

All contracts are verified on Sepolia Etherscan:
- [QuantumHook](https://sepolia.etherscan.io/address/0x15df43E9c4bc309a39227bBc6De5054Cb3DC0025)
- [QMFactory](https://sepolia.etherscan.io/address/0x6124f03F5D4B32a2163BA5E55C973ADC57E4e755)
- [PoolManager](https://sepolia.etherscan.io/address/0xE03A1074c86CFeDd5C142C4F04F1a1536e203543)

## Deployment Date

Deployed on: September 27, 2024
