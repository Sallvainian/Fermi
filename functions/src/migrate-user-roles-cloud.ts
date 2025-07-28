import * as admin from "firebase-admin";
import { https } from "firebase-functions/v2";

/**
 * Cloud Function to migrate existing users' roles to custom claims.
 * This can be called once to migrate all existing users.
 * Deploy this function and call it via HTTP to run the migration.
 */

// The function will use the default service account when running in Cloud Functions


export const migrateAllUserRoles = https.onCall(
  { region: "us-east4" },
  async (request) => {
    // Only allow authenticated users to call this
    if (!request.auth) {
      throw new https.HttpsError(
        "unauthenticated",
        "Must be authenticated to run migration"
      );
    }

    // Check if caller is a teacher (for security)
    const callerDoc = await admin
      .firestore()
      .collection("users")
      .doc(request.auth.uid)
      .get();
    const callerData = callerDoc.data();
    
    if (callerData?.role !== "teacher") {
      throw new https.HttpsError(
        "permission-denied",
        "Only teachers can run migration"
      );
    }

    console.log("Starting user role migration...");
    
    const firestore = admin.firestore();
    const auth = admin.auth();
    
    try {
      // Get all users from Firestore
      const usersSnapshot = await firestore.collection("users").get();
      
      console.log(`Found ${usersSnapshot.size} users to migrate`);
      
      let successCount = 0;
      let errorCount = 0;
      const errors: string[] = [];
      
      // Process each user
      for (const doc of usersSnapshot.docs) {
        const userId = doc.id;
        const userData = doc.data();
        const role = userData.role;
        
        if (!role || !["teacher", "student"].includes(role)) {
          console.warn(`User ${userId} has invalid or missing role: ${role}`);
          errorCount++;
          errors.push(`${userId}: invalid role '${role}'`);
          continue;
        }
        
        try {
          // Set custom claim for the user
          await auth.setCustomUserClaims(userId, { role });
          console.log(`✓ Set custom claim for user ${userId} with role: ${role}`);
          successCount++;
        } catch (error: any) {
          console.error(`✗ Error setting custom claim for user ${userId}:`, error);
          errorCount++;
          errors.push(`${userId}: ${error.message}`);
        }
      }
      
      const result = {
        success: true,
        message: "Migration completed",
        successCount,
        errorCount,
        totalUsers: usersSnapshot.size,
        errors: errorCount > 0 ? errors : undefined,
      };
      
      console.log("Migration result:", result);
      return result;
      
    } catch (error: any) {
      console.error("Error during migration:", error);
      throw new https.HttpsError("internal", "Migration failed: " + error.message);
    }
  }
);