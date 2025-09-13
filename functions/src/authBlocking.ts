import {beforeUserCreated} from "firebase-functions/v2/identity";
import {HttpsError} from "firebase-functions/v2/https";
import {logger} from "firebase-functions/v2";
import * as admin from "firebase-admin";
import {getRoleFromEmail, isValidSchoolEmail} from "./config/domainRoles";

const db = admin.firestore();

/**
 * Firebase Auth blocking function that runs before a user is created.
 * Automatically assigns roles based on email domain and creates user profile.
 */
export const autoAssignRole = beforeUserCreated(
  {region: "us-east4"},
  async (event) => {
    const user = event.data;

    if (!user) {
      logger.error("No user data in event");
      throw new HttpsError(
        "invalid-argument",
        "Invalid user data"
      );
    }

    const email = user.email;

    if (!email) {
      logger.warn("User creation attempt without email");
      throw new HttpsError(
        "invalid-argument",
        "Email is required for account creation"
      );
    }

    // Check if email is from a valid school domain
    if (!isValidSchoolEmail(email)) {
      logger.warn(`Invalid email domain attempt: ${email}`);
      
      // Provide clearer error message based on provider
      const provider = user.providerData?.[0]?.providerId;
      const errorMessage = provider === "google.com" 
        ? "Google Sign-In is only available for authorized school accounts. Please use an email ending in @roselleschools.org (teachers), @rosellestudent.org (students), or @fermi-plus.com (admins)."
        : "Registration is restricted to authorized school email addresses (@roselleschools.org for teachers, @rosellestudent.org for students, @fermi-plus.com for admins)";
      
      throw new HttpsError(
        "permission-denied",
        errorMessage
      );
    }

    // Get role based on email domain
    const role = getRoleFromEmail(email);

    if (!role) {
      logger.error(`Could not determine role for email: ${email}`);
      throw new HttpsError(
        "permission-denied",
        "Unable to determine user role from email address"
      );
    }

    logger.info(`Auto-assigning role ${role} to user with email ${email}`);

    // Set custom claims for the user
    const customClaims = {
      role: role,
      emailDomain: email.split("@")[1],
    };

    // Create user profile in Firestore
    try {
      await db.collection("users").doc(user.uid).set({
        email: email,
        displayName: user.displayName || email.split("@")[0],
        role: role,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        emailVerified: false,
        isEmailUser: true,
        profileComplete: false,
      });

      // Log the activity
      await db.collection("activities").add({
        type: "user_created",
        userName: user.displayName || email,
        userRole: role,
        createdBy: "system",
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        details: {
          userId: user.uid,
          email: email,
          autoAssigned: true,
        },
      });

      logger.info(`User profile created for ${user.uid} with role ${role}`);
    } catch (error) {
      logger.error("Error creating user profile:", error);
      throw new HttpsError(
        "internal",
        "Failed to create user profile"
      );
    }

    return {
      customClaims: customClaims,
      displayName: user.displayName || email.split("@")[0],
      emailVerified: role === "admin", // Auto-verify admin accounts
    };
  }
);

