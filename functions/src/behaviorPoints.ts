import * as functions from "firebase-functions/v2";
import * as admin from "firebase-admin";
import {HttpsError} from "firebase-functions/v2/https";

interface AwardPointsRequest {
  classId: string;
  studentId: string;
  studentName: string;
  behaviorId: string;
  behaviorName: string;
  points: number;
  gender?: string;
  gradeLevel?: string;
  studentAvatarUrl?: string;
  note?: string;
}

interface UndoPointsRequest {
  classId: string;
  studentId: string;
  historyId: string;
}

interface GetSummaryRequest {
  classId: string;
}

/**
 * Award behavior points to a student with server-side validation
 */
export const awardBehaviorPoints = functions.https.onCall(
  {
    maxInstances: 50,
    region: "us-east4",
  },
  async (request) => {
    const {auth, data} = request;

    // Validate authentication
    if (!auth) {
      throw new HttpsError("unauthenticated", "User must be authenticated");
    }

    const teacherId = auth.uid;
    const params = data as AwardPointsRequest;

    // Validate required fields
    if (!params.classId || !params.studentId || !params.behaviorId) {
      throw new HttpsError("invalid-argument", "Missing required fields");
    }

    // Validate teacher role
    const teacherDoc = await admin.firestore()
      .collection("users")
      .doc(teacherId)
      .get();

    if (!teacherDoc.exists || teacherDoc.data()?.role !== "teacher") {
      throw new HttpsError("permission-denied", "Only teachers can award points");
    }

    // Validate class ownership
    const classDoc = await admin.firestore()
      .collection("classes")
      .doc(params.classId)
      .get();

    if (!classDoc.exists) {
      throw new HttpsError("not-found", "Class not found");
    }

    const classData = classDoc.data()!;
    // Check for both teacherId (current) and teacherUID (legacy) fields for backward compatibility
    const classTeacherId = classData.teacherId || classData.teacherUID;
    if (!classTeacherId || classTeacherId !== teacherId) {
      throw new HttpsError("permission-denied", "You are not the teacher of this class");
    }

    // Generate operation ID for idempotency
    const operationId = `${teacherId}_${params.studentId}_${params.behaviorId}_${Date.now()}`;

    const db = admin.firestore();
    const batch = db.batch();

    // Check for duplicate operation (idempotency)
    const historyRef = db
      .collection("classes").doc(params.classId)
      .collection("studentPoints").doc(params.studentId)
      .collection("history").doc(operationId);

    const historyDoc = await historyRef.get();
    if (historyDoc.exists) {
      console.log(`Duplicate operation detected: ${operationId}`);
      return {
        success: false,
        message: "Duplicate operation detected",
        operationId
      };
    }

    // Update aggregate (create if doesn't exist)
    const aggregateRef = db
      .collection("classes").doc(params.classId)
      .collection("studentPoints").doc(params.studentId);

    batch.set(aggregateRef, {
      studentId: params.studentId,
      studentName: params.studentName,
      totalPoints: admin.firestore.FieldValue.increment(params.points),
      positivePoints: params.points > 0 ?
        admin.firestore.FieldValue.increment(params.points) :
        admin.firestore.FieldValue.increment(0),
      negativePoints: params.points < 0 ?
        admin.firestore.FieldValue.increment(Math.abs(params.points)) :
        admin.firestore.FieldValue.increment(0),
      [`behaviorCounts.${params.behaviorId}`]: admin.firestore.FieldValue.increment(1),
      lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
      lastUpdatedBy: teacherId,
    }, {merge: true});

    // Get teacher name for history
    const teacherName = teacherDoc.data()?.displayName || teacherDoc.data()?.name || 'Teacher';

    // Add history entry with enhanced fields
    batch.set(historyRef, {
      operationId,
      studentId: params.studentId,
      studentName: params.studentName,
      behaviorId: params.behaviorId,
      behaviorName: params.behaviorName,
      points: params.points,
      type: params.points > 0 ? 'positive' : 'negative',
      teacherId: teacherId,
      teacherName: teacherName,
      awardedBy: teacherId,
      awardedByName: teacherName,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      awardedAt: admin.firestore.FieldValue.serverTimestamp(),
      isUndone: false,
      classId: params.classId,
      gender: params.gender || null,
      gradeLevel: params.gradeLevel || null,
      studentAvatarUrl: params.studentAvatarUrl || null,
      note: params.note || null,
    });

    // Commit batch
    await batch.commit();

    console.log(`Points awarded successfully: ${operationId}`);
    return {
      success: true,
      operationId,
      message: "Points awarded successfully"
    };
  }
);

/**
 * Undo previously awarded behavior points
 */
