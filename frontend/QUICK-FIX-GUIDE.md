# Frontend Quick Fix Guide

**Problem**: https://mortgage-guardian-app.netlify.app returns 500 error
**Cause**: Missing Clerk API keys
**Time to Fix**: 5-10 minutes

---

## Quick Fix Option 1: Add Clerk Keys (Keep Next.js App)

### Step 1: Get Clerk API Keys
1. Go to https://dashboard.clerk.com/sign-up
2. Create account (or sign in if you have one)
3. Create a new application:
   - Name: "Mortgage Guardian"
   - Sign-in options: Email, Google (recommended)
4. Copy your keys from dashboard:
   - **Publishable key**: `pk_test_...`
   - **Secret key**: `sk_test_...`

### Step 2: Set Environment Variables in Netlify
1. Go to: https://app.netlify.com/sites/mortgage-guardian-app/settings/env
2. Click "Add a variable"
3. Add these two variables:
   ```
   Key: NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY
   Value: pk_test_[your-publishable-key]

   Key: CLERK_SECRET_KEY
   Value: sk_test_[your-secret-key]
   ```
4. Save changes

### Step 3: Redeploy
1. Go to: https://app.netlify.com/sites/mortgage-guardian-app/deploys
2. Click "Trigger deploy" → "Clear cache and deploy site"
3. Wait 1-2 minutes for deployment
4. Test: https://mortgage-guardian-app.netlify.app (should show Next.js template)

**Result**: Site will work but show generic Next.js starter template (not useful)

---

## Quick Fix Option 2: Deploy Marketing Site (Recommended)

### Step 1: Deploy Static Marketing Website

```bash
cd /Users/nickgarrison/Documents/GitHub/Mortgage-Guardian-2.0-Clean/Mortgage-Guardian-2.0/website

# Deploy to Netlify
npx netlify-cli deploy --prod --dir=. --site=9b1b9bf4-774f-4545-b901-b2289c4a6300
```

### Step 2: Verify Deployment
- Visit: https://mortgage-guardian-app.netlify.app
- Should see: Professional marketing site with app features

**Result**: Functional marketing website instead of broken app

---

## Quick Fix Option 3: Simple "Coming Soon" Page

### Create minimal page in frontend

```bash
cd /Users/nickgarrison/Documents/GitHub/Mortgage-Guardian-2.0-Clean/Mortgage-Guardian-2.0/frontend/src/app
```

**Edit `page.tsx`:**
```typescript
export default function Home() {
  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-50 flex items-center justify-center p-8">
      <div className="max-w-2xl text-center">
        <h1 className="text-5xl font-bold text-gray-900 mb-4">
          Mortgage Guardian
        </h1>
        <p className="text-xl text-gray-600 mb-8">
          AI-Powered Mortgage Audit Protection
        </p>
        <p className="text-lg text-gray-500 mb-8">
          Web dashboard coming soon. Download our iOS app to get started today.
        </p>
        <a
          href="https://apps.apple.com/app/mortgage-guardian"
          className="inline-block bg-indigo-600 text-white px-8 py-3 rounded-lg font-semibold hover:bg-indigo-700 transition"
        >
          Download for iOS
        </a>
      </div>
    </div>
  );
}
```

**Remove Clerk from `layout.tsx`:**
```typescript
import { Geist, Geist_Mono } from 'next/font/google'
import './globals.css'

const geistSans = Geist({
  variable: '--font-geist-sans',
  subsets: ['latin'],
})

const geistMono = Geist_Mono({
  variable: '--font-geist-mono',
  subsets: ['latin'],
})

export const metadata = {
  title: 'Mortgage Guardian - Coming Soon',
  description: 'AI-Powered Mortgage Audit Protection',
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="en">
      <body className={`${geistSans.variable} ${geistMono.variable} antialiased`}>
        {children}
      </body>
    </html>
  )
}
```

**Remove Clerk middleware:**
```bash
rm /Users/nickgarrison/Documents/GitHub/Mortgage-Guardian-2.0-Clean/Mortgage-Guardian-2.0/frontend/src/middleware.ts
```

**Commit and push:**
```bash
cd /Users/nickgarrison/Documents/GitHub/Mortgage-Guardian-2.0-Clean/Mortgage-Guardian-2.0/frontend
git add .
git commit -m "Add coming soon page, remove Clerk dependency"
git push origin main
```

Netlify will auto-deploy.

**Result**: Simple, functional coming soon page

---

## Comparison

| Option | Time | Result | Best For |
|--------|------|--------|----------|
| **Option 1: Add Clerk Keys** | 5 min | Generic Next.js template (not useful) | Testing only |
| **Option 2: Deploy Marketing Site** | 2 min | Professional marketing site | Production use |
| **Option 3: Coming Soon Page** | 10 min | Simple holding page | Temporary solution |

---

## Recommendation

**For Production**: Use **Option 2** (Deploy Marketing Site)
- Most professional
- Actually useful for visitors
- No broken features
- Already built and designed

**Command to run:**
```bash
cd /Users/nickgarrison/Documents/GitHub/Mortgage-Guardian-2.0-Clean/Mortgage-Guardian-2.0/website
npx netlify-cli deploy --prod --dir=. --site=9b1b9bf4-774f-4545-b901-b2289c4a6300
```

---

## After Fix: Next Steps

Once you've chosen a fix above, decide on web dashboard priority:

### If Web Dashboard is Low Priority
- Keep marketing site deployed
- Focus on iOS app development
- Revisit web dashboard in 3-6 months

### If Web Dashboard is High Priority
1. Review `/frontend/FRONTEND-ASSESSMENT.md`
2. Allocate 12-16 weeks development time
3. Follow development roadmap
4. Hire developer or dedicate internal resources

---

## Need Help?

- **Netlify Dashboard**: https://app.netlify.com/sites/mortgage-guardian-app
- **Clerk Dashboard**: https://dashboard.clerk.com
- **Frontend Assessment**: `/frontend/FRONTEND-ASSESSMENT.md`
- **Backend API**: Already deployed to Railway (working)

---

**Last Updated**: November 10, 2025
