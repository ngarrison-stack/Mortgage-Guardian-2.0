/**
 * Vendor-Neutral Security — Session Managers
 * In-memory and Redis-backed session storage.
 */

const crypto = require('crypto');
const Redis = require('ioredis');

/**
 * In-memory session storage (single instance)
 */
class InMemorySessionManager {
    constructor() {
        this.sessions = new Map();
        this.cleanupInterval = setInterval(() => this.cleanup(), 60000);
    }

    async createSession(userId, metadata = {}) {
        const sessionId = crypto.randomBytes(32).toString('hex');
        const session = {
            id: sessionId,
            userId,
            createdAt: Date.now(),
            lastActivity: Date.now(),
            metadata
        };

        this.sessions.set(sessionId, session);
        return sessionId;
    }

    async getSession(sessionId) {
        const session = this.sessions.get(sessionId);
        if (session) {
            session.lastActivity = Date.now();
            return session;
        }
        return null;
    }

    async deleteSession(sessionId) {
        this.sessions.delete(sessionId);
    }

    cleanup() {
        const now = Date.now();
        const timeout = 15 * 60 * 1000;

        for (const [sessionId, session] of this.sessions) {
            if (now - session.lastActivity > timeout) {
                this.sessions.delete(sessionId);
            }
        }
    }

    destroy() {
        clearInterval(this.cleanupInterval);
        this.sessions.clear();
    }
}

/**
 * Redis session storage (distributed)
 */
class RedisSessionManager {
    constructor(config) {
        this.redis = new Redis({
            host: config.redisHost,
            port: config.redisPort || 6379,
            password: config.redisPassword
        });
    }

    async createSession(userId, metadata = {}) {
        const sessionId = crypto.randomBytes(32).toString('hex');
        const session = {
            id: sessionId,
            userId,
            createdAt: Date.now(),
            lastActivity: Date.now(),
            metadata
        };

        await this.redis.setex(
            `session:${sessionId}`,
            900,
            JSON.stringify(session)
        );

        return sessionId;
    }

    async getSession(sessionId) {
        const data = await this.redis.get(`session:${sessionId}`);
        if (data) {
            const session = JSON.parse(data);
            session.lastActivity = Date.now();

            await this.redis.setex(
                `session:${sessionId}`,
                900,
                JSON.stringify(session)
            );

            return session;
        }
        return null;
    }

    async deleteSession(sessionId) {
        await this.redis.del(`session:${sessionId}`);
    }
}

module.exports = { InMemorySessionManager, RedisSessionManager };
