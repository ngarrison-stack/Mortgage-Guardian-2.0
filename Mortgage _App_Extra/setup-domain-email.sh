#!/bin/bash

# ============================================
# Domain & Email Setup for mortgageguardian.org
# ============================================

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}     🌐 MortgageGuardian.org Domain & Email Setup${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Function to check domain status
check_domain() {
    echo -e "${YELLOW}Checking domain status...${NC}"
    echo ""

    # Check nameservers
    echo -e "${BLUE}Current Nameservers:${NC}"
    dig +short NS mortgageguardian.org

    # Check A records
    echo -e "${BLUE}Current A Records:${NC}"
    dig +short A mortgageguardian.org

    echo ""
}

# Main menu
main_menu() {
    echo -e "${BLUE}What would you like to set up?${NC}"
    echo ""
    echo "1) Quick Setup with Cloudflare (Recommended)"
    echo "2) Quick Setup with Vercel + Railway"
    echo "3) Setup Email Service"
    echo "4) Configure Custom DNS"
    echo "5) Check Domain Status"
    echo "6) Generate DNS Records"
    echo "7) Exit"
    echo ""
    read -p "Enter choice [1-7]: " choice
}

# Cloudflare Setup (Recommended)
setup_cloudflare() {
    echo -e "${CYAN}══════════════════════════════════════════${NC}"
    echo -e "${CYAN}   Cloudflare Setup (Recommended)${NC}"
    echo -e "${CYAN}══════════════════════════════════════════${NC}"
    echo ""
    echo -e "${GREEN}Benefits:${NC}"
    echo "✅ Free SSL certificates"
    echo "✅ DDoS protection"
    echo "✅ Global CDN"
    echo "✅ Free email routing"
    echo "✅ Analytics included"
    echo ""

    echo -e "${YELLOW}Step 1: Add site to Cloudflare${NC}"
    echo "1. Go to: https://dash.cloudflare.com/sign-up"
    echo "2. Add site: mortgageguardian.org"
    echo "3. Select FREE plan"
    echo ""
    read -p "Press Enter after adding site to Cloudflare..."

    echo -e "${YELLOW}Step 2: Update nameservers at your registrar${NC}"
    echo "Cloudflare will provide 2 nameservers like:"
    echo "  • xxx.ns.cloudflare.com"
    echo "  • yyy.ns.cloudflare.com"
    echo ""
    echo "Update these at your domain registrar (GoDaddy, Namecheap, etc.)"
    echo ""
    read -p "Press Enter after updating nameservers..."

    echo -e "${YELLOW}Step 3: Configure DNS Records in Cloudflare${NC}"
    echo ""
    echo "Add these records in Cloudflare DNS:"
    echo ""

    read -p "What's your server/hosting IP? (Enter 'vercel' for Vercel or 'railway' for Railway): " SERVER_IP

    if [[ "$SERVER_IP" == "vercel" ]]; then
        cat << EOF
${GREEN}For Vercel Hosting:${NC}
Type    Name    Content                     Proxy
CNAME   @       cname.vercel-dns.com       ✅
CNAME   www     cname.vercel-dns.com       ✅
CNAME   app     cname.vercel-dns.com       ✅
EOF
    elif [[ "$SERVER_IP" == "railway" ]]; then
        cat << EOF
${GREEN}For Railway Hosting:${NC}
Type    Name    Content                            Proxy
CNAME   api     your-project.up.railway.app       ✅
EOF
        echo ""
        echo "Also add Vercel records for frontend (see above)"
    else
        cat << EOF
${GREEN}For VPS/Custom Server:${NC}
Type    Name    Content           Proxy
A       @       ${SERVER_IP}      ✅
A       www     ${SERVER_IP}      ✅
A       app     ${SERVER_IP}      ✅
A       api     ${SERVER_IP}      ✅
EOF
    fi

    echo ""
    echo -e "${YELLOW}Step 4: Configure SSL/TLS${NC}"
    echo "In Cloudflare > SSL/TLS > Overview:"
    echo "Set to: Full (strict)"
    echo ""

    echo -e "${YELLOW}Step 5: Configure Security${NC}"
    echo "Enable these in Cloudflare:"
    echo "• Always Use HTTPS: ON"
    echo "• Automatic HTTPS Rewrites: ON"
    echo "• Minimum TLS Version: 1.2"
    echo ""

    read -p "Press Enter to continue..."
    setup_email_cloudflare
}

# Email setup with Cloudflare
setup_email_cloudflare() {
    echo ""
    echo -e "${CYAN}══════════════════════════════════════════${NC}"
    echo -e "${CYAN}   Email Setup with Cloudflare${NC}"
    echo -e "${CYAN}══════════════════════════════════════════${NC}"
    echo ""

    echo -e "${BLUE}Choose email option:${NC}"
    echo "1) Cloudflare Email Routing (Free - Forward to Gmail/Outlook)"
    echo "2) Google Workspace ($6/user/month)"
    echo "3) Custom SMTP (SendGrid/Mailgun)"
    echo ""
    read -p "Enter choice [1-3]: " email_choice

    case $email_choice in
        1)
            echo -e "${GREEN}Cloudflare Email Routing (Free)${NC}"
            echo ""
            echo "1. Go to Cloudflare Dashboard > Email > Email Routing"
            echo "2. Enable Email Routing"
            echo "3. Add destination addresses (your personal email)"
            echo "4. Create custom addresses:"
            echo "   • support@mortgageguardian.org → your@gmail.com"
            echo "   • info@mortgageguardian.org → your@gmail.com"
            echo "   • hello@mortgageguardian.org → your@gmail.com"
            echo ""
            echo "MX Records (will be added automatically):"
            echo "  MX    @    1  mx1.forwardemail.net"
            echo "  MX    @    5  mx2.forwardemail.net"
            echo ""
            ;;
        2)
            echo -e "${GREEN}Google Workspace Setup${NC}"
            echo ""
            echo "1. Sign up at: https://workspace.google.com"
            echo "2. Verify domain ownership"
            echo "3. Add these MX records in Cloudflare:"
            echo ""
            echo "  MX    @    1   aspmx.l.google.com"
            echo "  MX    @    5   alt1.aspmx.l.google.com"
            echo "  MX    @    5   alt2.aspmx.l.google.com"
            echo "  MX    @    10  alt3.aspmx.l.google.com"
            echo "  MX    @    10  alt4.aspmx.l.google.com"
            echo ""
            echo "SPF Record:"
            echo "  TXT   @    v=spf1 include:_spf.google.com ~all"
            echo ""
            ;;
        3)
            echo -e "${GREEN}Custom SMTP (SendGrid)${NC}"
            echo ""
            echo "For transactional emails (from your app):"
            echo "1. Sign up at: https://sendgrid.com"
            echo "2. Verify domain in SendGrid"
            echo "3. Add these DNS records:"
            echo ""
            echo "  CNAME    em1234    sendgrid.net"
            echo "  CNAME    s1._domainkey    s1.domainkey.sendgrid.net"
            echo "  CNAME    s2._domainkey    s2.domainkey.sendgrid.net"
            echo ""
            ;;
    esac

    echo ""
    read -p "Press Enter to continue..."
}

