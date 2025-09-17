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

    if (!classDoc.exists || classDoc.data()?.teacherUID !== teacherId) {
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

    // Add history entry
    batch.set(historyRef, {
      operationId,
      studentId: params.studentId,
      studentName: params.studentName,
      behaviorId: params.behaviorId,
      behaviorName: params.behaviorName,
      points: params.points,
      awardedBy: teacherId,
      awardedAt: admin.firestore.FieldValue.serverTimestamp(),
      isUndone: false,
      classId: params.classId,
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

    if (!classDoc.exists || classDoc.data()?.teacherUID !== teacherId) {
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

      if (!classDoc.exists || classDoc.data()?.teacherUID !== auth.uid) {
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