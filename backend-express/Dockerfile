# Stage 1: Install production dependencies
FROM node:20-alpine AS deps

WORKDIR /app

COPY package.json package-lock.json ./

RUN npm ci --omit=dev

# Stage 2: Production runtime
FROM node:20-alpine

RUN addgroup -g 1001 -S appgroup && \
    adduser -S appuser -u 1001 -G appgroup

WORKDIR /app

COPY --from=deps /app/node_modules ./node_modules

COPY server.js ./
COPY routes/ ./routes/
COPY services/ ./services/
COPY middleware/ ./middleware/
COPY schemas/ ./schemas/
COPY utils/ ./utils/
COPY config/ ./config/
COPY migrations/ ./migrations/
COPY api/ ./api/
COPY package.json ./

ENV NODE_ENV=production

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3000/health || exit 1

USER appuser

CMD ["node", "server.js"]
