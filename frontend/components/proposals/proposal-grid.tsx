"use client"

import { proposals } from "@/data/mock-proposals"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import Link from "next/link"
import { ChartContainer, ChartTooltip, ChartTooltipContent } from "@/components/ui/chart"
import { Area, AreaChart, CartesianGrid, ResponsiveContainer, XAxis, YAxis } from "recharts"

export default function ProposalGrid() {
  return (
    <div className="grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
      {proposals.map((p) => (
        <Link key={p.id} href={`/trade?pool=${p.poolId}`} className="group">
          <Card className="transition-all group-hover:shadow-md">
            <CardHeader className="flex-row items-center justify-between">
              <CardTitle className="text-base">{p.title}</CardTitle>
              <Badge variant="outline">{p.chain}</Badge>
            </CardHeader>
            <CardContent className="space-y-3">
              <div className="text-sm text-muted-foreground flex items-center justify-between">
                <span>Price</span>
                <span className="font-medium text-foreground">{p.price.toFixed(4)} cr</span>
              </div>

              <ChartContainer
                className="h-28"
                config={{
                  price: { label: "Price", color: "hsl(var(--chart-1))" },
                }}
              >
                <ResponsiveContainer width="100%" height="100%">
                  <AreaChart data={p.sparkline}>
                    <defs>
                      <linearGradient id={`g-${p.id}`} x1="0" x2="0" y1="0" y2="1">
                        <stop offset="5%" stopColor="var(--color-price)" stopOpacity={0.4} />
                        <stop offset="95%" stopColor="var(--color-price)" stopOpacity={0.05} />
                      </linearGradient>
                    </defs>
                    <CartesianGrid strokeDasharray="3 3" className="stroke-muted" />
                    <XAxis hide dataKey="t" />
                    <YAxis hide />
                    <ChartTooltip content={<ChartTooltipContent />} />
                    <Area dataKey="v" stroke="var(--color-price)" fill={`url(#g-${p.id})`} type="monotone" />
                  </AreaChart>
                </ResponsiveContainer>
              </ChartContainer>

              <div className="flex items-center justify-between text-sm">
                <span className="text-muted-foreground">Liquidity</span>
                <span>${p.liquidity.toLocaleString()}</span>
              </div>
            </CardContent>
          </Card>
        </Link>
      ))}
    </div>
  )
}
