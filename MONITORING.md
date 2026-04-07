# Monitoring and Observability Guide

How to monitor Mortgage Guardian in production and interpret system health data.

## Health Endpoints

Three health endpoints are available without authentication or rate limiting.

### GET /health -- Full Status

Returns comprehensive service health including uptime, version, environment, configured services, and dependency checks.

```bash
curl -s http://localhost:3000/health | python3 -m json.tool
```

**Response:**
```json
{
  "status": "healthy",
  "timestamp": "2026-04-07T12:00:00.000Z",
  "uptime": 3600,
  "environment": "production",
  "version": "2.0.0",
  "services": {
    "anthropic": true,
    "plaid": true,
    "supabase": true
  },
  "checks": {
    "supabase": { "status": "connected", "latencyMs": 45 },
    "redis": { "status": "connected", "latencyMs": 2 }
  }
}
```

**Key fields:**
- `status`: `"healthy"` (all checks pass) or `"degraded"` (one or more checks failing)
- `services`: Boolean flags indicating whether API keys are configured (not whether services are reachable)
- `checks`: Live connectivity results with latency

### GET /health/live -- Liveness Probe

Confirms the Node.js process is running and responding to HTTP requests. Always returns 200 if the process is alive.

```bash
curl -s http://localhost:3000/health/live
# {"status":"ok"}
```

### GET /health/ready -- Readiness Probe

Deep checks against configured dependencies (Supabase, Redis). Returns 200 if all required services are connected, 503 if any required service is down.

```bash
curl -s http://localhost:3000/health/ready
# 200: {"status":"ready","checks":{...}}
# 503: {"status":"not_ready","checks":{...}}
```

**Note:** Redis is optional -- a disconnected Redis does not cause a 503. Only Supabase connectivity is required.

### Docker / Kubernetes Health Check Configuration

**Docker Compose:**
```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:3000/health/live"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 10s
```

**Kubernetes:**
```yaml
livenessProbe:
  httpGet:
    path: /health/live
    port: 3000
  initialDelaySeconds: 10
  periodSeconds: 30
  timeoutSeconds: 10

readinessProbe:
  httpGet:
    path: /health/ready
    port: 3000
  initialDelaySeconds: 5
  periodSeconds: 15
  timeoutSeconds: 10
```

## Metrics Endpoint

### GET /metrics -- Request Metrics Snapshot

Returns aggregate request metrics since the last server start. Not persisted across restarts.

```bash
curl -s http://localhost:3000/metrics | python3 -m json.tool
```

**Response:**
```json
{
  "uptime": 3600,
  "requests": {
    "total": 15240,
    "errors": 12,
    "errorRate": 0.08
  },
  "statusCodes": {
    "200": 14890,
    "401": 230,
    "404": 108,
    "500": 12
  },
  "responseTime": {
    "avg": 45.23,
    "p50": 32.10,
    "p95": 125.50,
    "p99": 350.00
  },
  "memory": {
    "rss": 78643200,
    "heapUsed": 45000000,
    "heapTotal": 67108864
  }
}
```

### Interpreting Metrics

| Metric | What It Means | Unit |
|--------|--------------|------|
| `requests.total` | Total requests since start | count |
| `requests.errors` | Requests that returned 5xx | count |
| `requests.errorRate` | Percentage of 5xx responses | % |
| `statusCodes` | Distribution of HTTP status codes | count per code |
| `responseTime.avg` | Mean response time | ms |
| `responseTime.p50` | Median response time | ms |
| `responseTime.p95` | 95th percentile response time | ms |
| `responseTime.p99` | 99th percentile response time | ms |
| `memory.rss` | Resident set size (total process memory) | bytes |
| `memory.heapUsed` | V8 heap memory in use | bytes |
| `memory.heapTotal` | V8 heap memory allocated | bytes |

**Implementation note:** Response times are stored in a ring buffer of 1,000 entries. Percentiles reflect the most recent 1,000 requests, not all-time.

### Alert Thresholds

| Metric | Warning | Critical | Action |
|--------|---------|----------|--------|
| `responseTime.p99` | > 500ms | > 1000ms | Check database latency, review recent deploys |
| `requests.errorRate` | > 0.5% | > 1% | Check Sentry, review error logs |
| `memory.heapUsed / heapTotal` | > 70% | > 80% | Monitor trend; restart if sustained above 80% |
| `uptime` | Unexpected reset | | Check for crashes in logs, OOM kills |

## Sentry Error Tracking

### Setup

Sentry is optional and gracefully degrades when not configured.

**Backend:** Set `SENTRY_DSN` environment variable.
**Frontend:** Set `NEXT_PUBLIC_SENTRY_DSN` environment variable.

