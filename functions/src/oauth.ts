import {onRequest, HttpsError} from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import * as crypto from "crypto";
import {
  oauthRateLimiters,
  applyRateLimit,
  oauthValidator,
  applySecurityHeaders,
  getClientIdentifier,
} from "./security";

// OAuth configuration - using environment variables
// For local development: create functions/.env file with GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET
// For production: set these in Firebase Console > Functions > Environment Variables
const GOOGLE_CLIENT_ID = process.env.GOOGLE_CLIENT_ID;
const GOOGLE_CLIENT_SECRET = process.env.GOOGLE_CLIENT_SECRET;
const GOOGLE_AUTH_URL = "https://accounts.google.com/o/oauth2/v2/auth";
const GOOGLE_TOKEN_URL = "https://oauth2.googleapis.com/token";
const GOOGLE_USERINFO_URL = "https://www.googleapis.com/oauth2/v2/userinfo";

// Use Firestore for PKCE challenge storage (stateless function-safe)
const getPKCECollection = () => admin.firestore().collection("oauth_pkce_challenges");

/**
 * Generate OAuth URL for desktop clients using PKCE
 * Desktop clients call this to get the authorization URL
 */
export const getOAuthUrl = onRequest(
  {cors: true},
  async (req, res) => {
    try {
      // Apply security headers
      applySecurityHeaders(res);

      // Apply rate limiting
      const clientId = getClientIdentifier(req);
      await applyRateLimit(oauthRateLimiters.getUrl, clientId);

      // Validate request structure
      if (!oauthValidator.validateRequest(req)) {
        throw new HttpsError("invalid-argument", "Invalid request format");
      }

      // Get redirect URI from request
      const redirectUri = req.query.redirect_uri as string || "http://localhost";

      // Validate redirect URI
      if (!oauthValidator.validateRedirectUri(redirectUri)) {
        throw new HttpsError(
          "invalid-argument",
          "Invalid redirect URI. Only localhost is allowed for desktop OAuth."
        );
      }

      // Generate state for CSRF protection
      const state = crypto.randomBytes(32).toString("base64url");

      // Generate PKCE challenge
      const codeVerifier = crypto.randomBytes(32).toString("base64url");
      const codeChallenge = crypto
        .createHash("sha256")
        .update(codeVerifier)
        .digest("base64url");

      // Store the verifier with the state in Firestore (expires in 10 minutes)
      await getPKCECollection().doc(state).set({
        codeVerifier: codeVerifier,
        expiresAt: Date.now() + 600000,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        clientId: clientId, // Store client ID for rate limiting tracking
      });

      // Build authorization URL
      const params = new URLSearchParams({
        client_id: GOOGLE_CLIENT_ID!,
        redirect_uri: redirectUri,
        response_type: "code",
        scope: "email profile openid",
        state: state,
        code_challenge: codeChallenge,
        code_challenge_method: "S256",
        access_type: "offline",
        prompt: "consent",
      });

      const authUrl = `${GOOGLE_AUTH_URL}?${params.toString()}`;

      res.json({
        authUrl,
        state,
        codeVerifier, // Client needs to save this for token exchange
      });
    } catch (error) {
      console.error("Error generating OAuth URL:", error);

      // Handle different error types
      if (error instanceof HttpsError) {
        res.status(error.httpErrorCode.status || 400).json({
          error: error.message,
        });
      } else {
        res.status(500).json({error: "Failed to generate OAuth URL"});
      }
    }
  }
);

/**
 * Exchange authorization code for tokens
 * Desktop clients call this after user authorizes
 */
