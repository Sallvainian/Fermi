import {onCall, HttpsError} from "firebase-functions/v2/https";
import {logger} from "firebase-functions/v2";
import * as admin from "firebase-admin";
import * as crypto from "crypto";

const db = admin.firestore();
const auth = admin.auth();

/**
 * Generate a cryptographically secure password
 * @param {number} length - The length of the password to generate
 * @return {string} A cryptographically secure password
 */
function generateSecurePassword(length: number = 12): string {
  const charset = 
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*";
  let password = "";

  let i = 0;
  while (i < length) {
    const byte = crypto.randomBytes(1)[0];
    // Accept only values that can be mapped uniformly to charset
    if (byte < Math.floor(256 / charset.length) * charset.length) {
      password += charset[byte % charset.length];
      i++;
    }
  }

  // Ensure password has at least one of each type
  const hasUpper = /[A-Z]/.test(password);
  const hasLower = /[a-z]/.test(password);
  const hasNumber = /[0-9]/.test(password);
  const hasSpecial = /[!@#$%^&*]/.test(password);

  if (!hasUpper || !hasLower || !hasNumber || !hasSpecial) {
    // Recursively generate until we get a password with all character types
    return generateSecurePassword(length);
  }

  return password;
}

/**
 * Create a new student account without email verification
 * Admin-only function
 */
export const createStudentAccount = onCall(
  {region: "us-east4", maxInstances: 10},
  async (request) => {
    // 1. Authentication check
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Authentication required");
    }

    // 2. Authorization check - must be admin
    const userDoc = await db.collection("users").doc(request.auth.uid).get();
    const userData = userDoc.data();

    if (userData?.role !== "admin") {
      throw new HttpsError("permission-denied", "Administrator access required");
    }

    // 3. Input validation
    const {email, password, displayName, gradeLevel, parentEmail, classIds, isGoogleAuth} = request.data;

    if (!email) {
      throw new HttpsError("invalid-argument", "Email is required");
    }

    if (!email.includes("@")) {
      throw new HttpsError("invalid-argument", "Invalid email address");
    }

    // ENFORCE DOMAIN VALIDATION FOR STUDENTS
    if (!email.toLowerCase().endsWith("@rosellestudent.org") &&
        !email.toLowerCase().endsWith("@rosellestudent.com")) {
      throw new HttpsError(
        "invalid-argument",
        "Student accounts must use @rosellestudent.org or @rosellestudent.com email addresses"
      );
    }

    // For Google OAuth accounts, we don't need a password
    if (!isGoogleAuth) {
      if (!password) {
        throw new HttpsError("invalid-argument", "Password is required for non-Google accounts");
      }
      if (password.length < 6) {
        throw new HttpsError("invalid-argument", "Password must be at least 6 characters");
      }
    }

    try {
      const emailValidated = email.toLowerCase();
      let userRecord;

      if (isGoogleAuth) {
        // For Google OAuth accounts, just create the Firestore document
        // The actual Firebase Auth account will be created when they first sign in with Google
        
        // Check if user already exists
        const existingUser = await auth.getUserByEmail(emailValidated).catch(() => null);
        
        if (existingUser) {
          // User already exists in Firebase Auth (likely from Google sign-in)
          userRecord = existingUser;
        } else {
          // Create a placeholder user that will be linked when they sign in with Google
          // We create without password for Google OAuth users
          userRecord = await auth.createUser({
            email: emailValidated,
            displayName: displayName || emailValidated.split("@")[0],
            emailVerified: true, // Mark as verified since admin created it
          });
        }
      } else {
        // Create regular email/password account
        userRecord = await auth.createUser({
          email: emailValidated,
          password: password,
          displayName: displayName || emailValidated.split("@")[0],
          emailVerified: true, // Mark as verified since admin created it
        });
      }

      // Set custom claims for role
      await auth.setCustomUserClaims(userRecord.uid, {
        role: "student",
      });

      // Create user document in Firestore
      await db.collection("users").doc(userRecord.uid).set({
        email: emailValidated,
        displayName: displayName || emailValidated.split("@")[0],
        role: "student",
        gradeLevel: gradeLevel || null,
        parentEmail: parentEmail || null,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        createdBy: request.auth.uid,
        isEmailUser: !isGoogleAuth, // true for email/password, false for Google OAuth
        isGoogleAuth: isGoogleAuth || false,
      });

      // Add to classes if provided
      if (classIds && Array.isArray(classIds) && classIds.length > 0) {
        const batch = db.batch();
        
        for (const classId of classIds) {
          const classRef = db.collection("classes").doc(classId);
          batch.update(classRef, {
            studentIds: admin.firestore.FieldValue.arrayUnion(userRecord.uid),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }
        
        await batch.commit();
      }

      // Log the activity
      await db.collection("activities").add({
        type: "user_created",
        userName: displayName || emailValidated.split("@")[0],
        userRole: "student",
        createdBy: request.auth.uid,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        details: {
          userId: userRecord.uid,
          email: emailValidated,
          gradeLevel: gradeLevel || null,
          isGoogleAuth: isGoogleAuth || false,
        },
      });

      logger.info(`Student account created: ${userRecord.uid} by admin ${request.auth.uid}, isGoogleAuth: ${isGoogleAuth}`);

      return {
        success: true,
        userId: userRecord.uid,
        email: emailValidated,
        displayName: displayName || emailValidated.split("@")[0],
        isGoogleAuth: isGoogleAuth || false,
      };
    } catch (error) {
      logger.error("Error creating student account:", error);

      if ((error as any).code === "auth/email-already-exists") {
        throw new HttpsError("already-exists", "Email already in use");
      }

      throw new HttpsError("internal", "Failed to create student account");
    }
  }
);

/**
 * Create a new teacher account
 * Admin-only function
 */
export const createTeacherAccount = onCall(
  {region: "us-east4", maxInstances: 10},
  async (request) => {
    // 1. Authentication check
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Authentication required");
    }

    // 2. Authorization check - must be admin
    const userDoc = await db.collection("users").doc(request.auth.uid).get();
    const userData = userDoc.data();

    if (userData?.role !== "admin") {
      throw new HttpsError("permission-denied", "Administrator access required");
    }

    // 3. Input validation
    const {email, password, displayName} = request.data;

    if (!email || !password || !displayName) {
      throw new HttpsError("invalid-argument", "Email, password, and display name are required");
    }

    if (!email.includes("@")) {
      throw new HttpsError("invalid-argument", "Invalid email address");
    }

    // ENFORCE DOMAIN VALIDATION FOR TEACHERS
    if (!email.toLowerCase().endsWith("@roselleschools.org")) {
      throw new HttpsError(
        "invalid-argument",
        "Teacher accounts must use @roselleschools.org email addresses"
      );
    }

    if (password.length < 6) {
      throw new HttpsError("invalid-argument", "Password must be at least 6 characters");
    }

    try {
      // Create the user account in Firebase Auth
      const userRecord = await auth.createUser({
        email: email,
        password: password,
        displayName: displayName,
        emailVerified: true, // Mark as verified since admin created it
      });

      // Set custom claims for role
      await auth.setCustomUserClaims(userRecord.uid, {
        role: "teacher",
      });

      // Create user document in Firestore
      await db.collection("users").doc(userRecord.uid).set({
        email: email,
        displayName: displayName,
        role: "teacher",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        createdBy: request.auth.uid,
        isEmailUser: true,
      });

      // Log the activity
      await db.collection("activities").add({
        type: "user_created",
        userName: displayName,
        userRole: "teacher",
        createdBy: request.auth.uid,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        details: {
          userId: userRecord.uid,
          email: email,
        },
      });

      logger.info(`Teacher account created: ${userRecord.uid} by admin ${request.auth.uid}`);

      return {
        success: true,
        userId: userRecord.uid,
        email: email,
        displayName: displayName,
      };
    } catch (error) {
      logger.error("Error creating teacher account:", error);

      if ((error as any).code === "auth/email-already-exists") {
        throw new HttpsError("already-exists", "Email already in use");
      }

      throw new HttpsError("internal", "Failed to create teacher account");
    }
  }
);

/**
 * Create a new admin account
 * Admin-only function (only existing admins can create new admins)
 */
export const createAdminAccount = onCall(
  {region: "us-east4", maxInstances: 10},
  async (request) => {
    // 1. Authentication check
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Authentication required");
    }

    // 2. Authorization check - must be admin
    const userDoc = await db.collection("users").doc(request.auth.uid).get();
    const userData = userDoc.data();

    if (userData?.role !== "admin") {
      throw new HttpsError("permission-denied", "Administrator access required");
    }

    // 3. Input validation
    const {email, password, displayName} = request.data;

    if (!email || !password || !displayName) {
      throw new HttpsError("invalid-argument", 
        "Email, password, and display name are required");
    }

    if (!email.includes("@")) {
      throw new HttpsError("invalid-argument", "Invalid email address");
    }

    // ENFORCE DOMAIN VALIDATION FOR ADMINS
    if (!email.toLowerCase().endsWith("@fermi-plus.com")) {
      throw new HttpsError(
        "invalid-argument",
        "Admin accounts must use @fermi-plus.com email addresses"
      );
    }

    if (password.length < 8) {
      throw new HttpsError("invalid-argument", 
        "Password must be at least 8 characters for admin accounts");
    }

    try {
      // Create the user account in Firebase Auth
      const userRecord = await auth.createUser({
        email: email,
        password: password,
        displayName: displayName,
        emailVerified: true, // Mark as verified since admin created it
      });

      // Set custom claims for role
      await auth.setCustomUserClaims(userRecord.uid, {
        role: "admin",
      });

      // Create user document in Firestore
      await db.collection("users").doc(userRecord.uid).set({
        email: email,
        displayName: displayName,
        role: "admin",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        createdBy: request.auth.uid,
        isEmailUser: true,
      });

      // Log the activity
      await db.collection("activities").add({
        type: "user_created",
        userName: displayName,
        userRole: "admin",
        createdBy: request.auth.uid,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        details: {
          userId: userRecord.uid,
          email: email,
        },
      });

      logger.info(`Admin account created: ${userRecord.uid} by admin ${request.auth.uid}`);

      return {
        success: true,
        userId: userRecord.uid,
        email: email,
        displayName: displayName,
      };
    } catch (error) {
      logger.error("Error creating admin account:", error);

      if ((error as any).code === "auth/email-already-exists") {
        throw new HttpsError("already-exists", "Email already in use");
      }

      throw new HttpsError("internal", "Failed to create admin account");
    }
  }
);

