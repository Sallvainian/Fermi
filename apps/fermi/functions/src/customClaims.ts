import {onCall, HttpsError} from "firebase-functions/v2/https";
import {onDocumentWritten} from "firebase-functions/v2/firestore";
import {logger} from "firebase-functions/v2";
import * as admin from "firebase-admin";

/**
 * Cloud Function to set custom claims for user roles.
 * This is needed for Storage rules to check if a user is a teacher.
 */
export const setRoleClaim = onCall({region: "us-east4"}, async (request) => {
  // Check that the request is made by an authenticated user
  if (!request.auth) {
    throw new HttpsError(
      "unauthenticated",
      "The function must be called while authenticated."
    );
  }

  const {uid, role} = request.data;

  // Validate input
  if (!uid || !role) {
    throw new HttpsError(
      "invalid-argument",
      "The function must be called with uid and role."
    );
  }

  if (!["teacher", "student"].includes(role)) {
    throw new HttpsError(
      "invalid-argument",
      "Role must be either \"teacher\" or \"student\"."
    );
  }

  try {
    // Only allow teachers to set roles (or during initial setup)
    const callerDoc = await admin.firestore()
      .collection("users")
      .doc(request.auth.uid)
      .get();

    const callerData = callerDoc.data();

    // Allow if caller is a teacher or if setting their own role during signup
    if (callerData?.role !== "teacher" && request.auth.uid !== uid) {
      throw new HttpsError(
        "permission-denied",
        "Only teachers can set roles for other users."
      );
    }

    // Set custom claim
    await admin.auth().setCustomUserClaims(uid, {role});

    // Also update the user document in Firestore to keep in sync
    await admin.firestore()
      .collection("users")
      .doc(uid)
      .update({role});

    return {
      success: true,
      message: `Successfully set role ${role} for user ${uid}`,
    };
  } catch (error) {
    logger.error("Error setting custom claim:", error);
    throw new HttpsError(
      "internal",
      "Error setting custom claim"
    );
  }
});

/**
 * Firestore trigger to automatically set custom claims when a user
 * document is created/updated. This ensures custom claims stay in sync
 * with Firestore roles.
 */
export const syncUserRole = onDocumentWritten(
  {document: "users/{userId}", region: "us-east4"},
  async (event) => {
    const userId = event.params.userId;
    const afterData = event.data?.after.exists ?
      event.data.after.data() : null;
    const beforeData = event.data?.before.exists ?
      event.data.before.data() : null;

    // If role hasn't changed, do nothing
    if (beforeData?.role === afterData?.role) {
      return null;
    }

    // If document was deleted, remove custom claims
    if (!afterData) {
      try {
        await admin.auth().setCustomUserClaims(userId, null);
        logger.log(`Removed custom claims for deleted user ${userId}`);
      } catch (error) {
        logger.error(`Error removing custom claims for user ${userId}:`, error);
      }
      return null;
    }

    // Set custom claims based on role
    const role = afterData.role;
    if (role && ["teacher", "student"].includes(role)) {
      try {
        await admin.auth().setCustomUserClaims(userId, {role});
        logger.log(`Set custom claim role=${role} for user ${userId}`);
      } catch (error) {
        logger.error(`Error setting custom claim for user ${userId}:`, error);
      }
    }

    return null;
  });
