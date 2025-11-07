#!/bin/bash

# Deploy Frontend to Netlify (FREE)

echo "🚀 Deploying to Netlify (100% Free)..."
echo ""

# Install Netlify CLI
if ! command -v netlify &> /dev/null; then
    echo "Installing Netlify CLI..."
    npm install -g netlify-cli
fi

cd frontend

# Build the project
echo "Building frontend..."
npm run build

# Deploy to Netlify
echo "Deploying to Netlify..."
netlify deploy --prod --dir=.next --site-name=mortgage-guardian-app

echo ""
echo "✅ Deployed to Netlify!"
echo ""
echo "Add custom domain in Netlify Dashboard:"
echo "1. Go to: https://app.netlify.com"
echo "2. Select your site"
echo "3. Domain settings → Add custom domain"
echo "4. Add: app.mortgageguardian.org"

cd ..