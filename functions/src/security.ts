import * as admin from "firebase-admin";
import {HttpsError} from "firebase-functions/v2/https";
import {FirebaseFunctionsRateLimiter} from "firebase-functions-rate-limiter";
import {Request, Response} from "express";

// Initialize rate limiter with Firestore backend
// This uses Firestore to track rate limiting across all function instances
export const createRateLimiter = (
  name: string,
  maxCalls: number,
  periodSeconds: number
): FirebaseFunctionsRateLimiter => {
  const limiter = FirebaseFunctionsRateLimiter.withFirestoreBackend(
    {
      name,
      maxCalls,
      periodSeconds,
    },
    admin.firestore()
  );

  return limiter;
};

// OAuth endpoint rate limiters with different limits for different security levels
export const oauthRateLimiters = {
  // Getting OAuth URL - less sensitive, allow more calls
  getUrl: createRateLimiter("oauth_get_url", 10, 60), // 10 calls per minute per IP

  // Exchanging code - more sensitive, stricter limit
  exchangeCode: createRateLimiter("oauth_exchange", 5, 60), // 5 calls per minute per IP

  // Refreshing token - moderate sensitivity
  refreshToken: createRateLimiter("oauth_refresh", 20, 60), // 20 calls per minute per IP
};

// Apply rate limiting to a request
export const applyRateLimit = async (
  limiter: FirebaseFunctionsRateLimiter,
  identifier: string
) => {
  try {
    // Use the correct method from FirebaseFunctionsRateLimiter
    await limiter.rejectOnQuotaExceededOrRecordUsage(identifier);
  } catch (error) {
    throw new HttpsError(
      "resource-exhausted",
      "Too many requests. Please try again later."
    );
  }
};

// Request validation for desktop OAuth (App Check alternative)
// Since App Check doesn't support desktop, we implement custom validation
export interface OAuthRequestValidation {
  // Check if the request has valid headers and structure
  validateRequest(req: Request): boolean;

  // Check if the redirect URI is allowed
  validateRedirectUri(uri: string): boolean;

  // Validate state parameter format
  validateState(state: string): boolean;

  // Validate code verifier for PKCE
  validateCodeVerifier(verifier: string): boolean;
}

export const oauthValidator: OAuthRequestValidation = {
  validateRequest(req: Request): boolean {
    // Check for basic request structure
    if (!req || typeof req !== "object") {
      return false;
    }

    // Check for user agent (desktop apps should have one)
    const userAgent = req.headers?.["user-agent"];
    if (!userAgent || typeof userAgent !== "string") {
      return false;
    }

    // Block obvious bot patterns
    const botPatterns = [
      /bot/i,
      /crawler/i,
      /spider/i,
      /scraper/i,
      /curl/i,
      /wget/i,
      /python-requests/i,
    ];

    for (const pattern of botPatterns) {
      if (pattern.test(userAgent)) {
        return false;
      }
    }

    return true;
  },

  validateRedirectUri(uri: string): boolean {
    if (!uri || typeof uri !== "string") {
      return false;
    }

    // Only allow localhost redirects for desktop OAuth
    // This ensures the request is coming from a local desktop app
    try {
      const url = new URL(uri);

      // Must be localhost or 127.0.0.1
      if (url.hostname !== "localhost" && url.hostname !== "127.0.0.1") {
        return false;
      }

      // Must be http (not https) for localhost
      if (url.protocol !== "http:") {
        return false;
      }

      // Port must be in valid range (1024-65535 for non-privileged)
      const port = parseInt(url.port || "80");
      if (port < 1024 || port > 65535) {
        return false;
      }

      return true;
    } catch {
      return false;
    }
  },

  validateState(state: string): boolean {
    if (!state || typeof state !== "string") {
      return false;
    }

    // State should be base64url encoded and reasonable length
    // PKCE state should be 32 bytes encoded as base64url = ~43 chars
    if (state.length < 40 || state.length > 50) {
      return false;
    }

    // Check if it's valid base64url
    const base64urlPattern = /^[A-Za-z0-9_-]+$/;
    return base64urlPattern.test(state);
  },

  validateCodeVerifier(verifier: string): boolean {
    if (!verifier || typeof verifier !== "string") {
      return false;
    }

    // Code verifier should be 32 bytes encoded as base64url = ~43 chars
    if (verifier.length < 40 || verifier.length > 50) {
      return false;
    }

    // Check if it's valid base64url
    const base64urlPattern = /^[A-Za-z0-9_-]+$/;
    return base64urlPattern.test(verifier);
  },
};

// Security headers to add to responses
export const securityHeaders = {
  "X-Content-Type-Options": "nosniff",
  "X-Frame-Options": "DENY",
  "X-XSS-Protection": "1; mode=block",
  "Referrer-Policy": "no-referrer",
  "Cache-Control": "no-store, no-cache, must-revalidate",
  "Pragma": "no-cache",
};

// Apply security headers to response
export const applySecurityHeaders = (res: Response) => {
  Object.entries(securityHeaders).forEach(([key, value]) => {
    res.set(key, value);
  });
};

// Get client identifier for rate limiting (IP address)
export const getClientIdentifier = (req: Request): string => {
  // Try various headers that might contain the real IP
  const xForwardedFor = req.headers["x-forwarded-for"];
  const xRealIp = req.headers["x-real-ip"];
  
  // Handle both string and string[] types for headers
  const ip =
    (typeof xForwardedFor === "string" ? xForwardedFor.split(",")[0] : xForwardedFor?.[0]) ||
    (typeof xRealIp === "string" ? xRealIp : xRealIp?.[0]) ||
    req.connection?.remoteAddress ||
    req.ip ||
    "unknown";

  return String(ip);
};
