import * as admin from "firebase-admin";
import {onCall, HttpsError} from "firebase-functions/v2/https";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {defineSecret} from "firebase-functions/params";

// Define secrets
const cloudflareWorkerUrl = defineSecret("CLOUDFLARE_WORKER_URL");
const cloudflareApiKey = defineSecret("CLOUDFLARE_API_KEY");

// Initialize Firestore
const db = admin.firestore();

/**
 * Send email via Cloudflare Worker
 */
async function sendEmailViaCloudflare(
  to: string, 
  subject: string, 
  html: string, 
  text: string,
  workerUrl: string,
  apiKey: string
): Promise<void> {
  if (!workerUrl || !apiKey) {
    throw new Error("Cloudflare email configuration missing");
  }

  const response = await fetch(workerUrl, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Authorization": `Bearer ${apiKey}`,
    },
    body: JSON.stringify({ to, subject, html, text }),
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`Failed to send email: ${errorText}`);
  }
}

/**
 * Generates a random 6-digit verification code
 */
function generateVerificationCode(): string {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

/**
 * Check if email is already linked to another account
 */
async function isEmailAlreadyUsed(email: string): Promise<boolean> {
  const usersSnapshot = await db
    .collection("users")
    .where("realEmail", "==", email)
    .limit(1)
    .get();
  
  return !usersSnapshot.empty;
}

/**
 * Check rate limiting for email verification codes
 */
async function checkRateLimit(email: string): Promise<boolean> {
  const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000);
  
  const recentCodes = await db
    .collection("email_verifications")
    .where("email", "==", email)
    .where("createdAt", ">", oneHourAgo)
    .get();
  
  return recentCodes.size < 3; // Max 3 codes per hour
}

/**
 * Send verification code to email
 */
export const sendEmailVerificationCode = onCall(
  {
    secrets: [cloudflareWorkerUrl, cloudflareApiKey],
  },
  async (request) => {
  // Verify user is authenticated
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "User must be authenticated");
  }

  const {email} = request.data;
  const userId = request.auth.uid;

  // Validate email format
  const emailRegex = /^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$/;
  if (!email || !emailRegex.test(email)) {
    throw new HttpsError("invalid-argument", "Invalid email address format");
  }

  // Check if email is already linked to another account
  const emailInUse = await isEmailAlreadyUsed(email);
  if (emailInUse) {
    throw new HttpsError(
      "already-exists",
      "This email is already linked to another account"
    );
  }

  // Check rate limiting
  const withinRateLimit = await checkRateLimit(email);
  if (!withinRateLimit) {
    throw new HttpsError(
      "resource-exhausted",
      "Too many verification attempts. Please try again in an hour."
    );
  }

  // Mark any existing codes for this user as expired
  const existingCodes = await db
    .collection("email_verifications")
    .where("userId", "==", userId)
    .where("verified", "==", false)
    .get();

  const batch = db.batch();
  existingCodes.forEach((doc) => {
    batch.update(doc.ref, {expired: true});
  });
  await batch.commit();

  // Generate verification code
  const code = generateVerificationCode();
  const now = new Date();
  const expiresAt = new Date(now.getTime() + 15 * 60 * 1000); // 15 minutes

  // Store verification record
  const verificationRef = db.collection("email_verifications").doc();
  await verificationRef.set({
    userId,
    email,
    code,
    createdAt: now,
    expiresAt,
    attempts: 0,
    verified: false,
    expired: false,
  });

  // Send email via Cloudflare Worker
  try {
    const html = `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <h2 style="color: #2563eb;">Verify Your Email</h2>
        <p>You requested to link this email address to your Fermi Education Platform account.</p>
        <div style="background-color: #f3f4f6; padding: 20px; border-radius: 8px; margin: 20px 0;">
          <p style="margin: 0; font-size: 14px; color: #6b7280;">Your verification code is:</p>
          <h1 style="margin: 10px 0; font-size: 32px; letter-spacing: 8px; color: #111827;">${code}</h1>
        </div>
        <p style="color: #6b7280;">This code will expire in 15 minutes.</p>
        <p style="color: #6b7280;">If you didn't request this verification, please ignore this email.</p>
      </div>
    `;
    
    const text = `Your Fermi Education Platform verification code is: ${code}\n\nThis code will expire in 15 minutes.\n\nIf you didn't request this verification, please ignore this email.`;

    await sendEmailViaCloudflare(
      email,
      "Verify Your Email - Fermi Education Platform",
      html,
      text,
      cloudflareWorkerUrl.value(),
      cloudflareApiKey.value()
    );

    return {
      success: true,
      verificationId: verificationRef.id,
      expiresAt: expiresAt.toISOString(),
    };
  } catch (error) {
    console.error("Error sending email:", error);
    throw new HttpsError("internal", "Failed to send verification email");
  }
});

/**
 * Verify the code entered by the user
 */
export const verifyEmailCode = onCall(async (request) => {
  // Verify user is authenticated
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "User must be authenticated");
  }

  const {verificationId, code} = request.data;
  const userId = request.auth.uid;

  if (!verificationId || !code) {
    throw new HttpsError("invalid-argument", "Missing verification ID or code");
  }

  // Get verification record
  const verificationDoc = await db
    .collection("email_verifications")
    .doc(verificationId)
    .get();

  if (!verificationDoc.exists) {
    throw new HttpsError("not-found", "Verification record not found");
  }

  const verification = verificationDoc.data()!;

  // Check if verification belongs to user
  if (verification.userId !== userId) {
    throw new HttpsError("permission-denied", "Invalid verification record");
  }

  // Check if already verified
  if (verification.verified) {
    throw new HttpsError("failed-precondition", "Code already used");
  }

  // Check if expired
  if (verification.expired || new Date() > verification.expiresAt.toDate()) {
    throw new HttpsError("deadline-exceeded", "Verification code has expired");
  }

  // Check attempts
  if (verification.attempts >= 3) {
    throw new HttpsError(
      "resource-exhausted",
      "Too many failed attempts. Please request a new code."
    );
  }

  // Verify code
  if (verification.code !== code) {
    // Update attempts
    await verificationDoc.ref.update({
      attempts: verification.attempts + 1,
    });

    const remainingAttempts = 2 - verification.attempts;
    throw new HttpsError(
      "invalid-argument",
      `Invalid verification code. ${remainingAttempts} ${
        remainingAttempts === 1 ? "attempt" : "attempts"
      } remaining.`
    );
  }

  // Code is correct - update user's realEmail
  const batch = db.batch();
  
  // Mark verification as used
  batch.update(verificationDoc.ref, {
    verified: true,
    usedAt: new Date(),
  });

  // Update user's realEmail
  const userRef = db.collection("users").doc(userId);
  batch.update(userRef, {
    realEmail: verification.email,
    hasLinkedEmail: true,
    emailLinkedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  await batch.commit();

  return {
    success: true,
    email: verification.email,
  };
});

/**
 * Scheduled function to clean up expired verification codes
 */
export const cleanupExpiredVerifications = onSchedule({
  schedule: "every 24 hours",
  region: "us-east4",
}, async (event) => {
  const oneDayAgo = new Date(Date.now() - 24 * 60 * 60 * 1000);

  const expiredDocs = await db
    .collection("email_verifications")
    .where("createdAt", "<", oneDayAgo)
    .get();

  const batch = db.batch();
  let count = 0;

  expiredDocs.forEach((doc) => {
    batch.delete(doc.ref);
    count++;
  });

  if (count > 0) {
    await batch.commit();
    console.log(`Deleted ${count} expired verification records`);
  }
});