# Vercel + Railway Setup
setup_vercel_railway() {
    echo -e "${CYAN}══════════════════════════════════════════${NC}"
    echo -e "${CYAN}   Vercel + Railway Quick Deploy${NC}"
    echo -e "${CYAN}══════════════════════════════════════════${NC}"
    echo ""

    echo -e "${YELLOW}Step 1: Deploy Frontend to Vercel${NC}"
    echo ""

    # Check if Vercel CLI is installed
    if ! command -v vercel &> /dev/null; then
        echo "Installing Vercel CLI..."
        npm i -g vercel
    fi

    cd frontend
    echo "Deploying frontend to Vercel..."
    vercel --yes

    echo ""
    echo -e "${GREEN}Frontend deployed!${NC}"
    echo "Now add custom domain in Vercel Dashboard:"
    echo "1. Go to your project settings"
    echo "2. Add domain: app.mortgageguardian.org"
    echo ""
    read -p "Press Enter after adding domain in Vercel..."

    cd ..

    echo -e "${YELLOW}Step 2: Deploy Backend to Railway${NC}"
    echo ""

    # Check if Railway CLI is installed
    if ! command -v railway &> /dev/null; then
        echo "Installing Railway CLI..."
        npm i -g @railway/cli
    fi

    cd backend-express
    echo "Login to Railway..."
    railway login

    echo "Deploying backend to Railway..."
    railway up

    echo ""
    echo -e "${GREEN}Backend deployed!${NC}"
    echo "Now add custom domain in Railway Dashboard:"
    echo "1. Go to your project settings"
    echo "2. Add domain: api.mortgageguardian.org"
    echo ""
    read -p "Press Enter after adding domain in Railway..."

    cd ..

    echo -e "${GREEN}✅ Deployment complete!${NC}"
    echo ""
    echo "Your sites will be available at:"
    echo "  • https://app.mortgageguardian.org (frontend)"
    echo "  • https://api.mortgageguardian.org (backend)"
    echo ""
}

