#!/bin/bash

echo "Setting up AWS Authentication for Mortgage Guardian"
echo "===================================================="

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Step 1: Update Lambda Environment Variables${NC}"
echo "----------------------------------------------"
echo "You need to set your actual API keys:"
echo ""
echo "1. Get your Claude API key from: https://console.anthropic.com/account/keys"
echo "2. Get your Plaid credentials from: https://dashboard.plaid.com/account/keys"
echo ""
echo "Then run these commands:"
echo ""
echo "# Update Claude API key:"
echo "aws lambda update-function-configuration \\"
echo "  --function-name mortgage-guardian-backend-ClaudeAnalysisFunction-IgW3U0cBfFKk \\"
echo "  --environment Variables='{\"CLAUDE_API_KEY\":\"sk-ant-YOUR-ACTUAL-KEY\"}'"
echo ""
echo "# Update Plaid credentials:"
echo "aws lambda update-function-configuration \\"
echo "  --function-name mortgage-guardian-backend-PlaidFunction-H4YfvS7AG5zC \\"
echo "  --environment Variables='{\"PLAID_CLIENT_ID\":\"YOUR-CLIENT-ID\",\"PLAID_SECRET\":\"YOUR-SECRET\"}'"
echo ""

echo -e "${YELLOW}Step 2: Store API Gateway Key Securely (Optional - Better to use Cognito)${NC}"
echo "--------------------------------------------------------------------------------"
echo "For production, consider using AWS Cognito instead of API keys:"
echo ""
echo "aws cognito-idp create-user-pool --pool-name MortgageGuardianUsers"
echo ""

echo -e "${YELLOW}Step 3: iOS App Configuration${NC}"
echo "--------------------------------"
echo "The iOS app now stores the API key in Keychain."
echo "On first launch, you can:"
echo "1. Have users enter the API key in Settings"
echo "2. Fetch it from a secure configuration endpoint"
echo "3. Use AWS Amplify for authentication"
echo ""

echo -e "${GREEN}Security Best Practices:${NC}"
echo "• Never commit API keys to source control"
echo "• Use AWS Secrets Manager for production keys"
echo "• Implement user authentication with Cognito"
echo "• Rotate API keys regularly"
echo "• Use IAM roles for service-to-service auth"
echo ""

echo "For immediate testing, your current API Gateway key is:"
echo "jigiSOiRzIakK6yjVpG5t4QnLOkquwmq7c7USYm5"
echo ""
echo "Store this in the iOS app's Keychain or Settings."