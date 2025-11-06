#!/bin/bash

# Mortgage Guardian Production Deployment Script
# Domain: mortgageguardian.org

set -e

echo "🚀 Mortgage Guardian Production Deployment"
echo "=========================================="
echo "Domain: mortgageguardian.org"
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# Function to display menu
show_menu() {
    echo -e "${BLUE}Select Deployment Option:${NC}"
    echo "1) Deploy Frontend to Vercel"
    echo "2) Deploy Backend to Railway"
    echo "3) Deploy Both (Frontend + Backend)"
    echo "4) Deploy to VPS with Docker"
    echo "5) Configure DNS Records"
    echo "6) Generate SSL Certificates"
    echo "7) Run Production Tests"
    echo "8) Exit"
    echo ""
}

# Deploy Frontend to Vercel
deploy_frontend_vercel() {
    echo -e "${YELLOW}Deploying Frontend to Vercel...${NC}"
    cd frontend

    # Check if Vercel CLI is installed
    if ! command -v vercel &> /dev/null; then
        echo "Installing Vercel CLI..."
        npm i -g vercel
    fi

    # Deploy
    vercel --prod --yes

    # Add custom domain
    echo -e "${YELLOW}Adding custom domain app.mortgageguardian.org...${NC}"
    vercel domains add app.mortgageguardian.org

    echo -e "${GREEN}✅ Frontend deployed to Vercel!${NC}"
    echo -e "URL: https://app.mortgageguardian.org"
    cd ..
}

# Deploy Backend to Railway
deploy_backend_railway() {
    echo -e "${YELLOW}Deploying Backend to Railway...${NC}"
    cd backend-express

    # Check if Railway CLI is installed
    if ! command -v railway &> /dev/null; then
        echo "Installing Railway CLI..."
        npm i -g @railway/cli
    fi

    # Deploy
    railway up

    # Add custom domain
    echo -e "${YELLOW}Adding custom domain api.mortgageguardian.org...${NC}"
    railway domain add api.mortgageguardian.org

    echo -e "${GREEN}✅ Backend deployed to Railway!${NC}"
    echo -e "URL: https://api.mortgageguardian.org"
    cd ..
}

