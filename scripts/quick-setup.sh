#!/bin/bash

# Quick Setup Script - Uses default values for immediate testing

echo "🚀 Mortgage Guardian - Quick Setup"
echo "======================================"

# Use a default bundle ID for testing
BUNDLE_ID="com.nickgarrison.mortgageguardian"

echo "📱 Setting up with bundle ID: $BUNDLE_ID"

# Update project configuration
sed -i '' "s/com.mortgageguardian.app/${BUNDLE_ID}/g" MortgageGuardian.xcodeproj/project.pbxproj

echo "✅ Project configured!"
echo ""
echo "Next steps:"
echo "1. In Xcode, select your Apple ID in Signing & Capabilities"
echo "2. Choose iPhone 15 Pro simulator from the device menu"
echo "3. Press ▶️ to run the app"
echo ""
echo "The app will run with mock data - no backend needed for testing!"