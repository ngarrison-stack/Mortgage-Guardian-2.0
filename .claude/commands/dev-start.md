Start the complete Mortgage Guardian development environment:

**Pre-flight Checks**:
1. Verify environment files exist (.env for backend, .env.local for frontend)
2. Check all required API keys are configured
3. Verify dependencies are installed (run npm install if needed)

**Start Services** in this order:
1. Start Docker services (docker-compose up -d)
   - PostgreSQL database
   - Redis cache
   - MinIO object storage
   - Mailhog email testing

2. Start Backend API (backend-express/)
   - Run: npm run dev
   - Expected: Server running on http://localhost:3000
   - Verify: /health endpoint responds

3. Start Frontend (frontend/)
   - Run: npm run dev
   - Expected: Next.js server on http://localhost:3001
   - Verify: Homepage loads

**Post-start Verification**:
- Test backend health endpoint
- Verify Docker containers are running
- Check logs for any errors
- Provide URLs for all services

If any step fails, provide clear troubleshooting steps.
