"use client"

import { useAccount, useConnect, useDisconnect } from "wagmi"
import { injected } from "wagmi/connectors"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { useEffect, useState } from "react"

export default function WalletConnectButton() {
  // Avoid hydration mismatches by rendering a stable placeholder on the server
  const [mounted, setMounted] = useState(false)
  useEffect(() => setMounted(true), [])

  const { address, isConnected } = useAccount()
  const { connect, isPending } = useConnect()
  const { disconnect } = useDisconnect()
  const [copy, setCopy] = useState<"copy" | "copied">("copy")

  // SSR/First client render placeholder (stable markup)
  if (!mounted) {
    return (
      <Button disabled className="pointer-events-none opacity-60">
        Connect Wallet
      </Button>
    )
  }

  if (isConnected && address) {
    const short = `${address.slice(0, 6)}…${address.slice(-4)}`
    return (
      <div className="flex items-center gap-2">
        <Badge variant="outline" className="font-mono">
          {short}
        </Badge>
        <Button
          variant="secondary"
          onClick={() => {
            navigator.clipboard.writeText(address)
            setCopy("copied")
            setTimeout(() => setCopy("copy"), 1200)
          }}
        >
          {copy === "copy" ? "Copy" : "Copied"}
        </Button>
        <Button variant="ghost" onClick={() => disconnect()}>
          Disconnect
        </Button>
      </div>
    )
  }

  return (
    <Button
      onClick={() => connect({ connector: injected() })}
      disabled={isPending}
      className="bg-primary text-primary-foreground hover:bg-primary/90"
    >
      {isPending ? "Connecting…" : "Connect Wallet"}
    </Button>
  )
}
