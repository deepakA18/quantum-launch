export type Proposal = {
  id: string
  title: string
  chain: string
  poolId: string
  fee: string
  price: number
  liquidity: number
  sparkline: { t: number; v: number }[]
  curve: { x: number; buy: number; sell: number }[]
}

function genSpark(): { t: number; v: number }[] {
  const data = []
  let v = 0.52 + Math.random() * 0.1
  for (let i = 0; i < 30; i++) {
    v += (Math.random() - 0.5) * 0.03
    data.push({ t: i, v: Math.max(0.05, Number(v.toFixed(3))) })
  }
  return data
}

function genCurve(): { x: number; buy: number; sell: number }[] {
  const data = []
  for (let i = 0; i <= 100; i += 5) {
    const x = i
    const buy = Math.max(0.01, Number((0.3 + 0.005 * i + 0.03 * Math.sin(i / 10)).toFixed(3)))
    const sell = Math.max(0.01, Number((0.28 + 0.0045 * i + 0.025 * Math.cos(i / 12)).toFixed(3)))
    data.push({ x, buy, sell })
  }
  return data
}

export const proposals: Proposal[] = [
  {
    id: "1",
    title: "Will Proposal A pass by Q4?",
    chain: "Base",
    poolId: "0xabc...001",
    fee: "500",
    price: 0.5342,
    liquidity: 524_000,
    sparkline: genSpark(),
    curve: genCurve(),
  },
  {
    id: "2",
    title: "Launch new product before Nov?",
    chain: "Arbitrum",
    poolId: "0xabc...002",
    fee: "300",
    price: 0.4821,
    liquidity: 371_250,
    sparkline: genSpark(),
    curve: genCurve(),
  },
  {
    id: "3",
    title: "Partnership finalized this month?",
    chain: "Ethereum",
    poolId: "0xabc...003",
    fee: "100",
    price: 0.6012,
    liquidity: 812_950,
    sparkline: genSpark(),
    curve: genCurve(),
  },
]
