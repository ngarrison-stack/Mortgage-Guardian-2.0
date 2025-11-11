# Mortgage Guardian Frontend

**Status**: Deployed but non-functional (500 error)
**URL**: https://mortgage-guardian-app.netlify.app
**Platform**: Netlify
**Framework**: Next.js 15 + React 19

---

## Current Situation

This directory contains a **Next.js starter template** that has been deployed to Netlify but is returning a 500 error due to missing Clerk authentication keys. The template has not been customized with any Mortgage Guardian-specific UI or functionality.

**The actual Mortgage Guardian application is an iOS Swift app** located in `/MortgageGuardian/`.

---

## Quick Start

### Option 1: Deploy Marketing Site (RECOMMENDED)
Replace the broken Next.js app with the professional marketing website:

```bash
cd ../website
npx netlify-cli deploy --prod --dir=. --site=9b1b9bf4-774f-4545-b901-b2289c4a6300
```

### Option 2: Fix the 500 Error
Add Clerk API keys to Netlify:

1. Get keys from: https://dashboard.clerk.com
2. Add to Netlify: https://app.netlify.com/sites/mortgage-guardian-app/settings/env
   - `NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY`
   - `CLERK_SECRET_KEY`
3. Redeploy

---

## Documentation

### For Immediate Action
- **QUICK-FIX-GUIDE.md** - 3 ways to fix the 500 error (2-10 minutes)
- **DEPLOYMENT-STATUS.md** - Current status and recommendations

### For Planning
- **FRONTEND-ASSESSMENT.md** - Complete analysis and development roadmap (70+ pages)

### For Development
- **.env.example** - Development environment configuration
- **.env.production.example** - Production environment configuration

---

## Technology Stack

**Currently Installed**
- Next.js 15.5.4
- React 19.1.0
- Tailwind CSS 4
- TypeScript 5.9
- Clerk 6.34.5 (auth)

**Not Yet Installed** (needed for actual app)
- Component library (shadcn/ui recommended)
- Form handling (React Hook Form + Zod)
- Data fetching (TanStack Query)
- File upload (react-dropzone)
- Charts (Recharts)
- PDF handling (react-pdf)

---

## Project Architecture

```
Mortgage Guardian Ecosystem
├── iOS App (Swift/SwiftUI)     [PRODUCTION] ✅
│   └── Full mortgage audit features
├── Marketing Site (HTML/CSS)   [READY] ✅
│   └── Landing page & app promotion
├── Backend API (Node.js)       [DEPLOYED] ✅
│   └── Claude AI, Plaid, Documents
└── Web Dashboard (Next.js)     [NOT BUILT] ❌
    └── This directory - requires development
```

---

## Development Timeline

**If building web dashboard:**

- **MVP**: 8 weeks (core features only)
- **Full Build**: 16 weeks (feature parity with iOS)
- **Production Ready**: 20 weeks (including testing)

**Estimated Cost**: $30,000 - $100,000 depending on approach

---

## Immediate Recommendations

1. **Today**: Deploy marketing site to fix 500 error
2. **This Week**: Decide if web dashboard is actually needed
3. **Next Month**: If yes, hire developer and start planning
4. **3-6 Months**: Launch web dashboard (if proceeding)

---

## Backend API Configuration

### Environment Variables Needed

Create `.env.local`:
```bash
# Clerk Authentication
NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY=pk_test_xxxxx
CLERK_SECRET_KEY=sk_test_xxxxx

# Backend API
NEXT_PUBLIC_API_URL=https://api.mortgageguardian.org

# Feature Flags
NEXT_PUBLIC_ENABLE_PLAID=true
NEXT_PUBLIC_ENABLE_AI_ANALYSIS=true
```

### Backend Endpoints Available

- `POST /v1/ai/claude/analyze` - Claude AI analysis
- `POST /v1/plaid/link_token` - Create Plaid Link
- `POST /v1/documents/upload` - Upload documents
- `GET /v1/documents` - List documents
- `GET /health` - Health check

---

## Development Commands

```bash
# Install dependencies
npm install

# Run development server
npm run dev

# Build for production
npm run build

# Start production server
npm start

# Lint code
npm run lint

# Type check
npx tsc --noEmit
```

---

## File Structure

```
frontend/
├── src/
│   ├── app/
│   │   ├── page.tsx          # Home page (starter template)
│   │   ├── layout.tsx        # Root layout with Clerk
│   │   └── globals.css       # Global styles
│   └── middleware.ts         # Clerk auth middleware
├── public/                   # Static assets
├── .env.example              # Environment variables template
├── package.json              # Dependencies
├── next.config.ts            # Next.js configuration
├── tailwind.config.ts        # Tailwind configuration
└── tsconfig.json            # TypeScript configuration
```

---

## Support

### Documentation
- [FRONTEND-ASSESSMENT.md](./FRONTEND-ASSESSMENT.md) - Complete project analysis
- [QUICK-FIX-GUIDE.md](./QUICK-FIX-GUIDE.md) - Immediate fixes
- [DEPLOYMENT-STATUS.md](./DEPLOYMENT-STATUS.md) - Current status

### External Resources
- **Netlify Dashboard**: https://app.netlify.com/sites/mortgage-guardian-app
- **Clerk Dashboard**: https://dashboard.clerk.com
- **Next.js Docs**: https://nextjs.org/docs
- **React Docs**: https://react.dev

---

## Questions?

See [FRONTEND-ASSESSMENT.md](./FRONTEND-ASSESSMENT.md) for:
- Complete technical analysis
- Development roadmap
- Cost estimates
- Technology decisions
- Timeline projections

---

**Last Updated**: November 10, 2025
**Status**: Awaiting decision on web dashboard priority
