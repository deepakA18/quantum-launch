"use client"

import Link from "next/link"
import { usePathname } from "next/navigation"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { Sheet, SheetContent, SheetTrigger } from "@/components/ui/sheet"
import { Menu, Sparkles, ArrowUpRight } from "lucide-react"
import { cn } from "@/lib/utils"
import WalletConnectButton from "@/components/wallet-connect"

export default function TopNav() {
  const pathname = usePathname()

  const links = [
    { href: "/proposals", label: "Proposals" },
    { href: "/trade", label: "Trade" },
    { href: "/deposit", label: "Deposit" },
    { href: "/settlement", label: "Settlement" },
  ]

  const isActive = (href: string) => {
    if (href === "/") return pathname === "/"
    return pathname?.startsWith(href)
  }

  return (
    <header className="sticky top-0 z-50 flex justify-center bg-primary px-3 pb-3 pt-4 transition-colors">
      <div className="relative w-full max-w-7xl">
        <div
          className="pointer-events-none absolute inset-x-4 -top-4 bottom-0 -z-10 rounded-3xl bg-gradient-to-r from-primary/80 via-primary/40 to-primary/80 opacity-90 blur-3xl"
          aria-hidden="true"
        />
        <div className="relative flex items-center justify-between gap-3 rounded-2xl border border-white/10 bg-background/75 px-4 py-3 shadow-[0_15px_40px_rgba(15,23,42,0.25)] backdrop-blur-xl supports-[backdrop-filter]:bg-background/60">
          {/* Brand */}
          <Link
            href="/"
            className="group flex items-center gap-3 rounded-full px-3 py-1.5 transition hover:bg-primary/5"
            aria-label="Home"
          >
            <span className="relative flex h-10 w-10 items-center justify-center rounded-full bg-primary text-background shadow-[0_8px_25px_rgba(59,130,246,0.45)] ring-2 ring-primary/60 ring-offset-2 ring-offset-background">
              <Sparkles className="h-5 w-5" />
            </span>
            <span className="flex flex-col -space-y-0.5 leading-none">
              <span className="space-grotesk-quantum text-base font-semibold tracking-tight">PropTrade</span>
              
            </span>
          </Link>

          {/* Desktop Nav */}
          <nav className="hidden items-center gap-2 md:flex">
            {links.map((l) => (
              <Link
                key={l.href}
                href={l.href}
                aria-current={isActive(l.href) ? "page" : undefined}
                className={cn(
                  "group relative overflow-hidden rounded-full px-3.5 py-2 text-sm font-medium text-foreground/70 transition duration-300",
                  "before:absolute before:inset-0 before:rounded-full before:bg-gradient-to-r before:from-primary/25 before:via-primary/10 before:to-primary/25 before:opacity-0 before:transition before:duration-300 before:content-['']",
                  "hover:text-foreground hover:before:opacity-100",
                  isActive(l.href) &&
                    "text-foreground shadow-[0_12px_30px_rgba(59,130,246,0.28)] before:opacity-100"
                )}
              >
                <span className="relative z-10 flex items-center gap-1">
                  {l.label}
                  {isActive(l.href) && <span className="h-1.5 w-1.5 rounded-full bg-primary shadow-[0_0_12px_rgba(59,130,246,0.8)]" aria-hidden="true" />}
                </span>
              </Link>
            ))}
          </nav>

          {/* Actions */}
          <div className="flex items-center gap-2">
            <Button
              asChild
              className="hidden items-center gap-2 rounded-full bg-gradient-to-r from-gray-900 via-gray-800 to-gray-900 px-4 py-2 text-sm font-semibold text-white shadow-[0_12px_30px_rgba(0,0,0,0.35)] transition hover:from-gray-800 hover:via-gray-700 hover:to-gray-800 md:inline-flex"
            >
              <Link href="/proposals">
              Launch app
              <ArrowUpRight className="h-4 w-4" />
              </Link>
            </Button>
            <WalletConnectButton />

            {/* Mobile Menu */}
            <Sheet>
              <SheetTrigger asChild>
                <Button size="icon" variant="ghost" className="md:hidden" aria-label="Open menu">
                  <Menu className="h-5 w-5" />
                </Button>
              </SheetTrigger>
              <SheetContent side="left" className="w-72 border-white/10 bg-background/90 backdrop-blur">
                <div className="mt-8 flex flex-col gap-4">
                  {links.map((l) => (
                    <Link
                      key={l.href}
                      href={l.href}
                      className={cn(
                        "rounded-xl border border-transparent bg-gradient-to-r from-primary/5 via-background to-primary/5 px-4 py-3 text-base font-medium text-foreground/80 transition",
                        "hover:border-primary/30 hover:text-foreground",
                        isActive(l.href) && "border-primary/50 text-foreground shadow-[0_8px_20px_rgba(59,130,246,0.25)]"
                      )}
                    >
                      {l.label}
                    </Link>
                  ))}
                  <Button
                    asChild
                    className="mt-2 flex items-center justify-center gap-2 rounded-full bg-gradient-to-r from-primary via-primary/80 to-primary/60 px-4 py-2 font-semibold text-background shadow-[0_12px_30px_rgba(59,130,246,0.35)]"
                  >
                    <Link href="/proposals">
                      Launch app
                      <ArrowUpRight className="h-4 w-4" />
                    </Link>
                  </Button>
                </div>
              </SheetContent>
            </Sheet>
          </div>
        </div>
      </div>
    </header>
  )
}