export const exchangeOAuthCode = onRequest(
  {cors: true},
  async (req, res) => {
    try {
      // Apply security headers
      applySecurityHeaders(res);

      // Apply rate limiting (stricter for code exchange)
      const clientId = getClientIdentifier(req);
      await applyRateLimit(oauthRateLimiters.exchangeCode, clientId);

      // Validate request structure
      if (!oauthValidator.validateRequest(req)) {
        throw new HttpsError("invalid-argument", "Invalid request format");
      }

      const {code, state, codeVerifier, redirectUri} = req.body;

      if (!code || !state || !codeVerifier) {
        throw new HttpsError("invalid-argument", "Missing required parameters");
      }

      // Validate state and code verifier formats
      if (!oauthValidator.validateState(state)) {
        throw new HttpsError("invalid-argument", "Invalid state format");
      }

      if (!oauthValidator.validateCodeVerifier(codeVerifier)) {
        throw new HttpsError("invalid-argument", "Invalid code verifier format");
      }

      // Validate redirect URI if provided
      if (redirectUri && !oauthValidator.validateRedirectUri(redirectUri)) {
        throw new HttpsError("invalid-argument", "Invalid redirect URI");
      }

      // Verify PKCE challenge from Firestore
      const stateDoc = await getPKCECollection().doc(state).get();
      if (!stateDoc.exists) {
        throw new HttpsError("invalid-argument", "Invalid state parameter");
      }

      const storedData = stateDoc.data()!;
      if (storedData.expiresAt < Date.now()) {
        await getPKCECollection().doc(state).delete();
        throw new HttpsError("deadline-exceeded", "State expired");
      }

      if (storedData.codeVerifier !== codeVerifier) {
        // Log potential security issue
        console.warn(`Invalid code verifier attempt from ${clientId}`);
        throw new HttpsError("invalid-argument", "Invalid code verifier");
      }

      // Clean up used challenge immediately
      await getPKCECollection().doc(state).delete();

      // Exchange code for tokens using the client secret server-side
      const tokenResponse = await fetch(GOOGLE_TOKEN_URL, {
        method: "POST",
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
        },
        body: new URLSearchParams({
          code,
          client_id: GOOGLE_CLIENT_ID!,
          client_secret: GOOGLE_CLIENT_SECRET!, // Secret stays server-side
          redirect_uri: redirectUri || "http://localhost",
          grant_type: "authorization_code",
          code_verifier: codeVerifier,
        }),
      });

      const tokenData = await tokenResponse.json();

      if (!tokenResponse.ok) {
        console.error("Token exchange failed:", tokenData);
        res.status(400).json({
          error: "Failed to exchange authorization code",
          details: tokenData,
        });
        return;
      }

      // Get user info
      const userResponse = await fetch(GOOGLE_USERINFO_URL, {
        headers: {
          Authorization: `Bearer ${tokenData.access_token}`,
        },
      });

      const userInfo = await userResponse.json();

      if (!userResponse.ok) {
        console.error("Failed to get user info:", userInfo);
        res.status(400).json({
          error: "Failed to get user information",
          details: userInfo,
        });
        return;
      }

      // Create or update Firebase user
      let firebaseUser;
      try {
        // Try to get existing user
        firebaseUser = await admin.auth().getUserByEmail(userInfo.email);
      } catch (error) {
        // User doesn't exist, create new one
        firebaseUser = await admin.auth().createUser({
          email: userInfo.email,
          displayName: userInfo.name,
          photoURL: userInfo.picture,
          emailVerified: userInfo.email_verified,
        });
      }

      // Create custom token for the user
      const customToken = await admin.auth().createCustomToken(firebaseUser.uid, {
        provider: "google.com",
        email: userInfo.email,
      });

      // Return tokens to desktop client
      res.json({
        firebaseToken: customToken,
        googleTokens: {
          accessToken: tokenData.access_token,
          refreshToken: tokenData.refresh_token,
          expiresIn: tokenData.expires_in,
          idToken: tokenData.id_token,
        },
        user: {
          uid: firebaseUser.uid,
          email: userInfo.email,
          displayName: userInfo.name,
          photoURL: userInfo.picture,
        },
      });
    } catch (error) {
      console.error("Error exchanging OAuth code:", error);

      // Handle different error types
      if (error instanceof HttpsError) {
        res.status(error.httpErrorCode.status || 400).json({
          error: error.message,
        });
      } else {
        res.status(500).json({error: "Failed to complete OAuth flow"});
      }
    }
  }
);

/**
 * Refresh access token using refresh token
 */
export const refreshOAuthToken = onRequest(
  {cors: true},
  async (req, res) => {
    try {
      // Apply security headers
      applySecurityHeaders(res);

      // Apply rate limiting
      const clientId = getClientIdentifier(req);
      await applyRateLimit(oauthRateLimiters.refreshToken, clientId);

      // Validate request structure
      if (!oauthValidator.validateRequest(req)) {
        throw new HttpsError("invalid-argument", "Invalid request format");
      }

      const {refreshToken} = req.body;

      if (!refreshToken) {
        throw new HttpsError("invalid-argument", "Missing refresh token");
      }

      // Exchange refresh token for new access token
      const tokenResponse = await fetch(GOOGLE_TOKEN_URL, {
        method: "POST",
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
        },
        body: new URLSearchParams({
          refresh_token: refreshToken,
          client_id: GOOGLE_CLIENT_ID!,
          client_secret: GOOGLE_CLIENT_SECRET!, // Secret stays server-side
          grant_type: "refresh_token",
        }),
      });

      const tokenData = await tokenResponse.json();

      if (!tokenResponse.ok) {
        console.error("Token refresh failed:", tokenData);
        res.status(400).json({
          error: "Failed to refresh token",
          details: tokenData,
        });
        return;
      }

      res.json({
        accessToken: tokenData.access_token,
        expiresIn: tokenData.expires_in,
        idToken: tokenData.id_token,
      });
    } catch (error) {
      console.error("Error refreshing token:", error);

      // Handle different error types
      if (error instanceof HttpsError) {
        res.status(error.httpErrorCode.status || 400).json({
          error: error.message,
        });
      } else {
        res.status(500).json({error: "Failed to refresh token"});
      }
    }
  }
);
