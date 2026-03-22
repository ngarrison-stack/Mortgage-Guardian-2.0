# Production Configuration for mortgageguardian.org

## 🌐 Domain Structure

### Recommended Subdomain Setup
```
mortgageguardian.org          → Marketing/Landing page
app.mortgageguardian.org      → Web application (React/Next.js)
api.mortgageguardian.org      → Backend API (Node.js/Express)
docs.mortgageguardian.org     → Documentation
status.mortgageguardian.org   → System status page
```

## 📍 DNS Configuration

### Required DNS Records

```dns
# Root domain
@           A       Your-Server-IP
@           AAAA    Your-IPv6-Address (if available)

# Subdomains
app         CNAME   mortgageguardian.org
api         CNAME   mortgageguardian.org
docs        CNAME   mortgageguardian.org
status      CNAME   mortgageguardian.org

# Email (if using)
@           MX      10 mail.mortgageguardian.org
@           TXT     "v=spf1 include:_spf.google.com ~all"

# SSL Verification
@           CAA     0 issue "letsencrypt.org"
```

## 🔒 SSL Certificate Options

### Option 1: Let's Encrypt (Free)
```bash
# Install Certbot
sudo apt-get update
sudo apt-get install certbot python3-certbot-nginx

# Generate certificates
sudo certbot certonly --standalone -d mortgageguardian.org -d *.mortgageguardian.org

# Auto-renewal
sudo certbot renew --dry-run
```

### Option 2: Cloudflare (Free with CDN)
1. Add site to Cloudflare
2. Update nameservers at domain registrar
3. Enable "Full (strict)" SSL mode
4. Use Cloudflare origin certificates

## 🚀 Deployment Options

### Option 1: Vercel (Recommended for Frontend)
- Connect GitHub repository
- Set custom domain: app.mortgageguardian.org
- Environment variables automatically applied
- Automatic SSL

### Option 2: Railway/Render (Backend)
- Deploy backend to Railway/Render
- Custom domain: api.mortgageguardian.org
- Automatic SSL included

### Option 3: VPS (Full Control)
- Deploy with Docker Compose
- Use Nginx reverse proxy
- Let's Encrypt SSL
- Full control over infrastructure

### Option 4: Cloudflare Pages + Workers
- Frontend on Pages
- API on Workers
- Global CDN included
- Automatic SSL

## 🔧 Environment Variables

### Backend (.env.production)
```env
NODE_ENV=production
PORT=3000

# Domain Configuration
API_URL=https://api.mortgageguardian.org
FRONTEND_URL=https://app.mortgageguardian.org
ALLOWED_ORIGINS=https://app.mortgageguardian.org,https://mortgageguardian.org

# Security
JWT_SECRET=production-secret-$(openssl rand -hex 32)
ENCRYPTION_KEY=production-key-$(openssl rand -hex 32)
COOKIE_DOMAIN=.mortgageguardian.org
SECURE_COOKIES=true

# API Keys (add your actual keys)
ANTHROPIC_API_KEY=sk-ant-production-key
PLAID_CLIENT_ID=production-client-id
PLAID_SECRET=production-secret
PLAID_ENV=production

# Database (production)
DATABASE_URL=postgresql://user:pass@host:5432/mortgageguardian_prod
REDIS_URL=redis://user:pass@host:6379
```

### Frontend (.env.production)
```env
NEXT_PUBLIC_API_URL=https://api.mortgageguardian.org
NEXT_PUBLIC_APP_URL=https://app.mortgageguardian.org
NEXT_PUBLIC_DOMAIN=mortgageguardian.org

# Clerk Production Keys
NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY=pk_live_xxx
CLERK_SECRET_KEY=sk_live_xxx
NEXT_PUBLIC_CLERK_SIGN_IN_URL=https://app.mortgageguardian.org/sign-in
NEXT_PUBLIC_CLERK_SIGN_UP_URL=https://app.mortgageguardian.org/sign-up
NEXT_PUBLIC_CLERK_AFTER_SIGN_IN_URL=https://app.mortgageguardian.org/dashboard
NEXT_PUBLIC_CLERK_AFTER_SIGN_UP_URL=https://app.mortgageguardian.org/onboarding

# Analytics (optional)
NEXT_PUBLIC_GA_ID=G-XXXXXXXXXX
NEXT_PUBLIC_HOTJAR_ID=XXXXXXX
```

