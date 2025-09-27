"use client"

import { useState } from "react"
import { useAccount } from "wagmi"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { proposals } from "@/data/mock-proposals"

export default function DepositPage() {
  const { isConnected } = useAccount()
  const [asset, setAsset] = useState<"ETH" | "USDC">("ETH")
  const [amount, setAmount] = useState("")
  const [decision, setDecision] = useState(proposals[0]?.id ?? "0")

  return (
    <div className="mx-auto max-w-4xl px-4 py-8">
      <Card>
        <CardHeader>
          <CardTitle>Deposit into a Decision</CardTitle>
        </CardHeader>
        <CardContent className="space-y-6">
          <Tabs defaultValue="deposit">
            <TabsList>
              <TabsTrigger value="deposit">Deposit</TabsTrigger>
              <TabsTrigger value="withdraw">Withdraw</TabsTrigger>
            </TabsList>

            <TabsContent value="deposit" className="space-y-6">
              <div className="grid md:grid-cols-2 gap-4">
                <div className="space-y-2">
                  <Label htmlFor="decision">Decision</Label>
                  <Select value={decision} onValueChange={(v) => setDecision(v)}>
                    <SelectTrigger id="decision">
                      <SelectValue placeholder="Select a decision" />
                    </SelectTrigger>
                    <SelectContent>
                      {proposals.map((p) => (
                        <SelectItem key={p.id} value={p.id}>
                          {p.title}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>

                <div className="space-y-2">
                  <Label>Asset</Label>
                  <div className="grid grid-cols-2 gap-2">
                    <Button
                      type="button"
                      variant={asset === "ETH" ? "default" : "secondary"}
                      onClick={() => setAsset("ETH")}
                    >
                      ETH
                    </Button>
                    <Button
                      type="button"
                      variant={asset === "USDC" ? "default" : "secondary"}
                      onClick={() => setAsset("USDC")}
                    >
                      USDC
                    </Button>
                  </div>
                </div>
              </div>

              <div className="space-y-2">
                <Label htmlFor="amount">Amount</Label>
                <Input
                  id="amount"
                  inputMode="decimal"
                  placeholder="0.00"
                  value={amount}
                  onChange={(e) => setAmount(e.target.value)}
                />
                <p className="text-xs text-muted-foreground">{"1 + 1 < 3"}</p>
              </div>

              <Button
                className="w-full bg-primary text-primary-foreground hover:bg-primary/90"
                disabled={!isConnected || !amount}
              >
                {isConnected ? `Deposit ${asset}` : "Connect Wallet to Deposit"}
              </Button>
            </TabsContent>

            <TabsContent value="withdraw">
              <div className="rounded-md border p-4 text-sm text-muted-foreground">
                Withdrawals UI coming soon. For now this is a design placeholder.
              </div>
            </TabsContent>
          </Tabs>
        </CardContent>
      </Card>
    </div>
  )
}