/**
 * Delete a user account
 * Admin-only function
 */
export const deleteUserAccount = onCall(
  {region: "us-east4", maxInstances: 10},
  async (request) => {
    // 1. Authentication check
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Authentication required");
    }

    // 2. Authorization check - must be admin
    const userDoc = await db.collection("users").doc(request.auth.uid).get();
    const userData = userDoc.data();

    if (userData?.role !== "admin") {
      throw new HttpsError("permission-denied", "Administrator access required");
    }

    // 3. Input validation
    const {userId} = request.data;

    if (!userId) {
      throw new HttpsError("invalid-argument", "User ID is required");
    }

    // Don't allow deleting self
    if (userId === request.auth.uid) {
      throw new HttpsError("invalid-argument", "Cannot delete your own account");
    }

    try {
      // Get user data before deletion for logging
      const targetUserDoc = await db.collection("users").doc(userId).get();
      const targetUserData = targetUserDoc.data();

      // Delete from Firebase Auth
      await auth.deleteUser(userId);

      // Delete from Firestore
      await db.collection("users").doc(userId).delete();

      // Log the activity
      await db.collection("activities").add({
        type: "user_deleted",
        userName: targetUserData?.displayName || "Unknown",
        userRole: targetUserData?.role || "unknown",
        deletedBy: request.auth.uid,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        details: {
          userId: userId,
          email: targetUserData?.email,
        },
      });

      logger.info(`User account deleted: ${userId} by admin ${request.auth.uid}`);

      return {
        success: true,
        message: "User account deleted successfully",
      };
    } catch (error) {
      logger.error("Error deleting user account:", error);
      throw new HttpsError("internal", "Failed to delete user account");
    }
  }
);

