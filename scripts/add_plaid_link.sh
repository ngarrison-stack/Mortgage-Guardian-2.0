#!/bin/bash

# Script to add Plaid Link iOS SDK to MortgageGuardian project
# This script provides instructions for manual addition via Xcode

echo "🔗 Adding Plaid Link iOS SDK to MortgageGuardian"
echo "================================================="
echo ""
echo "📋 MANUAL STEPS (Required):"
echo ""
echo "1. Open MortgageGuardian.xcodeproj in Xcode"
echo ""
echo "2. Add Package Dependency:"
echo "   • File → Add Package Dependencies"
echo "   • Enter URL: https://github.com/plaid/plaid-link-ios"
echo "   • Dependency Rule: Up to Next Major Version"
echo "   • Minimum Version: 4.7.0"
echo "   • Add to Target: MortgageGuardian"
echo ""
echo "3. Import in your Swift files:"
echo "   import LinkKit"
echo ""
echo "4. Required Info.plist additions:"
echo "   • LSApplicationQueriesSchemes array with plaid scheme"
echo "   • NSCameraUsageDescription for camera access"
echo ""
echo "🚀 After adding the dependency, run:"
echo "   ./configure_plaid_link.sh"
echo ""
echo "📚 Documentation: https://plaid.com/docs/link/ios/"
echo ""

# Check if LinkKit is already added (this won't work until manually added)
if xcodebuild -list -project MortgageGuardian.xcodeproj 2>/dev/null | grep -q "LinkKit"; then
    echo "✅ Plaid LinkKit appears to be already added to the project"
else
    echo "⚠️  Plaid LinkKit not detected - please follow manual steps above"
fi

echo ""
echo "💡 Alternative: Use CocoaPods or Carthage if preferred"
echo "   Pod: pod 'Plaid', '~> 4.7'"