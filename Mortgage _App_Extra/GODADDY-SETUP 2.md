# 🌐 GoDaddy Setup Guide for mortgageguardian.org

## Quick Setup Options

### 🎯 Option 1: Use Cloudflare (RECOMMENDED)
**Why?** Free SSL, CDN, DDoS protection, and email forwarding

### 🚀 Option 2: Direct GoDaddy DNS
**Why?** Simpler, stay within GoDaddy ecosystem

---

## 📋 OPTION 1: Cloudflare Setup (Recommended)

### Step 1: Create Cloudflare Account
1. Go to https://dash.cloudflare.com/sign-up
2. Enter your email and create password
3. Click "Add a Site"
4. Enter: `mortgageguardian.org`
5. Select **FREE plan**

### Step 2: Change Nameservers in GoDaddy
1. **Login to GoDaddy**: https://www.godaddy.com
2. Go to **My Products** → **Domains**
3. Click on `mortgageguardian.org`
4. Click **Domain Settings** (or Manage)
5. Scroll to **Nameservers** section
6. Click **Change Nameservers**
7. Choose **"I'll use my own nameservers"**
8. Replace with Cloudflare's nameservers:
   ```
   Example (yours will be different):
   abby.ns.cloudflare.com
   brad.ns.cloudflare.com
   ```
9. Click **Save**
10. **Wait 2-24 hours for propagation**

### Step 3: Configure DNS in Cloudflare

Once nameservers are active, add these records in Cloudflare:

#### For Vercel/Railway Deployment:
| Type | Name | Content | Proxy Status |
|------|------|---------|--------------|
| CNAME | @ | cname.vercel-dns.com | Proxied ✅ |
| CNAME | www | cname.vercel-dns.com | Proxied ✅ |
| CNAME | app | cname.vercel-dns.com | Proxied ✅ |
| CNAME | api | your-backend.up.railway.app | Proxied ✅ |

#### For VPS/Custom Server:
| Type | Name | Content | Proxy Status |
|------|------|---------|--------------|
| A | @ | YOUR_SERVER_IP | Proxied ✅ |
| A | www | YOUR_SERVER_IP | Proxied ✅ |
| A | app | YOUR_SERVER_IP | Proxied ✅ |
| A | api | YOUR_SERVER_IP | Proxied ✅ |

### Step 4: Setup Email with Cloudflare (FREE)

1. In Cloudflare Dashboard → **Email** → **Email Routing**
2. Click **Get Started**
3. Add destination addresses (where to forward):
   - Your personal Gmail/Outlook
4. Create custom addresses:
   - `support@mortgageguardian.org` → your@gmail.com
   - `info@mortgageguardian.org` → your@gmail.com
   - `hello@mortgageguardian.org` → your@gmail.com
   - `noreply@mortgageguardian.org` → your@gmail.com

Cloudflare will automatically add MX records.

---

## 📋 OPTION 2: Direct GoDaddy DNS Setup

### Step 1: Access GoDaddy DNS Management
1. Login to https://www.godaddy.com
2. Go to **My Products** → **Domains**
3. Click on `mortgageguardian.org`
4. Click **DNS** or **Manage DNS**

### Step 2: Remove Default Records
Delete these if they exist:
- Any "Parked" CNAME records
- Default A record pointing to GoDaddy parking

### Step 3: Add DNS Records

#### For Vercel Frontend:
| Type | Name | Value | TTL |
|------|------|-------|-----|
| CNAME | app | cname.vercel-dns.com | 600 |
| CNAME | www | cname.vercel-dns.com | 600 |

#### For Railway Backend:
| Type | Name | Value | TTL |
|------|------|-------|-----|
| CNAME | api | your-project.up.railway.app | 600 |

#### For VPS/Custom Server:
| Type | Name | Value | TTL |
|------|------|-------|-----|
| A | @ | YOUR_SERVER_IP | 600 |
| A | www | YOUR_SERVER_IP | 600 |
| A | app | YOUR_SERVER_IP | 600 |
| A | api | YOUR_SERVER_IP | 600 |

### Step 4: Email Options with GoDaddy

#### Option A: GoDaddy Email Forwarding (Free - up to 100 forwards)
1. In Domain Settings → **Email Forwarding**
2. Click **Add Forwarder**
3. Create forwards:
   - `support` → your@gmail.com
   - `info` → your@gmail.com
   - `hello` → your@gmail.com

#### Option B: Microsoft 365 from GoDaddy ($6.99/month)
1. Go to **Email & Microsoft 365**
2. Purchase Basic plan
3. GoDaddy auto-configures MX records

#### Option C: Professional Email ($2.99/month)
1. Go to **Professional Email**
2. Purchase plan
3. Create mailboxes

---

## 🚀 Quick Deployment Commands

### Deploy Frontend to Vercel
```bash
cd frontend
npm install -g vercel
vercel --prod

# In Vercel Dashboard:
# Add domain: app.mortgageguardian.org
```

### Deploy Backend to Railway
```bash
cd backend-express
npm install -g @railway/cli
railway login
railway up

# In Railway Dashboard:
# Add domain: api.mortgageguardian.org
```

---

## ✅ DNS Propagation Check

After making changes, check propagation:

1. Visit: https://dnschecker.org
2. Enter: mortgageguardian.org
3. Check if new records are showing globally

**Note**: GoDaddy DNS changes typically propagate in:
- 5-30 minutes for most locations
- Up to 48 hours globally

---

## 📧 Test Your Email

Once configured, test email forwarding:

```bash
# From another email, send test to:
support@mortgageguardian.org
info@mortgageguardian.org
```

---

## 🔒 SSL Certificate

### With Cloudflare (Automatic)
- SSL is automatic and free
- No configuration needed

### With GoDaddy Direct
- Purchase SSL from GoDaddy ($79.99/year)
- OR use Let's Encrypt on your server (free)

---

## 🆘 Troubleshooting

### "Site Can't Be Reached"
- Wait for DNS propagation (up to 48 hours)
- Clear browser cache
- Try incognito/private mode

### Email Not Working
- Check MX records are correct
- Verify forwarding addresses
- Check spam folder

### SSL Errors
- With Cloudflare: Set SSL mode to "Full"
- With GoDaddy: Install SSL certificate

---

## 📞 Support Contacts

**GoDaddy Support**: 1-480-505-8877
**Hours**: 24/7

**Cloudflare Support**: https://support.cloudflare.com

---

## 🎯 Next Steps After DNS Setup

1. **Deploy your application**
   ```bash
   ./deploy-production.sh
   ```

2. **Configure production environment**
   - Update API keys in `.env.production`
   - Set up monitoring
   - Configure backups

3. **Test everything**
   - Visit: https://app.mortgageguardian.org
   - API: https://api.mortgageguardian.org/health
   - Send test email to support@mortgageguardian.org

---

**Ready to go live!** 🚀