"use client"

import type React from "react"

import { WagmiProvider, createConfig, http } from "wagmi"
import {sepolia } from "wagmi/chains"
import { QueryClient, QueryClientProvider } from "@tanstack/react-query"
import { RainbowKitProvider } from "@rainbow-me/rainbowkit"
import { injected } from "@wagmi/connectors"

const config = createConfig({
  chains: [sepolia], 
  connectors: [injected()],
  transports: {
    [sepolia.id]: http(),
  },
  ssr: true,
})

const queryClient = new QueryClient()

export default function WalletProvider({ children }: { children: React.ReactNode }) {
  return (
    <WagmiProvider config={config}>
      <QueryClientProvider client={queryClient}>
        <RainbowKitProvider initialChain={sepolia}>
          {children}
        </RainbowKitProvider>
      </QueryClientProvider>
    </WagmiProvider>
  )
}
