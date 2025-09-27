import { Button } from "@/components/ui/button"
import { Card, CardContent } from "@/components/ui/card"
import Link from "next/link"
import Image from "next/image"

export default function Home() {
  return (
    <div>
      {/* Hero inspired by bold trading site headers */}
      <section className="bg-primary">
        <div className="mx-auto max-w-7xl px-4 py-16 md:py-24 grid gap-10 md:grid-cols-2 items-center">
          <div>
            <h1 className="text-balance text-4xl md:text-6xl font-semibold leading-tight text-primary-foreground">
              Trade Decisions on-chain.
            </h1>
            <p className="mt-4 text-primary-foreground/80 md:text-lg">
              Deposit USDC or ETH, buy credits, and express your view across proposal markets—each backed by Uniswap v4
              liquidity.
            </p>
            <div className="mt-6 flex flex-wrap gap-3">
              <Button asChild variant="secondary">
                <Link href="/proposals">Browse Proposals</Link>
              </Button>
              <Button asChild className="bg-accent text-accent-foreground hover:bg-accent/90">
                <Link href="/deposit">Deposit</Link>
              </Button>
            </div>
          </div>
          <Card className="shadow-lg">
            <CardContent className="p-4">
              <Image
                src="/trading-dashboard-mock-with-charts-and-orderbook.jpg"
                alt="Trading dashboard preview"
                width={960}
                height={540}
                className="h-auto w-full rounded-md object-cover"
                priority
              />
            </CardContent>
          </Card>
        </div>
      </section>

      {/* Feature tease */}
      <section className="mx-auto max-w-7xl px-4 py-12 grid md:grid-cols-3 gap-6">
        {[
          { title: "Proposal Markets", body: "Each proposal is a Uniswap v4 pool with continuous pricing." },
          { title: "Fast Trading", body: "Swap credits between outcomes with a responsive trading UI." },
          { title: "Credible Settlement", body: "Admin/oracle UI to collapse decisions and redeem winners." },
        ].map((f) => (
          <Card key={f.title}>
            <CardContent className="p-6">
              <h3 className="font-semibold">{f.title}</h3>
              <p className="mt-2 text-muted-foreground">{f.body}</p>
            </CardContent>
          </Card>
        ))}
      </section>
    </div>
  )
}
