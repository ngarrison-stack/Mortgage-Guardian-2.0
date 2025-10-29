#!/usr/bin/env bash
set -euo pipefail

# Helper script to run fastlane setup lanes locally.
# Usage:
#   ./scripts/setup_appstore.sh --create-app --setup-signing --match-git git@github.com:you/certificates.git

PRINT_USAGE(){
  cat <<EOF
Usage: $0 [--create-app] [--setup-signing] [--app-name NAME] [--bundle-id ID] [--sku SKU] [--match-git URL]

Options:
  --create-app        Create the App Store Connect app record using fastlane produce
  --setup-signing     Run fastlane match to create and sync signing certificates
  --app-name NAME     App display name (default: "Mortgage Guardian")
  --bundle-id ID      Bundle identifier (default: com.nickgarrison.mortgageguardian)
  --sku SKU           SKU identifier for produce
  --match-git URL     Git URL for match certificates repo (required for --setup-signing)
EOF
}

CREATE_APP=false
SETUP_SIGNING=false
APP_NAME="Mortgage Guardian"
BUNDLE_ID="com.nickgarrison.mortgageguardian"
SKU="mortgage-guardian-1"
MATCH_GIT=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --create-app) CREATE_APP=true; shift ;; 
    --setup-signing) SETUP_SIGNING=true; shift ;; 
    --app-name) APP_NAME="$2"; shift 2 ;; 
    --bundle-id) BUNDLE_ID="$2"; shift 2 ;; 
    --sku) SKU="$2"; shift 2 ;; 
    --match-git) MATCH_GIT="$2"; shift 2 ;; 
    -h|--help) PRINT_USAGE; exit 0 ;; 
    *) echo "Unknown option: $1"; PRINT_USAGE; exit 1 ;;
  esac
done

if [ "$CREATE_APP" = false ] && [ "$SETUP_SIGNING" = false ]; then
  PRINT_USAGE
  exit 1
fi

if [ "$CREATE_APP" = true ]; then
  echo "Running fastlane setup_app..."
  bundle exec fastlane ios setup_app app_name:"$APP_NAME" bundle_id:"$BUNDLE_ID" sku:"$SKU"
fi

if [ "$SETUP_SIGNING" = true ]; then
  if [ -z "$MATCH_GIT" ]; then
    echo "--match-git is required when using --setup-signing"
    exit 1
  fi
  export MATCH_GIT_URL="$MATCH_GIT"
  echo "Running fastlane setup_signing with match repo $MATCH_GIT..."
  bundle exec fastlane ios setup_signing bundle_id:"$BUNDLE_ID"
fi

echo "Done."