#!/bin/bash

# Script to complete Plaid Link iOS SDK configuration
# Run this after adding the LinkKit package dependency in Xcode

echo "🔗 Configuring Plaid Link iOS SDK for MortgageGuardian"
echo "======================================================"
echo ""

# Check if we're in the right directory
if [ ! -f "MortgageGuardian.xcodeproj/project.pbxproj" ]; then
    echo "❌ Error: Please run this script from the project root directory"
    echo "   Current directory: $(pwd)"
    echo "   Expected: MortgageGuardian.xcodeproj should be in current directory"
    exit 1
fi

echo "✅ Found MortgageGuardian.xcodeproj"
echo ""

# Check if Info.plist has been updated
if grep -q "plaid" MortgageGuardian/Info.plist; then
    echo "✅ Info.plist configured with Plaid scheme support"
else
    echo "❌ Info.plist missing Plaid configuration"
    echo "   Please ensure LSApplicationQueriesSchemes includes 'plaid'"
fi

# Check if PlaidLinkService exists
if [ -f "MortgageGuardian/Services/PlaidLinkService.swift" ]; then
    echo "✅ PlaidLinkService.swift created"
else
    echo "❌ PlaidLinkService.swift not found"
fi

# Check if RealPlaidConnectionView exists
if [ -f "MortgageGuardian/Views/RealPlaidConnectionView.swift" ]; then
    echo "✅ RealPlaidConnectionView.swift created"
else
    echo "❌ RealPlaidConnectionView.swift not found"
fi

echo ""
echo "📋 MANUAL STEPS REQUIRED:"
echo ""
echo "1. Open MortgageGuardian.xcodeproj in Xcode"
echo ""
echo "2. Add Package Dependency (if not done yet):"
echo "   • File → Add Package Dependencies"
echo "   • URL: https://github.com/plaid/plaid-link-ios"
echo "   • Version: Up to Next Major Version (4.7.0+)"
echo "   • Add to Target: MortgageGuardian"
echo ""
echo "3. Add new Swift files to Xcode project:"
echo "   • Right-click on Services folder → Add Files"
echo "   • Select: MortgageGuardian/Services/PlaidLinkService.swift"
echo "   • Right-click on Views folder → Add Files"
echo "   • Select: MortgageGuardian/Views/RealPlaidConnectionView.swift"
echo ""
echo "4. Import LinkKit in files that use it:"
echo "   • Add 'import LinkKit' to PlaidLinkService.swift"
echo "   • Add 'import LinkKit' to RealPlaidConnectionView.swift"
echo ""
echo "5. Update your ContentView.swift to use RealPlaidConnectionView:"
echo "   • Replace PlaidConnectionView() with RealPlaidConnectionView()"
echo "   • Replace SimplePlaidService with PlaidLinkService"
echo ""
echo "6. Configure Plaid credentials:"
echo "   • Get your Plaid Client ID and Secret from dashboard.plaid.com"
echo "   • Update your backend with these credentials"
echo "   • Test in Plaid Sandbox environment first"
echo ""
echo "7. Build and test:"
echo "   • Build the project (Cmd+B)"
echo "   • Test Plaid Link flow in iOS Simulator"
echo "   • Verify bank connection works end-to-end"
echo ""
echo "🔧 PLAID ENVIRONMENT SETTINGS:"
echo ""
echo "• Development/Sandbox: Use .sandbox or .development"
echo "• Production: Use .production (requires Plaid approval)"
echo "• Link Token URL: /v1/plaid/link/token/create"
echo "• Exchange Token URL: /v1/plaid/link/token/exchange"
echo ""
echo "📚 Additional Resources:"
echo "• Plaid Link iOS Guide: https://plaid.com/docs/link/ios/"
echo "• Plaid Dashboard: https://dashboard.plaid.com"
echo "• LinkKit Documentation: https://plaid.github.io/plaid-link-ios/"
echo ""
echo "✨ After completing these steps, your app will have:"
echo "• Real Plaid bank connection flow"
echo "• Secure token exchange with your backend"
echo "• Account data fetching and management"
echo "• Professional banking integration UI"
echo ""

# Check if Xcode is running
if pgrep -x "Xcode" > /dev/null; then
    echo "📱 Xcode is currently running - perfect for adding the package!"
else
    echo "💡 Tip: Open Xcode to begin adding the LinkKit package dependency"
fi

echo ""
echo "🚀 Ready to transform your mortgage app with real banking integration!"