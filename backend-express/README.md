# Mortgage Guardian Backend (AWS-Free)

A complete Express.js backend for Mortgage Guardian 2.0, replacing AWS Lambda/API Gateway/S3/DynamoDB with Railway + Supabase.

## 🚀 Features

- ✅ **Claude AI Integration** - Direct Anthropic API (no AWS Bedrock)
- ✅ **Plaid Bank Integration** - Full Plaid API support with mock fallback
- ✅ **Document Storage** - Supabase Storage (S3-compatible)
- ✅ **Database** - Supabase PostgreSQL
- ✅ **Rate Limiting** - Built-in protection
- ✅ **CORS** - Configured for iOS app
- ✅ **Security** - Helmet.js, compression, proper headers
- ✅ **Logging** - Morgan HTTP request logging

## 📦 Tech Stack

- **Backend**: Node.js 18+ with Express.js
- **AI**: Anthropic Claude API
- **Database**: Supabase (PostgreSQL)
- **Storage**: Supabase Storage
- **Banking**: Plaid API
- **Hosting**: Railway (or Vercel/Render)

## 🛠️ Setup

### 1. Install Dependencies

```bash
npm install
```

### 2. Configure Environment

Create `.env` file (copy from `.env.example`):

```bash
# Server
NODE_ENV=development
PORT=3000

# Anthropic Claude API
ANTHROPIC_API_KEY=sk-ant-your-api-key

# Plaid
PLAID_CLIENT_ID=your-client-id
PLAID_SECRET=your-secret
PLAID_ENV=sandbox

# Supabase
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_KEY=your-service-role-key
```

### 3. Setup Supabase

1. Create project at https://supabase.com
2. Run the SQL from `../MIGRATION-FROM-AWS.md` to create tables
3. Create storage bucket named `documents`
4. Copy URL and service key to `.env`

### 4. Run Locally

```bash
# Development mode (auto-reload)
npm run dev

# Production mode
npm start
```

## 📡 API Endpoints

### Health Check
- `GET /health` - Server health status

### Claude AI
- `POST /v1/ai/claude/analyze` - Analyze mortgage documents
- `POST /v1/ai/claude/test` - Test Claude API connection

### Plaid Banking
- `POST /v1/plaid/link_token` - Create Link token
- `POST /v1/plaid/sandbox_public_token` - Create sandbox token
- `POST /v1/plaid/exchange_token` - Exchange public for access token
- `POST /v1/plaid/accounts` - Get account information
- `POST /v1/plaid/transactions` - Get transaction history
- `POST /v1/plaid/test` - Test Plaid connection

### Documents
- `POST /v1/documents/upload` - Upload document
- `GET /v1/documents?userId=xxx` - List user's documents
- `GET /v1/documents/:documentId?userId=xxx` - Get specific document
- `DELETE /v1/documents/:documentId?userId=xxx` - Delete document

## 🚀 Deployment

### Option 1: Railway (Recommended)

1. Sign up at https://railway.app
2. Create new project → Deploy from GitHub
3. Select this repository's `backend-express` folder
4. Add environment variables in Railway dashboard
5. Deploy!

Railway will give you a URL like: `https://mortgage-guardian.up.railway.app`

### Option 2: Vercel

1. Install Vercel CLI: `npm install -g vercel`
2. Run: `vercel --prod`
3. Add environment variables via dashboard
4. Done!

### Option 3: Render

1. Sign up at https://render.com
2. Create new Web Service
3. Connect GitHub repository
4. Build command: `npm install`
5. Start command: `npm start`
6. Add environment variables
7. Deploy!

## 🧪 Testing

### Test Health Endpoint
```bash
curl http://localhost:3000/health
```

### Test Claude API
```bash
curl -X POST http://localhost:3000/v1/ai/claude/test \
  -H "Content-Type: application/json"
```

### Test Plaid (Mock Mode)
```bash
curl -X POST http://localhost:3000/v1/plaid/link_token \
  -H "Content-Type: application/json" \
  -d '{"user_id":"test123"}'
```

