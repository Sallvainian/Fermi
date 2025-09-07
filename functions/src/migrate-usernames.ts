import * as admin from "firebase-admin";
import {https} from "firebase-functions/v2";

/**
 * Cloud Function to migrate existing usernames to the public_usernames collection.
 * This ensures existing users can still log in after the security update.
 * 
 * The public_usernames collection contains minimal data (uid and role only)
 * to prevent exposing sensitive user information.
 */

export const migrateUsernamesToPublic = https.onCall(
  {region: "us-east4"},
  async (request) => {
    // Only allow authenticated users to call this
    if (!request.auth) {
      throw new https.HttpsError(
        "unauthenticated",
        "Must be authenticated to run migration"
      );
    }

    // Check if caller is a teacher or admin (for security)
    const callerDoc = await admin
      .firestore()
      .collection("users")
      .doc(request.auth.uid)
      .get();
    const callerData = callerDoc.data();

    if (callerData?.role !== "teacher" && callerData?.role !== "admin") {
      throw new https.HttpsError(
        "permission-denied",
        "Only teachers or admins can run migration"
      );
    }

    console.log("Starting username migration to public_usernames collection...");

    const firestore = admin.firestore();

    try {
      // Get all users with usernames from Firestore
      const usersSnapshot = await firestore
        .collection("users")
        .where("username", "!=", null)
        .get();

      console.log(`Found ${usersSnapshot.size} users with usernames to migrate`);

      let successCount = 0;
      let skipCount = 0;
      let errorCount = 0;
      const errors: string[] = [];

      // Use batch writes for efficiency (max 500 per batch)
      const batchSize = 500;
      let batch = firestore.batch();
      let operationCount = 0;

      // Process each user
      for (const doc of usersSnapshot.docs) {
        const userId = doc.id;
        const userData = doc.data();
        const username = userData.username;
        const role = userData.role || "student";

        if (!username) {
          console.warn(`User ${userId} has no username, skipping`);
          skipCount++;
          continue;
        }

        try {
          // Check if already exists in public_usernames
          const publicDoc = await firestore
            .collection("public_usernames")
            .doc(username.toLowerCase())
            .get();

          if (publicDoc.exists) {
            console.log(`Username ${username} already migrated, skipping`);
            skipCount++;
            continue;
          }

          // Add to batch
          const publicUsernameRef = firestore
            .collection("public_usernames")
            .doc(username.toLowerCase());
          
          batch.set(publicUsernameRef, {
            uid: userId,
            role: role,
            migratedAt: admin.firestore.FieldValue.serverTimestamp(),
          });

          operationCount++;
          
          // Commit batch if we've reached the limit
          if (operationCount >= batchSize) {
            await batch.commit();
            console.log(`Committed batch of ${operationCount} operations`);
            successCount += operationCount;
            
            // Start new batch
            batch = firestore.batch();
            operationCount = 0;
          }

        } catch (error: any) {
          console.error(`Error processing user ${userId} (${username}):`, error);
          errorCount++;
          errors.push(`${userId} (${username}): ${error.message}`);
        }
      }

      // Commit any remaining operations
      if (operationCount > 0) {
        await batch.commit();
        console.log(`Committed final batch of ${operationCount} operations`);
        successCount += operationCount;
      }

      const result = {
        success: true,
        message: "Username migration completed",
        successCount,
        skipCount,
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

/**
 * HTTP endpoint version for running migration from admin tools
 */
export const migrateUsernamesHttp = https.onRequest(
  {region: "us-east4"},
  async (req, res) => {
    // Simple auth check - you might want to add a secret key check here
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      res.status(401).send("Unauthorized");
      return;
    }

    try {
      // Verify the token
      const token = authHeader.split("Bearer ")[1];
      const decodedToken = await admin.auth().verifyIdToken(token);
      
      // Check if user is admin/teacher
      const userDoc = await admin
        .firestore()
        .collection("users")
        .doc(decodedToken.uid)
        .get();
      
      const userData = userDoc.data();
      if (userData?.role !== "teacher" && userData?.role !== "admin") {
        res.status(403).send("Forbidden: Only teachers/admins can run migration");
        return;
      }

      // Run the same migration logic
      const result = await runMigration();
      res.json(result);
    } catch (error: any) {
      console.error("Migration error:", error);
      res.status(500).json({
        success: false,
        error: error.message,
      });
    }
  }
);

/**
 * Shared migration logic
 */
async function runMigration() {
  const firestore = admin.firestore();
  
  const usersSnapshot = await firestore
    .collection("users")
    .where("username", "!=", null)
    .get();

  let successCount = 0;
  let skipCount = 0;
  const batchSize = 500;
  let batch = firestore.batch();
  let operationCount = 0;

  for (const doc of usersSnapshot.docs) {
    const userData = doc.data();
    const username = userData.username;
    
    if (!username) continue;
    
    // Check if already migrated
    const exists = await firestore
      .collection("public_usernames")
      .doc(username.toLowerCase())
      .get();
    
    if (exists.exists) {
      skipCount++;
      continue;
    }

    batch.set(
      firestore.collection("public_usernames").doc(username.toLowerCase()),
      {
        uid: doc.id,
        role: userData.role || "student",
        migratedAt: admin.firestore.FieldValue.serverTimestamp(),
      }
    );

    operationCount++;
    
    if (operationCount >= batchSize) {
      await batch.commit();
      successCount += operationCount;
      batch = firestore.batch();
      operationCount = 0;
    }
  }

  if (operationCount > 0) {
    await batch.commit();
    successCount += operationCount;
  }

  return {
    success: true,
    successCount,
    skipCount,
    totalUsers: usersSnapshot.size,
  };
}