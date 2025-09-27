import ProposalGrid from "@/components/proposals/proposal-grid"

export default function ProposalsPage() {
  return (
    <div className="mx-auto max-w-7xl px-4 py-8">
      <div className="mb-6">
        <h1 className="text-3xl font-semibold text-balance">Proposal Markets</h1>
        <p className="text-muted-foreground">
          Explore active proposals. Prices are represented by current pool state snapshots.
        </p>
      </div>
      <ProposalGrid />
    </div>
  )
}
