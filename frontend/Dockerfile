# Stage 1: Install dependencies
FROM node:20-alpine AS deps

WORKDIR /app

COPY package.json package-lock.json ./

RUN npm ci --legacy-peer-deps

# Stage 2: Build application
FROM node:20-alpine AS builder

WORKDIR /app

COPY --from=deps /app/node_modules ./node_modules
COPY . .

ARG NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY=pk_test_Y2ktcGxhY2Vob2xkZXItMDAuY2xlcmsuYWNjb3VudHMuZGV2JA==
ARG NEXT_PUBLIC_API_URL=http://localhost:3000
ARG NEXT_PUBLIC_APP_URL=http://localhost:3001
ARG NEXT_PUBLIC_APP_NAME="Mortgage Guardian"
ARG NEXT_PUBLIC_ENABLE_PLAID=false
ARG NEXT_PUBLIC_ENABLE_AI_ANALYSIS=false
ARG CLERK_SECRET_KEY=sk_test_Y2ktcGxhY2Vob2xkZXItMDAuY2xlcmsuYWNjb3VudHMuZGV2JA==

ENV NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY=$NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY
ENV NEXT_PUBLIC_API_URL=$NEXT_PUBLIC_API_URL
ENV NEXT_PUBLIC_APP_URL=$NEXT_PUBLIC_APP_URL
ENV NEXT_PUBLIC_APP_NAME=$NEXT_PUBLIC_APP_NAME
ENV NEXT_PUBLIC_ENABLE_PLAID=$NEXT_PUBLIC_ENABLE_PLAID
ENV NEXT_PUBLIC_ENABLE_AI_ANALYSIS=$NEXT_PUBLIC_ENABLE_AI_ANALYSIS
ENV CLERK_SECRET_KEY=$CLERK_SECRET_KEY

RUN npm run build

# Stage 3: Production runtime
FROM node:20-alpine

RUN addgroup -g 1001 -S appgroup && \
    adduser -S appuser -u 1001 -G appgroup

WORKDIR /app

COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static
COPY --from=builder /app/public ./public

ENV NODE_ENV=production
ENV HOSTNAME=0.0.0.0
ENV PORT=3001

EXPOSE 3001

USER appuser

CMD ["node", "server.js"]
