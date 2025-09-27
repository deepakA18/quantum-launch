"use client"

import { useMemo, useState } from "react"
import { useSearchParams } from "next/navigation"
import { proposals } from "@/data/mock-proposals"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { ChartContainer, ChartTooltip, ChartTooltipContent } from "@/components/ui/chart"
import { Line, LineChart, ResponsiveContainer, XAxis, YAxis, CartesianGrid, Legend } from "recharts"

export default function TradePage() {
  const params = useSearchParams()
  const pool = params.get("pool")
  const proposal = useMemo(() => proposals.find((p) => p.poolId === pool) ?? proposals[0], [pool])

  const [amount, setAmount] = useState("")
  const data = proposal.curve

  return (
    <div className="mx-auto max-w-7xl px-4 py-8 grid gap-6 md:grid-cols-5">
      <div className="md:col-span-3">
        <Card>
          <CardHeader>
            <CardTitle>{proposal.title}</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <ChartContainer
              className="h-[360px]"
              config={{
                buy: { label: "Buy curve", color: "hsl(var(--chart-1))" },
                sell: { label: "Sell curve", color: "hsl(var(--chart-2))" },
              }}
            >
              <ResponsiveContainer width="100%" height="100%">
                <LineChart data={data} margin={{ left: 8, right: 8 }}>
                  <CartesianGrid strokeDasharray="3 3" />
                  <XAxis dataKey="x" />
                  <YAxis />
                  <Legend />
                  <ChartTooltip content={<ChartTooltipContent />} />
                  <Line type="monotone" dataKey="buy" stroke="var(--color-buy)" dot={false} />
                  <Line type="monotone" dataKey="sell" stroke="var(--color-sell)" dot={false} />
                </LineChart>
              </ResponsiveContainer>
            </ChartContainer>
          </CardContent>
        </Card>
      </div>

      <div className="md:col-span-2 space-y-6">
        <Card>
          <CardHeader>
            <CardTitle>Trade Credits</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <Tabs defaultValue="buy">
              <TabsList className="grid grid-cols-2">
                <TabsTrigger value="buy">Buy</TabsTrigger>
                <TabsTrigger value="sell">Sell</TabsTrigger>
              </TabsList>
              <TabsContent value="buy" className="space-y-4">
                <div className="space-y-2">
                  <Label htmlFor="buy-amt">Amount (cr)</Label>
                  <Input id="buy-amt" value={amount} onChange={(e) => setAmount(e.target.value)} placeholder="0.00" />
                </div>
                <Button className="w-full bg-accent text-accent-foreground hover:bg-accent/90">Submit Buy</Button>
              </TabsContent>
              <TabsContent value="sell" className="space-y-4">
                <div className="space-y-2">
                  <Label htmlFor="sell-amt">Amount (cr)</Label>
                  <Input id="sell-amt" value={amount} onChange={(e) => setAmount(e.target.value)} placeholder="0.00" />
                </div>
                <Button variant="secondary" className="w-full">
                  Submit Sell
                </Button>
              </TabsContent>
            </Tabs>

            <div className="rounded-md border p-3 text-sm text-muted-foreground">
              Est. price: <span className="font-medium text-foreground">{proposal.price.toFixed(4)} cr</span>
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Pool Snapshot</CardTitle>
          </CardHeader>
          <CardContent className="grid grid-cols-2 gap-3 text-sm">
            <div className="text-muted-foreground">Liquidity</div>
            <div>${proposal.liquidity.toLocaleString()}</div>
            <div className="text-muted-foreground">Fee Tier</div>
            <div>{proposal.fee}</div>
            <div className="text-muted-foreground">Pool</div>
            <div className="truncate">{proposal.poolId}</div>
          </CardContent>
        </Card>
      </div>
    </div>
  )
}