### Test Document Upload (Mock Mode)
```bash
curl -X POST http://localhost:3000/v1/documents/upload \
  -H "Content-Type: application/json" \
  -d '{
    "documentId": "doc123",
    "userId": "user123",
    "fileName": "statement.pdf",
    "content": "base64content",
    "documentType": "mortgage_statement"
  }'
```

## 📊 Mock Mode

If you don't have credentials configured, the backend automatically uses mock services:

- **Claude API**: Requires `ANTHROPIC_API_KEY` (get from https://console.anthropic.com)
- **Plaid**: Falls back to mock if credentials missing
- **Supabase**: Falls back to in-memory storage if not configured

This allows you to test the entire API without external dependencies!

## 🔒 Security Features

- **Helmet.js**: Security headers
- **Rate Limiting**: Prevents abuse (100 req/15min by default)
- **CORS**: Configurable allowed origins
- **Input Validation**: All endpoints validate required fields
- **Error Handling**: Safe error messages (no stack traces in production)

## 💰 Cost Comparison

### AWS Stack (OLD)
- Lambda + API Gateway + DynamoDB + S3: ~$500-1000/month for 10K users

### New Stack
- Railway: FREE ($5 credit) or $5-20/month
- Supabase: FREE (500MB) or $25/month Pro
- Claude API: Pay-per-use (same as before)
- **Total: ~$50-100/month = 80-90% savings!**

## 📝 Environment Variables Reference

| Variable | Required | Description |
|----------|----------|-------------|
| `NODE_ENV` | No | `development` or `production` |
| `PORT` | No | Server port (default: 3000) |
| `ANTHROPIC_API_KEY` | Yes | Claude API key from Anthropic |
| `PLAID_CLIENT_ID` | No | Plaid client ID (uses mock if missing) |
| `PLAID_SECRET` | No | Plaid secret (uses mock if missing) |
| `PLAID_ENV` | No | `sandbox` or `production` |
| `SUPABASE_URL` | No | Supabase project URL (uses mock if missing) |
| `SUPABASE_SERVICE_KEY` | No | Supabase service role key (uses mock if missing) |
| `RATE_LIMIT_WINDOW_MS` | No | Rate limit window (default: 900000) |
| `RATE_LIMIT_MAX_REQUESTS` | No | Max requests per window (default: 100) |
| `ALLOWED_ORIGINS` | No | CORS origins (default: `*`) |

## 🐛 Troubleshooting

### "Cannot find module" errors
```bash
rm -rf node_modules package-lock.json
npm install
```

### Port already in use
```bash
# Change PORT in .env or kill the process:
lsof -ti:3000 | xargs kill
```

### Supabase connection errors
- Verify `SUPABASE_URL` and `SUPABASE_SERVICE_KEY` are correct
- Check if tables exist (run SQL from migration guide)
- Verify storage bucket is created

### Claude API errors
- Verify API key is valid at https://console.anthropic.com
- Check rate limits (free tier: 5 requests/minute)
- Ensure key starts with `sk-ant-`

## 📚 Project Structure

```
backend-express/
├── server.js           # Main Express server
├── package.json        # Dependencies
├── .env.example        # Environment template
├── routes/             # API routes
│   ├── health.js       # Health check
│   ├── claude.js       # Claude AI endpoints
│   ├── plaid.js        # Plaid banking endpoints
│   └── documents.js    # Document CRUD
├── services/           # Business logic
│   ├── claudeService.js      # Claude API integration
│   ├── plaidService.js       # Plaid API integration
│   ├── mockPlaidService.js   # Plaid mock service
│   └── documentService.js    # Document storage (Supabase)
└── README.md           # This file
```

## 🎯 Next Steps

1. ✅ Deploy backend to Railway/Vercel
2. ✅ Get deployment URL
3. ✅ Update iOS app API configuration
4. ✅ Test end-to-end
5. ✅ Deploy iOS app to TestFlight

## 📞 Support

For issues or questions:
- Check the main project README
- Review `MIGRATION-FROM-AWS.md`
- Test with `/health` endpoint first

---

**No AWS Required! 🎉**
