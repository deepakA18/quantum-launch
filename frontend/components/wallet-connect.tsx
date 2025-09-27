"use client"

import { ConnectButton } from "@rainbow-me/rainbowkit"

export default function WalletConnectButton() {
  // Standard RainbowKit button - shows "Connect Wallet" when disconnected
  // and account info with disconnect option when connected
  return <ConnectButton />
}