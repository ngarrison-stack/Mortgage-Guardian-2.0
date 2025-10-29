#!/bin/bash

echo "🔨 Testing Mortgage Guardian Build"
echo "===================================="
echo ""

# Check if we're in the right directory
if [ ! -f "MortgageGuardian.xcodeproj/project.pbxproj" ]; then
    echo "❌ Error: Not in the project directory"
    exit 1
fi

echo "📱 Available Simulators:"
xcrun simctl list devices available | grep "iPhone" | grep -v "unavailable" | head -5

echo ""
echo "🏗️ Building for iPhone 17 Pro Simulator..."
echo ""

# Simple build command
xcodebuild -project MortgageGuardian.xcodeproj \
           -scheme MortgageGuardian \
           -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
           -configuration Debug \
           clean build \
           CODE_SIGN_IDENTITY="" \
           CODE_SIGNING_REQUIRED=NO \
           CODE_SIGNING_ALLOWED=NO

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Build successful!"
    echo ""
    echo "To run the app:"
    echo "1. Open Xcode"
    echo "2. Select iPhone 17 Pro simulator from device menu"
    echo "3. Press ▶️ (Play button)"
else
    echo ""
    echo "⚠️  Build failed. Opening Xcode for manual configuration..."
    open MortgageGuardian.xcodeproj
fi