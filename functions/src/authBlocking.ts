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
      throw new HttpsError(
        "permission-denied",
        "Registration is restricted to authorized school email addresses"
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
      emailDomain: email.split('@')[1],
    };

    // Create user profile in Firestore
    try {
      await db.collection("users").doc(user.uid).set({
        email: email,
        displayName: user.displayName || email.split('@')[0],
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
      displayName: user.displayName || email.split('@')[0],
      emailVerified: role === 'admin', // Auto-verify admin accounts
    };
  }
);

/**
 * Firebase Auth blocking function that runs before a user signs in.
 * Ensures user has proper role and profile.
 */
export const validateUserSignIn = beforeUserCreated(
  {region: "us-east4"},
  async (event) => {
    const user = event.data;
    
    if (!user) {
      logger.error("No user data in sign-in event");
      throw new HttpsError(
        "invalid-argument",
        "Invalid user data"
      );
    }
    
    // Check if user profile exists
    const userDoc = await db.collection("users").doc(user.uid).get();
    
    if (!userDoc.exists) {
      logger.error(`User ${user.uid} attempting to sign in without profile`);
      
      // Try to create profile if we can determine role from email
      if (user.email && isValidSchoolEmail(user.email)) {
        const role = getRoleFromEmail(user.email);
        if (role) {
          await db.collection("users").doc(user.uid).set({
            email: user.email,
            displayName: user.displayName || user.email.split('@')[0],
            role: role,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            emailVerified: user.emailVerified || false,
            isEmailUser: true,
            profileComplete: false,
          });
          
          return {
            customClaims: {
              role: role,
              emailDomain: user.email.split('@')[1],
            },
          };
        }
      }
      
      throw new HttpsError(
        "permission-denied",
        "User profile not found. Please contact administrator."
      );
    }
    
    const userData = userDoc.data();
    
    // Ensure custom claims are set
    return {
      customClaims: {
        role: userData?.role || 'student',
        emailDomain: user.email?.split('@')[1],
      },
    };
  }
);