import { SignedIn, SignedOut } from '@clerk/nextjs'

function ShieldLogo({ className = '' }: { className?: string }) {
  return (
    <svg className={className} width="64" height="64" viewBox="0 0 40 40" fill="none" xmlns="http://www.w3.org/2000/svg">
      <path d="M20 2L4 10v12c0 9.6 6.8 18.6 16 20.8 9.2-2.2 16-11.2 16-20.8V10L20 2z" fill="#2997FF" fillOpacity="0.15" stroke="#2997FF" strokeWidth="2"/>
      <path d="M16 20l4 4 8-8" stroke="#30D158" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round"/>
    </svg>
  )
}

function StatusCard({ label, status, color }: { label: string; status: string; color: string }) {
  return (
    <div className="flex items-center justify-between p-4 rounded-lg bg-gray-900 border border-gray-800">
      <span className="text-gray-300">{label}</span>
      <span className={`flex items-center gap-2 text-sm font-medium ${color}`}>
        <span className="w-2 h-2 rounded-full bg-current" />
        {status}
      </span>
    </div>
  )
}

export default function Home() {
  return (
    <div className="min-h-[calc(100vh-4rem)] bg-gray-950 flex flex-col items-center justify-center px-6 py-16">
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
            <a
              href="/sign-in"
              className="bg-[#2997FF] text-white rounded-full font-medium text-base h-12 px-6 flex items-center hover:bg-[#2080E0] transition-colors"
            >
              Sign In to Get Started
            </a>
          </div>
        </div>
      </SignedOut>

      <SignedIn>
        <div className="flex flex-col items-center text-center max-w-2xl w-full">
          <ShieldLogo className="mb-6" />
          <h1 className="text-3xl sm:text-4xl font-bold text-white mb-2">
            Welcome to Mortgage Guardian
          </h1>
          <p className="text-gray-400 mb-10 max-w-lg">
            Your AI-powered mortgage audit platform. Upload documents to detect servicing errors
            and generate compliance reports.
          </p>

          <div className="w-full max-w-md flex flex-col gap-3">
            <h2 className="text-sm font-semibold text-gray-500 uppercase tracking-wider mb-1">
              System Status
            </h2>
            <StatusCard label="Document Analysis" status="Ready" color="text-[#30D158]" />
            <StatusCard label="Bank Verification" status="Ready" color="text-[#30D158]" />
            <StatusCard label="Compliance Engine" status="Ready" color="text-[#30D158]" />
          </div>
        </div>
      </SignedIn>
    </div>
  )
}
