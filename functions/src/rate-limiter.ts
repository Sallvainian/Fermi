import * as admin from "firebase-admin";

interface RateLimiterConfig {
  name: string;
  maxCalls: number;
  periodSeconds: number;
}

interface RateLimitRecord {
  count: number;
  firstCall: admin.firestore.Timestamp;
  lastCall: admin.firestore.Timestamp;
}

export class FirestoreRateLimiter {
  private config: RateLimiterConfig;
  private firestore: admin.firestore.Firestore;
  private collectionName = "_rate_limits";

  constructor(config: RateLimiterConfig, firestore: admin.firestore.Firestore) {
    this.config = config;
    this.firestore = firestore;
  }

  static withFirestoreBackend(
    config: RateLimiterConfig,
    firestore: admin.firestore.Firestore
  ): FirestoreRateLimiter {
    return new FirestoreRateLimiter(config, firestore);
  }

  async rejectOnQuotaExceededOrRecordUsage(identifier: string): Promise<void> {
    const docId = `${this.config.name}_${identifier}`;
    const docRef = this.firestore.collection(this.collectionName).doc(docId);

    try {
      await this.firestore.runTransaction(async (transaction) => {
        const doc = await transaction.get(docRef);
        const now = admin.firestore.Timestamp.now();
        const cutoffTime = admin.firestore.Timestamp.fromMillis(
          now.toMillis() - (this.config.periodSeconds * 1000)
        );

        if (!doc.exists) {
          // First call from this identifier
          const record: RateLimitRecord = {
            count: 1,
            firstCall: now,
            lastCall: now,
          };
          transaction.set(docRef, record);
          return;
        }

        const data = doc.data() as RateLimitRecord;

        // Check if the period has expired
        if (data.firstCall.toMillis() < cutoffTime.toMillis()) {
          // Period expired, reset counter
          const record: RateLimitRecord = {
            count: 1,
            firstCall: now,
            lastCall: now,
          };
          transaction.set(docRef, record);
          return;
        }

        // Check if quota exceeded
        if (data.count >= this.config.maxCalls) {
          throw new Error("Rate limit exceeded");
        }

        // Increment counter
        transaction.update(docRef, {
          count: data.count + 1,
          firstCall: data.firstCall,
          lastCall: now,
        });
      });
    } catch (error: any) {
      if (error?.message === "Rate limit exceeded") {
        throw error;
      }
      // Log other errors but don't block the request
      console.error("Rate limiter error:", error);
    }
  }
}

// Cleanup old rate limit records periodically
export async function cleanupOldRateLimitRecords(
  firestore: admin.firestore.Firestore,
  hoursToKeep: number = 24
): Promise<void> {
  const cutoffTime = admin.firestore.Timestamp.fromMillis(
    Date.now() - (hoursToKeep * 60 * 60 * 1000)
  );

  const batch = firestore.batch();
  const snapshot = await firestore
    .collection("_rate_limits")
    .where("lastCall", "<", cutoffTime)
    .limit(500)
    .get();

  snapshot.forEach((doc) => {
    batch.delete(doc.ref);
  });

  if (!snapshot.empty) {
    await batch.commit();
    console.log(`Cleaned up ${snapshot.size} old rate limit records`);
  }
}
