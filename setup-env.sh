#!/bin/bash

# Quantum Market - Environment Setup Script
# This script helps you set up your deployment environment

echo "🚀 Quantum Market - Environment Setup"
echo "====================================="
echo ""

# Check if .env already exists
if [ -f ".env" ]; then
    echo "⚠️  .env file already exists!"
    read -p "Do you want to overwrite it? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ Setup cancelled. Your existing .env file is preserved."
        exit 1
    fi
fi

# Copy the example file
echo "📋 Creating .env file from template..."
cp env.example .env

echo "✅ .env file created successfully!"
echo ""
echo "🔧 Next steps:"
echo "1. Edit .env file and fill in your values:"
echo "   - PRIVATE_KEY: Your wallet's private key"
echo "   - OWNER: Address that will own the contracts"
echo "   - ETHERSCAN_API_KEY: (Optional) For contract verification"
echo "   - SEPOLIA_RPC_URL: (Optional) Your RPC endpoint"
echo ""
echo "2. Get Sepolia ETH from faucets:"
echo "   - https://sepoliafaucet.com/"
echo "   - https://faucet.sepolia.dev/"
echo ""
echo "3. Get Sepolia USDC for testing"
echo ""
echo "4. Deploy with:"
echo "   forge script script/Deploy.s.sol --rpc-url sepolia --broadcast --verify"
echo ""
echo "🔒 SECURITY REMINDER:"
echo "   - Never commit .env to git"
echo "   - Keep your private key secure"
echo "   - Use a dedicated wallet for deployment"
echo ""
echo "🎯 Ready for deployment!"