/**
 * Reset a user's password
 * Admin-only function
 */
export const resetUserPassword = onCall(
  {region: "us-east4", maxInstances: 10},
  async (request) => {
    // 1. Authentication check
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Authentication required");
    }

    // 2. Authorization check - must be admin
    const userDoc = await db.collection("users").doc(request.auth.uid).get();
    const userData = userDoc.data();

    if (userData?.role !== "admin") {
      throw new HttpsError("permission-denied", "Administrator access required");
    }

    // 3. Input validation
    const {userId} = request.data;

    if (!userId) {
      throw new HttpsError("invalid-argument", "User ID is required");
    }

    try {
      // Generate a new cryptographically secure password
      const newPassword = generateSecurePassword(12);

      // Update the user's password
      await auth.updateUser(userId, {
        password: newPassword,
      });

      // Get user data for logging
      const targetUserDoc = await db.collection("users").doc(userId).get();
      const targetUserData = targetUserDoc.data();

      // Log the activity
      await db.collection("activities").add({
        type: "password_reset",
        userName: targetUserData?.displayName || "Unknown",
        resetBy: request.auth.uid,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        details: {
          userId: userId,
        },
      });

      logger.info(`Password reset for user: ${userId} by admin ${request.auth.uid}`);

      return {
        success: true,
        newPassword: newPassword,
        message: "Password reset successfully",
      };
    } catch (error) {
      logger.error("Error resetting password:", error);
      throw new HttpsError("internal", "Failed to reset password");
    }
  }
);

/**
 * Get system statistics
 * Admin-only function
 */
export const getSystemStats = onCall(
  {region: "us-east4", maxInstances: 10},
  async (request) => {
    // 1. Authentication check
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Authentication required");
    }

    // 2. Authorization check - must be admin
    const userDoc = await db.collection("users").doc(request.auth.uid).get();
    const userData = userDoc.data();

    if (userData?.role !== "admin") {
      throw new HttpsError("permission-denied", "Administrator access required");
    }

    try {
      // Get user statistics
      const usersSnapshot = await db.collection("users").get();
      const users = usersSnapshot.docs.map((doc) => doc.data());

      const stats = {
        totalUsers: users.length,
        studentCount: users.filter((u) => u.role === "student").length,
        teacherCount: users.filter((u) => u.role === "teacher").length,
        adminCount: users.filter((u) => u.role === "admin").length,
        activeUsers: users.filter((u) => u.isOnline === true).length,
        recentActivityCount: 0, // Initialize with 0
      };

      // Get recent activity count
      const oneDayAgo = new Date();
      oneDayAgo.setDate(oneDayAgo.getDate() - 1);

      const recentActivitiesSnapshot = await db
        .collection("activities")
        .where("timestamp", ">", oneDayAgo)
        .get();

      stats.recentActivityCount = recentActivitiesSnapshot.size;

      return stats;
    } catch (error) {
      logger.error("Error getting system stats:", error);
      throw new HttpsError("internal", "Failed to get system statistics");
    }
  }
);