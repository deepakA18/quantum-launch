"use client"

import type React from "react"

import { WagmiProvider, createConfig, http } from "wagmi"
import { mainnet, base, arbitrum, polygon, sepolia } from "wagmi/chains"
import { QueryClient, QueryClientProvider } from "@tanstack/react-query"
import { RainbowKitProvider } from "@rainbow-me/rainbowkit"
import { injected } from "@wagmi/connectors"

const config = createConfig({
  chains: [mainnet, base, arbitrum, polygon, sepolia],
  connectors: [injected()],
  transports: {
    [mainnet.id]: http(),
    [base.id]: http(),
    [arbitrum.id]: http(),
    [polygon.id]: http(),
    [sepolia.id]: http(),
  },
  ssr: true,
})

const queryClient = new QueryClient()

export default function WalletProvider({ children }: { children: React.ReactNode }) {
  return (
    <WagmiProvider config={config}>
      <QueryClientProvider client={queryClient}>
        <RainbowKitProvider>
          {children}
        </RainbowKitProvider>
      </QueryClientProvider>
    </WagmiProvider>
  )
}
