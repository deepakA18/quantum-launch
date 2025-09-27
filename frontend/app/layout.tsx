import type React from "react"
import type { Metadata } from "next"
import { GeistMono } from "geist/font/mono"
import { Analytics } from "@vercel/analytics/next"
import { Space_Grotesk } from "next/font/google"
import "./globals.css"
import "@rainbow-me/rainbowkit/styles.css"
import { ThemeProvider } from "@/components/theme-provider"
import TopNav from "@/components/top-nav"
import { Suspense } from "react"
import Providers from "@/app/providers"

const spaceGrotesk = Space_Grotesk({ subsets: ["latin"], weight: "500", variable: "--font-space-grotesk" })

export const metadata: Metadata = {
  title: "Quantum Launch",
  description: "Created with Quantum Launch",
  generator: "Quantum Launch",
}

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode
}>) {
  return (
    <html lang="en" suppressHydrationWarning>
      <body className={`font-sans space-grotesk-quantum ${spaceGrotesk.variable} ${GeistMono.variable}`}>
        <ThemeProvider attribute="class" defaultTheme="light" enableSystem={false}>
          <Providers>
            <Suspense fallback={<div>Loading...</div>}>
              <div className="min-h-dvh flex flex-col">
                <TopNav />
                <main className="flex-1">{children}</main>
              </div>
            </Suspense>
            <Analytics />
          </Providers>
        </ThemeProvider>
      </body>
    </html>
  )
}
