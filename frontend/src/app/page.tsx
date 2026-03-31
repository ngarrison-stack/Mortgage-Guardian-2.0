import { redirect } from 'next/navigation'
import { SignedIn, SignedOut, SignInButton } from '@clerk/nextjs'
import { auth } from '@clerk/nextjs/server'

function ShieldLogo({ className = '' }: { className?: string }) {
  return (
    <svg className={className} width="64" height="64" viewBox="0 0 40 40" fill="none" xmlns="http://www.w3.org/2000/svg">
      <path d="M20 2L4 10v12c0 9.6 6.8 18.6 16 20.8 9.2-2.2 16-11.2 16-20.8V10L20 2z" fill="#2997FF" fillOpacity="0.15" stroke="#2997FF" strokeWidth="2"/>
      <path d="M16 20l4 4 8-8" stroke="#30D158" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round"/>
    </svg>
  )
}

export default async function Home() {
  const { userId } = await auth()

  if (userId) {
    redirect('/dashboard')
  }

  return (
    <div className="min-h-screen bg-gray-950 flex flex-col items-center justify-center px-6 py-16">
      <SignedOut>
        <div className="flex flex-col items-center text-center max-w-2xl">
          <ShieldLogo className="mb-8" />
          <h1 className="text-4xl sm:text-5xl font-bold text-white mb-4">
            Mortgage Guardian
          </h1>
          <p className="text-lg text-gray-400 mb-8 max-w-lg">
            AI-powered forensic audit that detects mortgage servicer violations,
            cross-verifies bank transactions, and generates RESPA-compliant dispute letters.
          </p>
          <div className="flex gap-4">
            <SignInButton>
              <button className="bg-[#2997FF] text-white rounded-full font-medium text-base h-12 px-6 flex items-center hover:bg-[#2080E0] transition-colors cursor-pointer">
                Sign In to Get Started
              </button>
            </SignInButton>
          </div>
        </div>
      </SignedOut>

      <SignedIn>
        <div className="text-gray-400">Redirecting to dashboard...</div>
      </SignedIn>
    </div>
  )
}
