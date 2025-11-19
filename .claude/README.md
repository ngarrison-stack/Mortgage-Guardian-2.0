# Claude Code Custom Commands

This directory contains custom slash commands for the Mortgage Guardian project.

## Available Commands

### Development Environment

#### `/dev-status`
Check the complete status of all development services:
- Backend API (dependencies, env, running status)
- Frontend (dependencies, env, running status)
- Website deployment
- Docker services (PostgreSQL, Redis, MinIO)
- Deployment status (Railway, Netlify)

**Usage**: `/dev-status`

#### `/dev-start`
Start the complete development environment:
- Pre-flight checks (env files, dependencies)
- Start Docker services
- Start backend API
- Start frontend
- Post-start verification

**Usage**: `/dev-start`

#### `/setup-local`
Complete local development setup from scratch:
- Install all dependencies
- Create environment files
- Start Docker services
- Setup databases
- Test all services

**Usage**: `/setup-local`

### Testing & Validation

#### `/test-integrations`
Test all third-party API integrations:
- Anthropic Claude AI
- Plaid Banking
- Supabase Database
- Clerk Authentication
- Database Services (PostgreSQL, Redis, MinIO)

**Usage**: `/test-integrations`

#### `/validate-env`
Validate environment configuration:
- Check all required environment variables
- Validate formats and values
- Detect placeholder values
- Provide links to get API keys

**Usage**: `/validate-env`

### Deployment

#### `/deploy-status`
Check deployment status of all services:
- Backend API (Railway)
- Frontend/Website (Netlify)
- Health endpoints
- API connectivity

**Usage**: `/deploy-status`

#### `/deploy-backend`
Deploy backend to Railway:
- Pre-deployment checks
- Environment validation
- Deploy to Railway
- Post-deployment verification
- Custom domain configuration

**Usage**: `/deploy-backend`

#### `/deploy-frontend`
Deploy frontend/website to Netlify:
- Choose marketing site or dashboard
- Pre-deployment validation
- Deploy to Netlify
- Custom domain setup

**Usage**: `/deploy-frontend`

## Project Structure

```
.claude/
├── README.md                    # This file
├── settings.local.json          # Permissions configuration
└── commands/                    # Custom slash commands
    ├── dev-status.md           # Check dev environment status
    ├── dev-start.md            # Start development environment
    ├── setup-local.md          # Setup from scratch
    ├── test-integrations.md    # Test API integrations
    ├── validate-env.md         # Validate environment config
    ├── deploy-status.md        # Check deployment status
    ├── deploy-backend.md       # Deploy to Railway
    └── deploy-frontend.md      # Deploy to Netlify
```

## How to Use

In Claude Code, simply type the command with a forward slash:

```
/dev-status
```

Claude will execute the command and provide detailed feedback.

## Permissions

The `settings.local.json` file grants automatic approval for:
- Netlify CLI commands
- Railway CLI commands
- Git operations (add, commit, pull, etc.)
- Testing commands
- Health check endpoints

This prevents repetitive permission prompts during development.

## API Keys Required

The following API keys are needed (see `/validate-env` for detailed setup):

### Backend (backend-express/.env)
- `ANTHROPIC_API_KEY` - Get from https://console.anthropic.com/
- `PLAID_CLIENT_ID` - Get from https://dashboard.plaid.com/team/keys
- `PLAID_SECRET` - Get from https://dashboard.plaid.com/team/keys
- `SUPABASE_URL` - Get from https://app.supabase.com/project/_/settings/api
- `SUPABASE_ANON_KEY` - Get from Supabase dashboard
- `SUPABASE_SERVICE_KEY` - Get from Supabase dashboard

### Frontend (frontend/.env.local)
- `NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY` - Get from https://dashboard.clerk.com/
- `CLERK_SECRET_KEY` - Get from Clerk dashboard
- `NEXT_PUBLIC_API_URL` - Your backend URL

## Quick Start

1. **Setup local environment**:
   ```
   /setup-local
   ```

2. **Check status**:
   ```
   /dev-status
   ```

3. **Start development**:
   ```
   /dev-start
   ```

4. **Validate configuration**:
   ```
   /validate-env
   ```

5. **Test integrations**:
   ```
   /test-integrations
   ```

6. **Check deployments**:
   ```
   /deploy-status
   ```

## Troubleshooting

If a command doesn't work:
1. Make sure you're in the project root directory
2. Check that Claude Code is up to date
3. Verify the command file exists in `.claude/commands/`
4. Check permissions in `settings.local.json`

## Contributing

To add a new command:
1. Create a new `.md` file in `.claude/commands/`
2. Write clear instructions for what the command should do
3. Update this README with the new command
4. Test the command thoroughly

## Documentation

- Main project docs: `/CLAUDE.md`
- Backend setup: `/backend-express/README.md`
- Frontend setup: `/frontend/README.md`
- Deployment guides: Various `DEPLOYMENT-*.md` files
