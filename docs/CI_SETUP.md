# CI & App Store Connect Setup Guide

This guide walks through the steps to set up App Store Connect and the GitHub Actions secrets needed to enable automatic TestFlight deployment.

## Prerequisites
- Apple Developer Program account
- App Store Connect access (Admin or App Manager role)
- Local macOS machine with Xcode and Ruby
- GitHub repository admin access

## Quick steps
1. Create the App ID in Apple Developer (bundle id: `com.nickgarrison.mortgageguardian`).
2. Create and download a Distribution certificate (.p12) and export it (password-protected).
3. Create an App Store provisioning profile and download it.
4. Create the App record in App Store Connect.
5. Generate an App Store Connect API key (.p8) and record Key ID + Issuer ID.
6. Add required secrets to GitHub (see below).
7. Run `./scripts/setup_appstore.sh --create-app --setup-signing --match-git git@github.com:you/certificates.git` locally to setup match.

## Required GitHub secrets
- `DEVELOPER_APP_ID` (your Apple ID email)
- `DEVELOPER_TEAM_ID` (your Apple Developer Team ID)
- `PROVISIONING_PROFILE_SPECIFIER` (name of App Store provisioning profile)
- `CERTIFICATE_BASE64` (base64 of the exported .p12)
- `TEMP_KEYCHAIN_PASSWORD` (random secure password for CI keychain)
- `APPLE_KEY_ID` (App Store Connect API key id)
- `APPLE_ISSUER_ID` (App Store Connect issuer id)
- `APPLE_KEY_CONTENT` (full contents of the .p8 key file)
- `FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD` (generated on appleid.apple.com)
- `MATCH_GIT_URL` (private git repo used by match; used locally or in CI)

## How to export the certificate to base64
1. Export distribution certificate from Keychain Access as a .p12 and set a password.
2. Run:

```bash
base64 -i /path/to/distribution.p12 > /tmp/distribution.p12.base64
pbcopy < /tmp/distribution.p12.base64
# Paste into the CERTIFICATE_BASE64 secret
```

## Running the setup script locally
1. Install fastlane and bundler:

```bash
sudo gem install bundler
bundle install
```

2. Run setup script (examples):

```bash
./scripts/setup_appstore.sh --create-app --app-name "Mortgage Guardian" --bundle-id com.nickgarrison.mortgageguardian --sku mg-001

# To run match (ensure you have a private git repo ready for match):
./scripts/setup_appstore.sh --setup-signing --match-git git@github.com:you/certificates.git
```

## Notes
- `match` stores sensitive certificates in a private git repo. Make sure the repo is private and access is limited.
- The script uses `bundle exec fastlane` to ensure your fastlane environment is consistent.
- The CI workflow will require the secrets listed above to be present in GitHub Secrets.

If you want, I can:
- Draft App Store metadata and screenshots placeholders
- Create a `.github/workflows/release.yml` that automatically publishes tagged releases
- Walk you through exporting the certificate step-by-step on your Mac

