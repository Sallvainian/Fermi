import {onSchedule} from "firebase-functions/v2/scheduler";
import * as admin from "firebase-admin";

/**
 * Scheduled cleanup job for expired PKCE challenges
 * Runs every hour to remove expired challenges from Firestore
 * This prevents the database from growing indefinitely with stale data
 */
export const cleanupExpiredPKCEChallenges = onSchedule(
  {
    schedule: "every 1 hours", // Run every hour
    timeZone: "America/New_York", // Set appropriate timezone
    retryCount: 3, // Retry up to 3 times on failure
    memory: "256MiB", // Minimal memory needed for cleanup
  },
  async () => {
    console.log("Starting PKCE challenge cleanup job...");

    try {
      const db = admin.firestore();
      const collection = db.collection("oauth_pkce_challenges");

      // Get current timestamp
      const now = Date.now();

      // Query for expired challenges
      // We look for documents where expiresAt is less than current time
      const expiredSnapshot = await collection
        .where("expiresAt", "<", now)
        .get();

      if (expiredSnapshot.empty) {
        console.log("No expired PKCE challenges found");
        return;
      }

      console.log(`Found ${expiredSnapshot.size} expired PKCE challenges to clean up`);

      // Batch delete for efficiency (Firestore allows max 500 operations per batch)
      const batchSize = 500;
      const batches = [];
      let batch = db.batch();
      let operationCount = 0;

      expiredSnapshot.docs.forEach((doc) => {
        batch.delete(doc.ref);
        operationCount++;

        // If we reach the batch size limit, save this batch and start a new one
        if (operationCount === batchSize) {
          batches.push(batch);
          batch = db.batch();
          operationCount = 0;
        }
      });

      // Don't forget the last batch if it has operations
      if (operationCount > 0) {
        batches.push(batch);
      }

      // Execute all batches
      const deletePromises = batches.map((b) => b.commit());
      await Promise.all(deletePromises);

      console.log(`Successfully cleaned up ${expiredSnapshot.size} expired PKCE challenges`);

      // Also clean up very old documents that might not have expiresAt field
      // This handles any legacy data from before we added expiration
      const thirtyDaysAgo = now - (30 * 24 * 60 * 60 * 1000); // 30 days in milliseconds

      const oldDocsSnapshot = await collection
        .where("createdAt", "<", new admin.firestore.Timestamp(
          Math.floor(thirtyDaysAgo / 1000), 0
        ))
        .get();

      if (!oldDocsSnapshot.empty) {
        console.log(`Found ${oldDocsSnapshot.size} old PKCE challenges without proper expiration`);

        // Batch delete old documents
        const oldBatches = [];
        let oldBatch = db.batch();
        let oldOperationCount = 0;

        oldDocsSnapshot.docs.forEach((doc) => {
          oldBatch.delete(doc.ref);
          oldOperationCount++;

          if (oldOperationCount === batchSize) {
            oldBatches.push(oldBatch);
            oldBatch = db.batch();
            oldOperationCount = 0;
          }
        });

        if (oldOperationCount > 0) {
          oldBatches.push(oldBatch);
        }

        const oldDeletePromises = oldBatches.map((b) => b.commit());
        await Promise.all(oldDeletePromises);

        console.log(`Successfully cleaned up ${oldDocsSnapshot.size} old PKCE challenges`);
      }

      // Log cleanup statistics
      const remainingSnapshot = await collection.count().get();
      const remainingCount = remainingSnapshot.data().count;
      console.log(`Cleanup complete. ${remainingCount} valid PKCE challenges remain in database`);
    } catch (error) {
      console.error("Error during PKCE cleanup:", error);
      throw error; // Re-throw to trigger retry mechanism
    }
  }
);

/** Cleanup result statistics */
export interface CleanupResult {
  expired: number;
  old: number;
  remaining: number;
}

/**
 * Manual cleanup function that can be triggered for immediate cleanup
 * Useful for testing or emergency cleanup scenarios
 */
export const manualPKCECleanup = async (): Promise<CleanupResult> => {
  const db = admin.firestore();
  const collection = db.collection("oauth_pkce_challenges");
  const now = Date.now();

  let expiredCount = 0;
  let oldCount = 0;

  // Clean expired challenges
  const expiredSnapshot = await collection
    .where("expiresAt", "<", now)
    .get();

  if (!expiredSnapshot.empty) {
    const deletePromises = expiredSnapshot.docs.map((doc) => doc.ref.delete());
    await Promise.all(deletePromises);
    expiredCount = expiredSnapshot.size;
  }

  // Clean old challenges without proper expiration
  const thirtyDaysAgo = now - (30 * 24 * 60 * 60 * 1000);
  const oldDocsSnapshot = await collection
    .where("createdAt", "<", new admin.firestore.Timestamp(
      Math.floor(thirtyDaysAgo / 1000), 0
    ))
    .get();

  if (!oldDocsSnapshot.empty) {
    const deletePromises = oldDocsSnapshot.docs.map((doc) => doc.ref.delete());
    await Promise.all(deletePromises);
    oldCount = oldDocsSnapshot.size;
  }

  // Count remaining
  const remainingSnapshot = await collection.count().get();
  const remaining = remainingSnapshot.data().count;

  return {
    expired: expiredCount,
    old: oldCount,
    remaining: remaining,
  };
};
