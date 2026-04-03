/**
 * Frontend Environment Validation
 *
 * Validates environment variables at import time and exports a typed
 * configuration object for use throughout the app.
 *
 * No external dependencies — uses simple runtime checks since Zod is
 * not in the frontend dependency tree.
 *
 * In CI builds, Clerk keys use synthetic format-valid values
 * (per Phase 23-02 decision). Validation checks format, not that
 * keys are real.
 */

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

class EnvValidationError extends Error {
  constructor(errors: string[]) {
    super(
      `Frontend environment validation failed:\n  - ${errors.join('\n  - ')}`
    );
    this.name = 'EnvValidationError';
  }
}

function requireEnv(name: string, value: string | undefined): string {
  if (!value || value.trim() === '') {
    throw new EnvValidationError([`${name} is required but was not provided`]);
  }
  return value.trim();
}

function isValidUrl(value: string): boolean {
  try {
    new URL(value);
    return true;
  } catch {
    return false;
  }
}

// ---------------------------------------------------------------------------
// Validation
// ---------------------------------------------------------------------------

function validateEnv() {
  const errors: string[] = [];

  // -- Required: Clerk keys ------------------------------------------------
  const clerkPublishableKey =
    process.env.NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY?.trim() ?? '';
  if (!clerkPublishableKey) {
    errors.push(
      'NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY is required (Clerk publishable key)'
    );
  } else if (!clerkPublishableKey.startsWith('pk_')) {
    errors.push(
      'NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY must start with "pk_"'
    );
  }

  const clerkSecretKey = process.env.CLERK_SECRET_KEY?.trim() ?? '';
  if (!clerkSecretKey) {
    errors.push('CLERK_SECRET_KEY is required (Clerk secret key)');
  } else if (!clerkSecretKey.startsWith('sk_')) {
    errors.push('CLERK_SECRET_KEY must start with "sk_"');
  }

  // -- Required: API URL ---------------------------------------------------
  const apiUrl = process.env.NEXT_PUBLIC_API_URL?.trim() ?? '';
  if (!apiUrl) {
    errors.push('NEXT_PUBLIC_API_URL is required (backend API base URL)');
  } else if (!isValidUrl(apiUrl)) {
    errors.push('NEXT_PUBLIC_API_URL must be a valid URL');
  }

  // -- Bail on errors ------------------------------------------------------
  if (errors.length > 0) {
    throw new EnvValidationError(errors);
  }

  // -- Optional with defaults ----------------------------------------------
  const appUrl =
    process.env.NEXT_PUBLIC_APP_URL?.trim() || 'http://localhost:3001';
  const appName =
    process.env.NEXT_PUBLIC_APP_NAME?.trim() || 'Mortgage Guardian';

  // -- Feature flags (string booleans) -------------------------------------
  const enablePlaid =
    (process.env.NEXT_PUBLIC_ENABLE_PLAID?.trim() || 'false') === 'true';
  const enableAiAnalysis =
    (process.env.NEXT_PUBLIC_ENABLE_AI_ANALYSIS?.trim() || 'false') === 'true';

  return Object.freeze({
    // Clerk
    clerkPublishableKey,
    clerkSecretKey,

    // API
    apiUrl,

    // App
    appUrl,
    appName,

    // Feature flags
    enablePlaid,
    enableAiAnalysis,
  });
}

// ---------------------------------------------------------------------------
// Typed config export (singleton, validated on first import)
// ---------------------------------------------------------------------------

export type FrontendEnvConfig = ReturnType<typeof validateEnv>;

/**
 * Validated, frozen environment configuration.
 *
 * Importing this module triggers validation immediately. If any required
 * variable is missing or malformed the build / server start will fail
 * with a descriptive error.
 */
export const env: FrontendEnvConfig = validateEnv();
