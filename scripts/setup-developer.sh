#!/bin/bash

# Mortgage Guardian - Developer Setup Script
# This script helps configure your Xcode project for deployment

echo "🚀 Mortgage Guardian - Developer Setup"
echo "======================================"
echo ""

# Check if Xcode is installed
if ! command -v xcodebuild &> /dev/null; then
    echo "❌ Xcode is not installed. Please install Xcode from the App Store."
    exit 1
fi

# Get current Xcode version
XCODE_VERSION=$(xcodebuild -version | head -n 1)
echo "✅ Found $XCODE_VERSION"

# Prompt for bundle identifier
echo ""
echo "📝 Enter your unique bundle identifier"
echo "   (e.g., com.yourcompany.mortgageguardian or com.yourname.mortgageguardian)"
read -p "Bundle Identifier: " BUNDLE_ID

if [ -z "$BUNDLE_ID" ]; then
    echo "❌ Bundle identifier cannot be empty"
    exit 1
fi

# Prompt for development team
echo ""
echo "📝 Enter your Apple Developer Team ID"
echo "   (You can find this in Xcode > Preferences > Accounts)"
echo "   (Leave empty to use Personal Team for testing)"
read -p "Team ID (optional): " TEAM_ID

# Update Info.plist with bundle identifier
echo ""
echo "🔧 Updating project configuration..."

# Create a backup of the project file
cp MortgageGuardian.xcodeproj/project.pbxproj MortgageGuardian.xcodeproj/project.pbxproj.backup

# Update bundle identifier in project
sed -i '' "s/com.mortgageguardian.app/${BUNDLE_ID}/g" MortgageGuardian.xcodeproj/project.pbxproj

if [ ! -z "$TEAM_ID" ]; then
    # Update team ID if provided
    sed -i '' "s/DEVELOPMENT_TEAM = \"\"/DEVELOPMENT_TEAM = \"${TEAM_ID}\"/g" MortgageGuardian.xcodeproj/project.pbxproj
fi

echo "✅ Project configuration updated"

# Check for simulator availability
echo ""
echo "🔍 Checking available simulators..."
xcrun simctl list devices available | grep "iPhone" | head -5

# Build for simulator to verify setup
echo ""
echo "🏗️ Building project for simulator to verify configuration..."
xcodebuild -scheme MortgageGuardian \
           -destination 'platform=iOS Simulator,name=iPhone 15 Pro,OS=latest' \
           -configuration Debug \
           build-for-testing &> /dev/null

if [ $? -eq 0 ]; then
    echo "✅ Build successful! Your project is configured correctly."
else
    echo "⚠️  Build had issues. Please check Xcode for details."
fi

echo ""
echo "======================================"
echo "🎉 Setup Complete!"
echo ""
echo "Next steps:"
echo "1. Open Xcode if not already open"
echo "2. Select a simulator or connect your iPhone"
echo "3. Press the Play button (▶️) to run the app"
echo ""
echo "Bundle ID: $BUNDLE_ID"
if [ ! -z "$TEAM_ID" ]; then
    echo "Team ID: $TEAM_ID"
fi
echo ""
echo "For help, see DEPLOYMENT_GUIDE.md"
echo "======================================"