## 📱 iOS App Configuration

### Update Info.plist
```xml
<!-- App Transport Security for API -->
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSExceptionDomains</key>
    <dict>
        <key>mortgageguardian.org</key>
        <dict>
            <key>NSIncludesSubdomains</key>
            <true/>
            <key>NSExceptionAllowsInsecureHTTPLoads</key>
            <false/>
            <key>NSExceptionRequiresForwardSecrecy</key>
            <true/>
        </dict>
    </dict>
</dict>

<!-- Associated Domains for Universal Links -->
<key>com.apple.developer.associated-domains</key>
<array>
    <string>applinks:mortgageguardian.org</string>
    <string>applinks:app.mortgageguardian.org</string>
    <string>webcredentials:mortgageguardian.org</string>
</array>
```

### Update API Configuration
```swift
// MortgageGuardian/Config/APIConfig.swift
struct APIConfig {
    static let baseURL = {
        #if DEBUG
        return "http://localhost:3000"
        #else
        return "https://api.mortgageguardian.org"
        #endif
    }()
}
```

## 🛡️ Security Headers

### Nginx Configuration
```nginx
server {
    listen 443 ssl http2;
    server_name mortgageguardian.org *.mortgageguardian.org;

    # SSL Configuration
    ssl_certificate /etc/letsencrypt/live/mortgageguardian.org/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/mortgageguardian.org/privkey.pem;

    # Security Headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline' https://cdn.jsdelivr.net; style-src 'self' 'unsafe-inline';" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    add_header Permissions-Policy "geolocation=(), microphone=(), camera=()" always;
}
```

## 🚦 Pre-Launch Checklist

### Security
- [ ] SSL certificates installed and auto-renewal configured
- [ ] Security headers configured
- [ ] CORS properly configured for production domains
- [ ] API rate limiting enabled
- [ ] DDoS protection enabled (Cloudflare recommended)
- [ ] WAF rules configured
- [ ] Secrets rotated from development

### Infrastructure
- [ ] Database backups configured
- [ ] Redis persistence enabled
- [ ] Monitoring/alerting set up
- [ ] Error tracking (Sentry) configured
- [ ] Log aggregation configured
- [ ] Health checks configured
- [ ] Auto-scaling configured (if applicable)

### Legal/Compliance
- [ ] Privacy Policy updated with domain
- [ ] Terms of Service updated
- [ ] Cookie consent banner configured
- [ ] GDPR/CCPA compliance verified
- [ ] SSL Labs A+ rating achieved
- [ ] Security.txt file added

### Testing
- [ ] Load testing completed
- [ ] Security scanning completed
- [ ] Mobile app tested with production API
- [ ] Payment flow tested (if applicable)
- [ ] Email delivery tested
- [ ] Error pages configured (404, 500, etc.)

## 📈 Monitoring Setup

### Recommended Services
1. **Uptime Monitoring**: UptimeRobot, Pingdom
2. **Error Tracking**: Sentry, Rollbar
3. **Analytics**: Google Analytics, Plausible
4. **Performance**: Lighthouse CI, WebPageTest
5. **Security**: Snyk, OWASP ZAP

## 🎯 Quick Deployment Commands

### Deploy to Vercel (Frontend)
```bash
cd frontend
vercel --prod
vercel domains add app.mortgageguardian.org
```

### Deploy to Railway (Backend)
```bash
cd backend-express
railway up
railway domain add api.mortgageguardian.org
```

### Deploy with Docker (VPS)
```bash
# On your server
git clone https://github.com/ngarrison-stack/Mortgage-Guardian-2.0.git
cd Mortgage-Guardian-2.0
docker-compose -f docker-compose.production.yml up -d
```

## 📞 Support Configuration

### Email Setup
- support@mortgageguardian.org
- security@mortgageguardian.org
- privacy@mortgageguardian.org

### Status Page
Set up status.mortgageguardian.org using:
- Cachet
- Upptime
- BetterUptime

---

Ready to launch mortgageguardian.org! 🚀