Token minting server (development)
=================================

This small Flask server uses a Google service account JSON to mint short-lived OAuth2 access tokens
for the Cloud Vision API. It's intended for local development/testing only. Do NOT expose this to the
public internet in production; instead, run a secured server in your private network or mint tokens
server-side in your backend.

How it works

- The server loads a service account JSON file (path provided by environment variable SERVICE_ACCOUNT_JSON).
- It exposes POST /token which returns a JSON { "access_token": "...", "expires_in": 3599 }

Setup (macOS)

1. Create a Python virtualenv and install requirements:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

1. Export your service account JSON path and run the server:

```bash
export SERVICE_ACCOUNT_JSON=/path/to/mortgage-guardian-e966d1fe23df.json
export FLASK_APP=token_server.py
flask run --host=127.0.0.1 --port=5001
```

1. In the app, save the token server URL to Keychain using the service name `com.mortgageguardian.api.token_server_url`.

   Example URL: `http://127.0.0.1:5001/token`

Security note

-------------
This server reads the private key and signs tokens on your behalf. Do not expose it publicly. In production,
implement proper authentication (mTLS, OAuth, API keys) and audit access logs.
