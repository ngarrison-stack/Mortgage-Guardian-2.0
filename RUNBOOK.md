# Incident Response Runbook

Operational procedures for responding to Mortgage Guardian production incidents.

## Incident Severity Levels

| Level | Name | Definition | Response Time | Examples |
|-------|------|------------|---------------|----------|
| **P1** | Critical | Service completely down or data loss risk | Immediate (< 5 min) | Backend unreachable, database corruption, security breach |
| **P2** | High | Major feature broken, many users affected | < 15 min | Document processing failing, authentication down, Plaid integration broken |
| **P3** | Medium | Minor feature broken, workaround exists | < 1 hour | Slow response times, single endpoint failing, non-critical service degraded |
| **P4** | Low | Cosmetic issue, no functional impact | Next business day | UI rendering glitch, log formatting issue, non-critical warning |

## Immediate Response Checklist (First 5 Minutes)

Run these steps in order for any P1 or P2 incident:

1. **Check liveness** -- is the process running?
   ```bash
   curl -s http://<HOST>:3000/health/live
   # Expected: {"status":"ok"}
   ```

2. **Check readiness** -- are dependencies connected?
   ```bash
   curl -s http://<HOST>:3000/health/ready
   # Expected: {"status":"ready","checks":{"supabase":{"status":"connected",...},"redis":{"status":"connected",...}}}
   # 503 = one or more dependencies down
   ```

3. **Check full health** -- service status, version, uptime
   ```bash
   curl -s http://<HOST>:3000/health | python3 -m json.tool
   # Look for: status (healthy/degraded), uptime, services (anthropic/plaid/supabase booleans)
   ```

4. **Check metrics** -- response times and error rates
   ```bash
   curl -s http://<HOST>:3000/metrics | python3 -m json.tool
   # Alert if: p99 > 1000ms, errorRate > 1%, heapUsed/heapTotal > 80%
   ```

5. **Check Sentry** -- recent errors and frequency (if SENTRY_DSN configured)

6. **Run deployment validation script**
   ```bash
   bash scripts/validate-deployment.sh http://<HOST>:3000
   # Checks: health endpoints, security headers, API structure, env validation
   ```

7. **Check container/process status**
   ```bash
   # Docker
   docker ps --filter name=mg-backend
   docker logs --tail 50 mg-backend

   # Docker Compose
   docker compose ps
   docker compose logs --tail 50 backend
   ```

## Common Incident Playbooks

### 1. Backend Not Responding

**Symptoms:** /health/live returns connection refused or timeout.

1. Check if the process/container is running:
   ```bash
   docker ps --filter name=mg-backend
   # Or: docker compose ps
   ```
2. Check container logs for crash reason:
   ```bash
   docker logs --tail 100 mg-backend
   ```
3. Check for port conflicts (default: 3000):
   ```bash
   lsof -i :3000
   ```
4. Verify environment variables are loaded (see [ENV-GUIDE.md](./ENV-GUIDE.md)):
   ```bash
   docker exec mg-backend env | grep -E "SUPABASE_URL|PORT|NODE_ENV"
   ```
5. Restart the container:
   ```bash
   docker compose restart backend
   ```
