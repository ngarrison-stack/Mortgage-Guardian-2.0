# AWS Backend - ARCHIVED

This directory contained the AWS Lambda/SAM backend which is no longer usable due to AWS account suspension.

## Status: REPLACED

The AWS-based backend has been replaced with a modern Express.js backend that doesn't require AWS.

## New Backend Location

The new AWS-free backend is located at:
```
backend-express/
```

## What Was Replaced

| AWS Service | Replacement |
|-------------|-------------|
| AWS Lambda | Railway/Vercel/Render |
| API Gateway | Express.js |
| AWS Bedrock | Direct Anthropic Claude API |
| DynamoDB | Supabase PostgreSQL |
| S3 | Supabase Storage |
| CloudWatch | Railway/Vercel Logs |

## Migration Benefits

- ✅ 80-90% cost reduction
- ✅ Easier deployment (git push)
- ✅ Better developer experience
- ✅ More flexible architecture
- ✅ Free tier available
- ✅ No AWS account needed

## How to Use New Backend

See:
- `../backend-express/README.md` - Backend documentation
- `../MIGRATION-FROM-AWS.md` - Migration guide
- `../QUICK-START-NO-AWS.md` - Quick start guide

## Old AWS Files Location

The original AWS files were moved to:
```
mortgage-guardian-backend-OLD-AWS/
```

These files are kept for reference only and should not be used.

## Do Not Use

⚠️ **This backend is deprecated and will not work without an active AWS account.**

Use the new backend in `backend-express/` instead.

---

Last updated: $(date)
AWS-free since: 2024