# Deploy to VPS with Docker
deploy_vps_docker() {
    echo -e "${YELLOW}Deploying to VPS with Docker...${NC}"

    read -p "Enter your VPS IP address: " VPS_IP
    read -p "Enter your SSH user (default: root): " SSH_USER
    SSH_USER=${SSH_USER:-root}

    echo -e "${BLUE}Connecting to $SSH_USER@$VPS_IP...${NC}"

    # Create deployment script
    cat > /tmp/deploy-vps.sh << 'DEPLOY_SCRIPT'
#!/bin/bash
# Update system
apt-get update
apt-get install -y docker.io docker-compose git

# Clone repository
cd /opt
rm -rf Mortgage-Guardian-2.0
git clone https://github.com/ngarrison-stack/Mortgage-Guardian-2.0.git
cd Mortgage-Guardian-2.0

# Copy production environment files
echo "Setting up environment files..."

# Start services
docker-compose -f docker-compose.production.yml down
docker-compose -f docker-compose.production.yml up -d

# Install Nginx if not present
if ! command -v nginx &> /dev/null; then
    apt-get install -y nginx certbot python3-certbot-nginx
fi

# Setup Nginx configuration
cat > /etc/nginx/sites-available/mortgageguardian << 'NGINX_CONFIG'
upstream backend {
    server localhost:3000;
}

upstream frontend {
    server localhost:3001;
}

server {
    listen 80;
    server_name mortgageguardian.org www.mortgageguardian.org;
    return 301 https://$server_name$request_uri;
}

server {
    listen 80;
    server_name api.mortgageguardian.org;

    location / {
        proxy_pass http://backend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

server {
    listen 80;
    server_name app.mortgageguardian.org;

    location / {
        proxy_pass http://frontend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}
NGINX_CONFIG

# Enable site
ln -sf /etc/nginx/sites-available/mortgageguardian /etc/nginx/sites-enabled/
nginx -t && systemctl reload nginx

echo "✅ Deployment complete!"
DEPLOY_SCRIPT

    # Copy and execute script on VPS
    scp /tmp/deploy-vps.sh $SSH_USER@$VPS_IP:/tmp/
    ssh $SSH_USER@$VPS_IP "chmod +x /tmp/deploy-vps.sh && /tmp/deploy-vps.sh"

    echo -e "${GREEN}✅ VPS deployment complete!${NC}"
    echo -e "${YELLOW}Next: Run 'Generate SSL Certificates' to secure your site${NC}"
}

# Configure DNS
configure_dns() {
    echo -e "${BLUE}DNS Configuration Required:${NC}"
    echo ""
    echo "Add these records to your DNS provider:"
    echo ""
    echo -e "${YELLOW}A Records:${NC}"
    echo "  @     →  Your-Server-IP"
    echo "  app   →  Your-Server-IP"
    echo "  api   →  Your-Server-IP"
    echo ""
    echo -e "${YELLOW}Or if using CDN/Proxy (Cloudflare):${NC}"
    echo "  @     →  Your-Server-IP (Proxied)"
    echo "  app   →  Your-Server-IP (Proxied)"
    echo "  api   →  Your-Server-IP (Proxied)"
    echo ""
    echo -e "${YELLOW}For Vercel/Railway deployment:${NC}"
    echo "  app   CNAME  cname.vercel-dns.com"
    echo "  api   CNAME  your-backend.up.railway.app"
    echo ""
    echo -e "${GREEN}After adding DNS records, wait 5-30 minutes for propagation${NC}"
}

# Generate SSL Certificates
generate_ssl() {
    echo -e "${YELLOW}Generating SSL Certificates...${NC}"

    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo -e "${RED}Note: Run this on your production server, not locally${NC}"
        echo ""
        echo "SSH to your server and run:"
        echo "sudo certbot --nginx -d mortgageguardian.org -d www.mortgageguardian.org -d app.mortgageguardian.org -d api.mortgageguardian.org"
    else
        sudo certbot --nginx -d mortgageguardian.org -d www.mortgageguardian.org -d app.mortgageguardian.org -d api.mortgageguardian.org
        echo -e "${GREEN}✅ SSL certificates generated!${NC}"
    fi
}

# Run production tests
run_tests() {
    echo -e "${YELLOW}Running Production Tests...${NC}"

    # Test API endpoint
    echo -e "${BLUE}Testing API...${NC}"
    curl -s https://api.mortgageguardian.org/health || curl -s http://api.mortgageguardian.org/health

    # Test Frontend
    echo -e "${BLUE}Testing Frontend...${NC}"
    curl -s -o /dev/null -w "%{http_code}" https://app.mortgageguardian.org || curl -s -o /dev/null -w "%{http_code}" http://app.mortgageguardian.org

    # SSL Test
    echo -e "${BLUE}Testing SSL...${NC}"
    echo | openssl s_client -connect mortgageguardian.org:443 2>/dev/null | grep "Verify return code"

    echo -e "${GREEN}✅ Tests complete!${NC}"
}

# Main loop
while true; do
    show_menu
    read -p "Enter choice [1-8]: " choice

    case $choice in
        1) deploy_frontend_vercel ;;
        2) deploy_backend_railway ;;
        3)
            deploy_frontend_vercel
            deploy_backend_railway
            ;;
        4) deploy_vps_docker ;;
        5) configure_dns ;;
        6) generate_ssl ;;
        7) run_tests ;;
        8)
            echo -e "${GREEN}Exiting deployment script${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid option${NC}"
            ;;
    esac

    echo ""
    read -p "Press Enter to continue..."
    clear
done