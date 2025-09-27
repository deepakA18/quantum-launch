"use client"

import { useState } from "react"
import { proposals } from "@/data/mock-proposals"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Label } from "@/components/ui/label"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { Textarea } from "@/components/ui/textarea"

export default function SettlementPage() {
  const [winner, setWinner] = useState("A")
  const [decision, setDecision] = useState(proposals[0]?.id ?? "0")

  return (
    <div className="mx-auto max-w-4xl px-4 py-8">
      <Card>
        <CardHeader>
          <CardTitle>Settlement & Oracle</CardTitle>
        </CardHeader>
        <CardContent className="space-y-6">
          <div className="grid md:grid-cols-2 gap-4">
            <div className="space-y-2">
              <Label>Decision</Label>
              <Select value={decision} onValueChange={(v) => setDecision(v)}>
                <SelectTrigger>
                  <SelectValue placeholder="Select decision" />
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
              <Label>Winning Outcome</Label>
              <Select value={winner} onValueChange={(v) => setWinner(v)}>
                <SelectTrigger>
                  <SelectValue placeholder="Choose winner" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="A">Outcome A</SelectItem>
                  <SelectItem value="B">Outcome B</SelectItem>
                  <SelectItem value="C">Outcome C</SelectItem>
                </SelectContent>
              </Select>
            </div>
          </div>

          <div className="space-y-2">
            <Label htmlFor="note">Rationale (optional)</Label>
            <Textarea id="note" placeholder="Provide settlement notes for transparency." />
          </div>

          <div className="flex flex-wrap gap-3">
            <Button className="bg-accent text-accent-foreground hover:bg-accent/90">Settle Decision</Button>
            <Button variant="secondary">Revert Others</Button>
          </div>
        </CardContent>
      </Card>
    </div>
  )
}