When configured, Sentry initializes with:
- `environment`: matches `NODE_ENV`
- `release`: `"2.0.0"`
- `tracesSampleRate`: `0.1` (10% of transactions traced)
- Express integration for automatic request/error capture

### What Gets Captured

- Unhandled exceptions (process-level `uncaughtException`)
- Express error handler errors (4xx/5xx with stack traces)
- Request context: `requestId` (UUID), `userId` (UUID), HTTP `method`, `path`

### What Does NOT Get Captured (PII Protection)

- Request bodies (no form data, document content, or user input)
- Authorization headers or JWT tokens
- IP addresses
- User names, emails, or personal information
- Document contents or analysis results

This is enforced by the `addSentryContext()` function in `backend-express/utils/sentry.js`, which explicitly only passes non-PII identifiers.

### Triaging Sentry Alerts

1. **Check frequency** -- is this a one-off or a pattern?
2. **Check the requestId** -- search backend logs for that requestId to get full context
3. **Check the path** -- which endpoint is failing?
4. **Check the environment** -- production vs staging
5. **Check the release** -- did this start after a deploy?

## Log Analysis

### Winston Structured Logging

Backend uses Winston with environment-aware formatting:

- **Production:** JSON format (machine-parseable by log aggregators)
- **Development:** Colorized human-readable format

### Production Log Format (JSON)

```json
{
  "level": "info",
  "message": "Server started",
  "service": "server",
  "timestamp": "2026-04-07T12:00:00.000Z",
  "port": 3000,
  "env": "production"
}
```

### Key Log Fields

| Field | Description | Always Present |
|-------|-------------|----------------|
| `level` | Log level (error, warn, info, http, debug) | Yes |
| `message` | Human-readable description | Yes |
| `service` | Module name (server, plaid, claude, auth, sentry, env-validator) | Yes |
| `timestamp` | ISO 8601 timestamp | Yes (production) |
| `requestId` | UUID for request correlation | On request-scoped logs |
| `error` | Error message | On error logs |
| `stack` | Stack trace | On error logs |

### Request ID Tracing

Every request is assigned a unique UUID via the `requestId` middleware. This ID appears in:
- All log entries for that request (`requestId` field)
- Sentry error context
- Response headers (if configured)

To trace a specific request through logs:
```bash
docker logs mg-backend 2>&1 | grep "abc12345-6789-..."
```

### Log Levels

| Level | When Used | Examples |
|-------|-----------|---------|
| `error` | Unrecoverable failures | Uncaught exceptions, database connection failure, environment validation failure |
| `warn` | Recoverable issues, degraded state | Missing optional env vars, Sentry not configured, CORS wildcard in production |
| `info` | Normal operations | Server started, environment validated, Sentry initialized |
| `http` | HTTP request logs | Morgan combined format access logs |
| `debug` | Detailed diagnostic info | Available in development only (LOG_LEVEL controls this) |

**Default log level:** `info` in production, `debug` in development. Override with `LOG_LEVEL` env var.

## Key Metrics to Watch

### Response Time Trends

- **Gradual increase over days:** Possible memory leak, database index degradation, or growing dataset
- **Sudden spike after deploy:** New code path is slow -- consider rollback
- **Spike correlated with time of day:** Normal load patterns -- may need scaling

### Error Rate Patterns

- **Steady low rate (< 0.1%):** Normal -- occasional client errors
- **Spike after deploy:** Bug in new code -- check Sentry for details
- **Gradual increase:** Dependency degradation (database, external API)

### Memory Usage Patterns

- **Stable plateau:** Healthy -- GC is working properly
- **Sawtooth pattern:** Normal GC behavior (heap grows, GC reclaims, repeat)
- **Steady upward climb:** Memory leak -- restart and investigate. Check recent code changes for unclosed connections, growing arrays/maps, or event listener accumulation

### Health Check Failures

- **Supabase disconnected:** Database is down or paused. Check Supabase dashboard.
- **Redis disconnected:** Cache unavailable -- not critical, but rate limiting may degrade.
- **Status "degraded":** At least one required dependency is down. Check `/health/ready` for specifics.

---

**Related documentation:**
- [RUNBOOK.md](./RUNBOOK.md) -- Incident response procedures and playbooks
- [DEPLOY.md](./DEPLOY.md) -- Deployment procedures and rollback instructions
- [ENV-GUIDE.md](./ENV-GUIDE.md) -- Environment variable reference
- [SECURITY-AUDIT.md](./SECURITY-AUDIT.md) -- Security audit report and accepted risks