export const undoBehaviorPoints = functions.https.onCall(
  {
    maxInstances: 50,
    region: "us-east4",
  },
  async (request) => {
    const {auth, data} = request;

    // Validate authentication
    if (!auth) {
      throw new HttpsError("unauthenticated", "User must be authenticated");
    }

    const teacherId = auth.uid;
    const params = data as UndoPointsRequest;

    // Validate required fields
    if (!params.classId || !params.studentId || !params.historyId) {
      throw new HttpsError("invalid-argument", "Missing required fields");
    }

    // Validate teacher role
    const teacherDoc = await admin.firestore()
      .collection("users")
      .doc(teacherId)
      .get();

    if (!teacherDoc.exists || teacherDoc.data()?.role !== "teacher") {
      throw new HttpsError("permission-denied", "Only teachers can undo points");
    }

    // Validate class ownership
    const classDoc = await admin.firestore()
      .collection("classes")
      .doc(params.classId)
      .get();

    if (!classDoc.exists) {
      throw new HttpsError("not-found", "Class not found");
    }

    const classData = classDoc.data()!;
    // Check for both teacherId (current) and teacherUID (legacy) fields for backward compatibility
    const classTeacherId = classData.teacherId || classData.teacherUID;
    if (!classTeacherId || classTeacherId !== teacherId) {
      throw new HttpsError("permission-denied", "You are not the teacher of this class");
    }

    const db = admin.firestore();

    // Get the history entry
    const historyRef = db
      .collection("classes").doc(params.classId)
      .collection("studentPoints").doc(params.studentId)
      .collection("history").doc(params.historyId);

    const historyDoc = await historyRef.get();
    if (!historyDoc.exists) {
      throw new HttpsError("not-found", "History entry not found");
    }

    const history = historyDoc.data()!;

    // Check if already undone
    if (history.isUndone) {
      return {
        success: false,
        message: "This operation has already been undone"
      };
    }

    const batch = db.batch();

    // Reverse the aggregate points
    const aggregateRef = db
      .collection("classes").doc(params.classId)
      .collection("studentPoints").doc(params.studentId);

    batch.update(aggregateRef, {
      totalPoints: admin.firestore.FieldValue.increment(-history.points),
      positivePoints: history.points > 0 ?
        admin.firestore.FieldValue.increment(-history.points) :
        admin.firestore.FieldValue.increment(0),
      negativePoints: history.points < 0 ?
        admin.firestore.FieldValue.increment(-Math.abs(history.points)) :
        admin.firestore.FieldValue.increment(0),
      [`behaviorCounts.${history.behaviorId}`]: admin.firestore.FieldValue.increment(-1),
      lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
      lastUpdatedBy: teacherId,
    });

    // Mark history entry as undone
    batch.update(historyRef, {
      isUndone: true,
      undoneBy: teacherId,
      undoneAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Commit batch
    await batch.commit();

    console.log(`Points undone successfully: ${params.historyId}`);
    return {
      success: true,
      message: "Points undone successfully"
    };
  }
);

/**
 * Get class points summary (for initial load or refresh)
 */
export const getClassPointsSummary = functions.https.onCall(
  {
    maxInstances: 50,
    region: "us-east4",
  },
  async (request) => {
    const {auth, data} = request;

    // Validate authentication
    if (!auth) {
      throw new HttpsError("unauthenticated", "User must be authenticated");
    }

    const params = data as GetSummaryRequest;

    // Validate required fields
    if (!params.classId) {
      throw new HttpsError("invalid-argument", "Class ID is required");
    }

    // Get user role
    const userDoc = await admin.firestore()
      .collection("users")
      .doc(auth.uid)
      .get();

    const userData = userDoc.data();
    if (!userData) {
      throw new HttpsError("permission-denied", "User data not found");
    }

    // Check permissions
    if (userData.role === "teacher") {
      // Teachers can view their own classes
      const classDoc = await admin.firestore()
        .collection("classes")
        .doc(params.classId)
        .get();

      if (!classDoc.exists) {
        throw new HttpsError("not-found", "Class not found");
      }

      const classData = classDoc.data()!;
      // Check for both teacherId (current) and teacherUID (legacy) fields for backward compatibility
      const classTeacherId = classData.teacherId || classData.teacherUID;
      if (!classTeacherId || classTeacherId !== auth.uid) {
        throw new HttpsError("permission-denied", "You are not the teacher of this class");
      }
    } else if (userData.role === "student") {
      // Students can only view their own points
      // This would be handled differently
      throw new HttpsError("permission-denied", "Students should use a different endpoint");
    } else {
      throw new HttpsError("permission-denied", "Invalid user role");
    }

    // Get all student points for the class
    const snapshot = await admin.firestore()
      .collection("classes").doc(params.classId)
      .collection("studentPoints")
      .get();

    const summaries: Record<string, any> = {};
    snapshot.docs.forEach(doc => {
      summaries[doc.id] = doc.data();
    });

    return {
      success: true,
      summaries
    };
  }
);

/**
 * Get filtered behavior history for a class
 */
export const getBehaviorHistory = functions.https.onCall(
  {
    maxInstances: 50,
    region: "us-east4",
  },
  async (request) => {
    const {auth, data} = request;

    // Validate authentication
    if (!auth) {
      throw new HttpsError("unauthenticated", "User must be authenticated");
    }

    const userId = auth.uid;

    interface HistoryRequest {
      classId: string;
      studentId?: string;
      gender?: string;
      startDate?: string;
      endDate?: string;
      behaviorType?: 'positive' | 'negative' | 'all';
      limit?: number;
      offset?: number;
    }

    const params = data as HistoryRequest;

    // Validate required fields
    if (!params.classId) {
      throw new HttpsError("invalid-argument", "Class ID is required");
    }

    try {
      // Check if user is teacher or student
      const userDoc = await admin.firestore()
        .collection("users")
        .doc(userId)
        .get();

      const userData = userDoc.data();
      if (!userData) {
        throw new HttpsError("permission-denied", "User data not found");
      }

      // Teachers can view all history, students only their own
      if (userData.role === "teacher") {
        const classDoc = await admin.firestore()
          .collection("classes")
          .doc(params.classId)
          .get();

        if (!classDoc.exists) {
          throw new HttpsError("not-found", "Class not found");
        }

        const classData = classDoc.data();
        if (!classData) {
          throw new HttpsError("not-found", "Class data not found");
        }

        // Check for both teacherId (current) and teacherUID (legacy) fields for backward compatibility
        const classTeacherId = classData.teacherId || classData.teacherUID;
        if (!classTeacherId || classTeacherId !== userId) {
          throw new HttpsError("permission-denied", "You are not the teacher of this class");
        }
      } else if (userData.role === "student") {
        // Students can only view their own history
        params.studentId = userId;
      } else {
        throw new HttpsError("permission-denied", "Invalid user role");
      }

      // Build query
      let query: admin.firestore.Query = admin.firestore()
        .collectionGroup("history")
        .where("classId", "==", params.classId)
        .where("isUndone", "==", false);

      // Apply filters
      if (params.studentId) {
        query = query.where("studentId", "==", params.studentId);
      }

      if (params.gender) {
        query = query.where("gender", "==", params.gender);
      }

      if (params.behaviorType && params.behaviorType !== 'all') {
        query = query.where("type", "==", params.behaviorType);
      }

      // Date range filter
      if (params.startDate) {
        const startDate = new Date(params.startDate);
        if (!isNaN(startDate.getTime())) {
          query = query.where("timestamp", ">=", admin.firestore.Timestamp.fromDate(startDate));
        }
      }

      if (params.endDate) {
        const endDate = new Date(params.endDate);
        if (!isNaN(endDate.getTime())) {
          endDate.setHours(23, 59, 59, 999); // End of day
          query = query.where("timestamp", "<=", admin.firestore.Timestamp.fromDate(endDate));
        }
      }

      // Order and pagination - using awardedAt which is the actual timestamp field
      query = query.orderBy("awardedAt", "desc");

      const limit = params.limit || 50;
      const offset = params.offset || 0;

      if (offset > 0) {
        query = query.offset(offset);
      }
      query = query.limit(limit);

      // Execute query
      const snapshot = await query.get();

      const history = snapshot.docs.map(doc => {
        const docData = doc.data();
        const result: any = {
          id: doc.id,
          ...docData,
        };

        // Convert timestamp fields
        if (docData.timestamp && typeof docData.timestamp.toDate === 'function') {
          result.timestamp = (docData.timestamp as admin.firestore.Timestamp).toDate().toISOString();
        }
        if (docData.awardedAt && typeof docData.awardedAt.toDate === 'function') {
          result.awardedAt = (docData.awardedAt as admin.firestore.Timestamp).toDate().toISOString();
        }

        return result;
      });

      // Get total count for pagination
      let countQuery: admin.firestore.Query = admin.firestore()
        .collectionGroup("history")
        .where("classId", "==", params.classId)
        .where("isUndone", "==", false);

      if (params.studentId) {
        countQuery = countQuery.where("studentId", "==", params.studentId);
      }
      if (params.gender) {
        countQuery = countQuery.where("gender", "==", params.gender);
      }
      if (params.behaviorType && params.behaviorType !== 'all') {
        countQuery = countQuery.where("type", "==", params.behaviorType);
      }

      const countSnapshot = await countQuery.count().get();
      const totalCount = countSnapshot.data().count;

      return {
        success: true,
        history,
        totalCount,
        hasMore: (offset + limit) < totalCount,
      };
    } catch (error: any) {
      console.error("Error in getBehaviorHistory:", error);

      // Re-throw HttpsError instances
      if (error instanceof HttpsError) {
        throw error;
      }

      // For other errors, wrap them
      throw new HttpsError(
        "internal",
        `Failed to get behavior history: ${error.message || error}`
      );
    }
  }
);