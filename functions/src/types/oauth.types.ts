/**
 * Type definitions for OAuth implementation
 */

import * as admin from "firebase-admin";

/** Google OAuth token response */
export interface GoogleTokenResponse {
  access_token: string;
  expires_in: number;
  refresh_token?: string;
  scope: string;
  token_type: string;
  id_token?: string;
}

/** Google user info response */
export interface GoogleUserInfo {
  id: string;
  email: string;
  verified_email: boolean;
  name: string;
  given_name?: string;
  family_name?: string;
  picture?: string;
  locale?: string;
}

/** PKCE challenge data stored in Firestore */
export interface PKCEChallenge {
  codeVerifier: string;
  expiresAt: number;
  createdAt: admin.firestore.Timestamp | admin.firestore.FieldValue;
  clientId?: string;
}

/** OAuth URL generation request */
export interface OAuthUrlRequest {
  redirect_uri?: string;
}

/** OAuth code exchange request */
export interface OAuthCodeExchangeRequest {
  code: string;
  state: string;
  codeVerifier: string;
  redirectUri?: string;
}

/** OAuth token refresh request */
export interface OAuthTokenRefreshRequest {
  refreshToken: string;
}

/** OAuth URL generation response */
export interface OAuthUrlResponse {
  authUrl: string;
  state: string;
  codeVerifier: string;
}

/** OAuth token response */
export interface OAuthTokenResponse {
  firebaseToken: string;
  accessToken?: string;
  refreshToken?: string;
  expiresIn?: number;
  idToken?: string;
  user?: {
    uid: string;
    email: string;
    displayName?: string;
    photoURL?: string;
  };
}

/** OAuth error response */
export interface OAuthErrorResponse {
  error: string;
  error_description?: string;
}
