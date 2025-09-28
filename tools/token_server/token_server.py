from flask import Flask, jsonify, request
import os
from google.oauth2 import service_account
from google.auth.transport.requests import Request as GoogleRequest

app = Flask(__name__)

SERVICE_ACCOUNT_JSON = os.environ.get('SERVICE_ACCOUNT_JSON')
if not SERVICE_ACCOUNT_JSON or not os.path.exists(SERVICE_ACCOUNT_JSON):
    raise RuntimeError('Please set SERVICE_ACCOUNT_JSON to the path of your service account JSON')

SCOPES = ['https://www.googleapis.com/auth/cloud-platform']

creds = service_account.Credentials.from_service_account_file(SERVICE_ACCOUNT_JSON, scopes=SCOPES)

@app.route('/token', methods=['POST', 'GET'])
def token():
    # Use the service account credentials to get an access token
    creds.refresh(GoogleRequest())
    # google-auth stores token in creds.token and expiry in creds.expiry
    expires_in = 3600
    if creds.expiry:
        try:
            now = creds._clock.now()
            expires_in = int((creds.expiry - now).total_seconds())
        except Exception:
            expires_in = 3600

    return jsonify({
        'access_token': creds.token,
        'expires_in': expires_in
    })

if __name__ == '__main__':
    app.run(host='127.0.0.1', port=5001)