# Generate DNS records
generate_dns_records() {
    echo -e "${CYAN}══════════════════════════════════════════${NC}"
    echo -e "${CYAN}   DNS Records for mortgageguardian.org${NC}"
    echo -e "${CYAN}══════════════════════════════════════════${NC}"
    echo ""

    read -p "Enter your deployment type (cloudflare/vercel/vps): " deploy_type

    case $deploy_type in
        cloudflare)
            echo -e "${GREEN}Cloudflare DNS Records:${NC}"
            cat << 'EOF'
# Website Records
A       @       YOUR_SERVER_IP    ✅ Proxied
A       www     YOUR_SERVER_IP    ✅ Proxied
A       app     YOUR_SERVER_IP    ✅ Proxied
A       api     YOUR_SERVER_IP    ✅ Proxied

# Email Records (Cloudflare Email Routing)
MX      @       1   mx1.forwardemail.net
MX      @       5   mx2.forwardemail.net
TXT     @       "v=spf1 include:_spf.forwardemail.net ~all"

# Security Records
TXT     @       "v=spf1 include:_spf.google.com ~all"
CAA     @       0 issue "letsencrypt.org"
CAA     @       0 issuewild "letsencrypt.org"
EOF
            ;;

        vercel)
            echo -e "${GREEN}Vercel + Railway DNS Records:${NC}"
            cat << 'EOF'
# Frontend (Vercel)
CNAME   app     cname.vercel-dns.com
CNAME   www     cname.vercel-dns.com

# Backend (Railway)
CNAME   api     your-project.up.railway.app

# Landing Page
CNAME   @       cname.vercel-dns.com

# Email (Google Workspace)
MX      @       1   aspmx.l.google.com
MX      @       5   alt1.aspmx.l.google.com
MX      @       5   alt2.aspmx.l.google.com
MX      @       10  alt3.aspmx.l.google.com
MX      @       10  alt4.aspmx.l.google.com
TXT     @       "v=spf1 include:_spf.google.com ~all"
EOF
            ;;

        vps)
            read -p "Enter your VPS IP address: " vps_ip
            echo -e "${GREEN}VPS DNS Records:${NC}"
            cat << EOF
# A Records (Replace with your VPS IP)
A       @       ${vps_ip}
A       www     ${vps_ip}
A       app     ${vps_ip}
A       api     ${vps_ip}
A       mail    ${vps_ip}

# Email Records (if using local mail server)
MX      @       10  mail.mortgageguardian.org
TXT     @       "v=spf1 ip4:${vps_ip} ~all"

# DKIM (generate with your mail server)
TXT     mail._domainkey    "k=rsa; p=YOUR_DKIM_KEY"

# DMARC
TXT     _dmarc    "v=DMARC1; p=quarantine; rua=mailto:postmaster@mortgageguardian.org"
EOF
            ;;
    esac

    echo ""
    echo -e "${YELLOW}Copy these records to your DNS provider${NC}"
    echo ""
}

# Check requirements
check_requirements() {
    echo -e "${YELLOW}Checking requirements...${NC}"

    # Check Node.js
    if ! command -v node &> /dev/null; then
        echo -e "${RED}❌ Node.js not installed${NC}"
        exit 1
    fi

    # Check npm
    if ! command -v npm &> /dev/null; then
        echo -e "${RED}❌ npm not installed${NC}"
        exit 1
    fi

    echo -e "${GREEN}✅ All requirements met${NC}"
    echo ""
}

# Main execution
check_requirements

while true; do
    main_menu

    case $choice in
        1) setup_cloudflare ;;
        2) setup_vercel_railway ;;
        3) setup_email_cloudflare ;;
        4) generate_dns_records ;;
        5) check_domain ;;
        6) generate_dns_records ;;
        7)
            echo -e "${GREEN}Setup complete! Your domain will be live soon.${NC}"
            echo ""
            echo "Next steps:"
            echo "1. Wait 5-30 minutes for DNS propagation"
            echo "2. Test your site: https://mortgageguardian.org"
            echo "3. Test email: send to support@mortgageguardian.org"
            echo ""
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid option${NC}"
            ;;
    esac
done