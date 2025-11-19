Deploy the Mortgage Guardian frontend to Netlify:

**Decision Point - What to Deploy**:
1. **Marketing Website** (website/): Static HTML site for app promotion
2. **Web Dashboard** (frontend/): Next.js app (requires Clerk setup)

Ask user which to deploy or recommend marketing site if dashboard not ready.

**For Marketing Website Deployment**:
1. Navigate to website directory
2. Verify static files are ready:
   - index.html exists
   - assets/css/js are present
   - No broken links

3. Deploy to Netlify:
   ```bash
   cd website
   netlify deploy --prod --dir=. --site=9b1b9bf4-774f-4545-b901-b2289c4a6300
   ```

4. Verify deployment:
   - Check https://mortgage-guardian-app.netlify.app
   - Verify HTTP 200 response
   - Test all links and assets load

**For Next.js Dashboard Deployment**:
1. Navigate to frontend directory
2. Pre-deployment checks:
   - Dependencies installed
   - Build succeeds: `npm run build`
   - Environment variables documented

3. Configure Netlify environment variables:
   - NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY
   - CLERK_SECRET_KEY
   - NEXT_PUBLIC_API_URL (backend URL)

4. Deploy:
   ```bash
   cd frontend
   netlify deploy --prod --dir=.next
   ```

5. Verify deployment and functionality

**Custom Domain Setup** (Optional):
1. In GoDaddy DNS, add CNAME:
   - Name: app
   - Value: mortgage-guardian-app.netlify.app
   - TTL: 600

2. In Netlify dashboard:
   - Add custom domain: app.mortgageguardian.org
   - Configure DNS
   - Enable HTTPS (automatic)

**Post-deployment**:
1. Test deployment URL
2. Verify all features work
3. Check browser console for errors
4. Test on mobile devices
5. Verify SSL certificate

**Output**:
- Deployment status
- URL (Netlify and custom domain)
- Build logs if errors
- Next steps or issues