6. If restart fails, check for missing required env vars -- server exits on validation failure. Required: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_KEY`, `DOCUMENT_ENCRYPTION_KEY`.
7. If persistent, **rollback** (see [Rollback Decision Matrix](#rollback-decision-matrix)).

### 2. High Response Times

**Symptoms:** p95/p99 response times elevated on /metrics, user-reported slowness.

1. Check current response time percentiles:
   ```bash
   curl -s http://<HOST>:3000/metrics | python3 -c "import sys,json; m=json.load(sys.stdin); print(f'p50={m[\"responseTime\"][\"p50\"]}ms p95={m[\"responseTime\"][\"p95\"]}ms p99={m[\"responseTime\"][\"p99\"]}ms')"
   ```
2. Check Supabase connection latency (in /health/ready response, `checks.supabase.latencyMs`):
   ```bash
   curl -s http://<HOST>:3000/health/ready | python3 -m json.tool
   ```
3. Check memory usage for potential GC pressure:
   ```bash
   curl -s http://<HOST>:3000/metrics | python3 -c "import sys,json; m=json.load(sys.stdin); print(f'heapUsed={m[\"memory\"][\"heapUsed\"]//1048576}MB heapTotal={m[\"memory\"][\"heapTotal\"]//1048576}MB')"
   ```
4. Check Redis connectivity (if configured):
   ```bash
   curl -s http://<HOST>:3000/health/ready | python3 -c "import sys,json; r=json.load(sys.stdin); print(r.get('checks',{}).get('redis',{}))"
   ```
5. If Supabase latency is high, check Supabase dashboard for database load.
6. If memory is climbing, restart the backend to reclaim memory, then investigate the leak.

### 3. Authentication Failures

**Symptoms:** Users get 401/403 errors, JWT validation failures in logs.

1. Check if Supabase is reachable (auth depends on Supabase):
   ```bash
   curl -s http://<HOST>:3000/health/ready | python3 -c "import sys,json; r=json.load(sys.stdin); print(r.get('checks',{}).get('supabase',{}))"
   ```
2. Check that auth-related env vars are set:
   - `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_KEY`
   - `JWT_SECRET` (if using custom JWT verification)
3. Check CORS configuration -- mismatched `ALLOWED_ORIGINS` causes silent auth failures:
   ```bash
   docker exec mg-backend env | grep ALLOWED_ORIGINS
   # Must NOT be "*" in production (see SECURITY-AUDIT.md accepted risks)
   ```
4. Check Clerk configuration for frontend (if applicable):
   - `NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY` must match environment (pk_test_ vs pk_live_)
   - `CLERK_SECRET_KEY` must match (sk_test_ vs sk_live_)
5. Check Sentry for specific error patterns (expired tokens, malformed headers).

### 4. Document Processing Failures

**Symptoms:** Document uploads succeed but analysis fails, /v1/documents/:id/status stuck.

1. Check if Claude API key is configured:
   ```bash
   curl -s http://<HOST>:3000/health | python3 -c "import sys,json; h=json.load(sys.stdin); print(f'anthropic={h[\"services\"][\"anthropic\"]}')"
   # Should print: anthropic=True
   ```
2. Check backend logs for Claude API errors:
   ```bash
   docker logs mg-backend 2>&1 | grep -i "claude\|anthropic\|analysis" | tail -20
   ```
3. Check for rate limiting (Anthropic API has per-minute limits):
   ```bash
   docker logs mg-backend 2>&1 | grep -i "rate.limit\|429" | tail -10
   ```
4. Verify document size is within limits (25MB body parser limit, ~20MB binary after base64 overhead).
5. Check Sentry for specific error traces on document analysis endpoints.
6. If Claude API is down, document processing will fail gracefully -- monitor Anthropic status page.

### 5. Database Connection Issues

**Symptoms:** /health/ready returns 503, `supabase: { status: "disconnected" }`.

1. Check Supabase readiness:
   ```bash
   curl -s http://<HOST>:3000/health/ready
   # Look for: checks.supabase.status and checks.supabase.latencyMs
   ```
2. Verify Supabase env vars:
   ```bash
   docker exec mg-backend env | grep SUPABASE
   # Required: SUPABASE_URL (https://), SUPABASE_ANON_KEY, SUPABASE_SERVICE_KEY
   ```
3. Test Supabase URL directly:
   ```bash
   curl -s https://<SUPABASE_URL>/rest/v1/ -H "apikey: <ANON_KEY>" | head -c 200
   ```
4. Check Supabase dashboard for:
   - Database status (paused projects auto-pause after inactivity)
   - Connection pool exhaustion
   - RLS policy errors in logs
5. If Supabase is paused, resume it from the dashboard. It may take 1-2 minutes.

### 6. Memory Issues

**Symptoms:** Increasing heapUsed in /metrics, OOM kills, slow garbage collection.

1. Check current memory state:
   ```bash
   curl -s http://<HOST>:3000/metrics | python3 -c "
   import sys,json
   m=json.load(sys.stdin)['memory']
   pct = m['heapUsed'] / m['heapTotal'] * 100
   print(f'RSS={m[\"rss\"]//1048576}MB Heap={m[\"heapUsed\"]//1048576}/{m[\"heapTotal\"]//1048576}MB ({pct:.0f}%)')
   "
   ```
2. If heap usage > 80%, restart the backend:
   ```bash
   docker compose restart backend
   ```
3. After restart, monitor memory over 10-15 minutes to see if it climbs again.
4. If memory keeps climbing after restart, likely a memory leak:
   - Check for large document processing in progress
   - Review recent deployments for new code paths
   - Consider rolling back to last known-good version

### 7. Plaid Integration Down

**Symptoms:** Bank account linking fails, transaction sync errors, webhook delivery failures.

1. Check if Plaid keys are configured:
   ```bash
   curl -s http://<HOST>:3000/health | python3 -c "import sys,json; h=json.load(sys.stdin); print(f'plaid={h[\"services\"][\"plaid\"]}')"
   ```
2. Check Plaid status page: https://status.plaid.com
3. Verify Plaid environment matches keys:
   ```bash
   docker exec mg-backend env | grep PLAID
   # PLAID_ENV should match key type (sandbox/development/production)
   ```
4. Check backend logs for Plaid-specific errors:
   ```bash
   docker logs mg-backend 2>&1 | grep -i "plaid" | tail -20
   ```
5. If webhooks are failing, verify `PLAID_WEBHOOK_URL` is accessible from the internet and `PLAID_WEBHOOK_VERIFICATION_KEY` is set (required in production).
6. Plaid sandbox has different behavior than production -- confirm environment.

## Rollback Decision Matrix

| Situation | Action | Reference |
|-----------|--------|-----------|
| Service completely down after deploy | **Rollback immediately** | [DEPLOY.md - Rollback Procedures](./DEPLOY.md#rollback-procedures) |
| Intermittent errors, < 5% of requests | **Hotfix** -- diagnose and patch | |
| Data corruption or security issue | **Rollback immediately** + investigate | [DEPLOY.md - Rollback Procedures](./DEPLOY.md#rollback-procedures) |
| Performance degradation (< 2x baseline) | **Monitor** -- may resolve with cache warmup | |
| Performance degradation (> 2x baseline) | **Rollback** if not resolved in 15 min | [DEPLOY.md - Rollback Procedures](./DEPLOY.md#rollback-procedures) |
| Single endpoint broken, rest working | **Hotfix** if fix is clear, else **rollback** | |
| Third-party service down (Plaid, Supabase) | **Wait** -- not a deploy issue | |

**Before rolling back:**
1. Note the current commit hash: `git rev-parse HEAD`
2. Save relevant logs: `docker logs mg-backend > /tmp/incident-logs-$(date +%s).txt`
3. Follow rollback procedures in [DEPLOY.md](./DEPLOY.md#rollback-procedures)

## Post-Incident

### Post-Mortem Template

After any P1 or P2 incident, create a post-mortem within 24 hours:

```markdown
# Post-Mortem: [Brief Title]

**Date:** YYYY-MM-DD
**Severity:** P1/P2
**Duration:** [start time] to [resolution time]
**Impact:** [number of users affected, features impacted]

## Timeline

| Time | Event |
|------|-------|
| HH:MM | [First alert / detection] |
| HH:MM | [Investigation started] |
| HH:MM | [Root cause identified] |
| HH:MM | [Fix deployed / rollback executed] |
| HH:MM | [Service fully restored] |

## Root Cause

[1-2 paragraphs explaining what went wrong and why]

## Resolution

[What was done to fix it -- rollback, hotfix, config change]

## Prevention

- [ ] [Action item 1 to prevent recurrence]
- [ ] [Action item 2]

## Lessons Learned

- [What went well in the response]
- [What could be improved]
```

---

**Related documentation:**
- [DEPLOY.md](./DEPLOY.md) -- Deployment procedures and rollback instructions
- [MONITORING.md](./MONITORING.md) -- Health endpoints, metrics, and observability
- [ENV-GUIDE.md](./ENV-GUIDE.md) -- Environment variable reference
- [SECURITY-AUDIT.md](./SECURITY-AUDIT.md) -- Security audit report and accepted risks
