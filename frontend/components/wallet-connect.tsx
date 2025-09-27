"use client"

import { ConnectButton } from "@rainbow-me/rainbowkit"
import { useEffect } from "react"
import { useConnect, useAccount } from "wagmi"

export default function WalletConnectButton() {
  const { connect, connectors } = useConnect()
  const { isConnected } = useAccount()

  useEffect(() => {
    if (!isConnected && typeof window !== "undefined") {
      const injectedConnector = connectors.find((connector) => connector.type === "injected")
      if (injectedConnector) {
        setTimeout(() => {
          connect({ connector: injectedConnector })
        }, 100)
      }
    }
  }, [isConnected, connect, connectors])

  return <ConnectButton />
}