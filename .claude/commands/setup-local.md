Setup local development environment for Mortgage Guardian from scratch:

**Phase 1: Install Dependencies**
1. Backend: `cd backend-express && npm install`
2. Frontend: `cd frontend && npm install`
3. Verify installations completed successfully

**Phase 2: Environment Configuration**
1. Create backend-express/.env from .env.example
2. Create frontend/.env.local from .env.example
3. Prompt user to add API keys for:
   - Anthropic Claude AI
   - Plaid (for bank integration)
   - Supabase (database/auth)
   - Clerk (frontend auth)
4. Validate all environment files

**Phase 3: Docker Services**
1. Check if Docker daemon is running
2. Start services: `docker-compose up -d`
3. Verify containers started:
   - PostgreSQL (port 5432)
   - Redis (port 6379)
   - MinIO (ports 9000/9001)
   - Mailhog (ports 1025/8025)

**Phase 4: Database Setup**
1. Run any database migrations if they exist
2. Verify database connectivity
3. Create initial tables/schema if needed

**Phase 5: Test Services**
1. Start backend: `cd backend-express && npm run dev`
2. Test health endpoint: http://localhost:3000/health
3. Start frontend: `cd frontend && npm run dev`
4. Test frontend: http://localhost:3001

**Phase 6: Verification**
1. Run integration tests
2. Verify all API endpoints respond
3. Check logs for errors
4. Create verification report

**Interactive Mode**:
Ask user for API keys if not already configured, provide links to get them, and validate each step before proceeding to the next.

**Output**:
Complete setup report with service URLs, status, and next steps for development.
