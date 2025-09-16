import {onCall, HttpsError} from "firebase-functions/v2/https";
import {logger} from "firebase-functions/v2";
import * as admin from "firebase-admin";

const db = admin.firestore();
const auth = admin.auth();

interface BulkImportUser {
  email: string;
  displayName: string;
  classIds?: string[];  // Direct class IDs for admin bulk import
  enrollmentCode?: string;  // Optional enrollment code for CSV imports
  gradeLevel?: string | number;
  parentEmail?: string;
  isGoogleAuth?: boolean;
  studentId?: string;  // Optional student ID for record keeping
}

interface ImportResult {
  email: string;
  success: boolean;
  uid?: string;
  error?: string;
}

/**
 * Bulk import students using Firebase Admin SDK's importUsers method
 * This is significantly more efficient than creating users one-by-one
 * Can handle up to 1000 users in a single batch
 */
export const bulkImportStudents = onCall(
  {
    region: "us-east4",
    maxInstances: 10,
    memory: "512MiB",
    timeoutSeconds: 300, // 5 minutes for large imports
  },
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
    const {users, csvData, sendPasswordResetEmails = true} = request.data;

    let usersToImport: BulkImportUser[] = [];

    // Handle CSV data if provided
    if (csvData) {
      try {
        usersToImport = parseCSV(csvData);
      } catch (error) {
        throw new HttpsError("invalid-argument", `CSV parsing error: ${error}`);
      }
    } else if (users && Array.isArray(users)) {
      usersToImport = users;
    } else {
      throw new HttpsError("invalid-argument", "Either 'users' array or 'csvData' must be provided");
    }

    // Validate input
    if (usersToImport.length === 0) {
      throw new HttpsError("invalid-argument", "No users to import");
    }

    if (usersToImport.length > 1000) {
      throw new HttpsError("invalid-argument", "Cannot import more than 1000 users at once");
    }

    // 4. Validate all emails before processing
    const emailValidationErrors: string[] = [];
    const validatedUsers: BulkImportUser[] = [];
    const existingEmails = new Set<string>();

    for (let i = 0; i < usersToImport.length; i++) {
      const user = usersToImport[i];
      const email = user.email?.toLowerCase().trim();

      if (!email) {
        emailValidationErrors.push(`Row ${i + 1}: Email is required`);
        continue;
      }

      if (!email.includes("@")) {
        emailValidationErrors.push(`Row ${i + 1}: Invalid email format: ${email}`);
        continue;
      }

      // Enforce domain validation for students
      if (!email.endsWith("@rosellestudent.org") &&
          !email.endsWith("@rosellestudent.com")) {
        emailValidationErrors.push(
          `Row ${i + 1}: Student email must use @rosellestudent.org or @rosellestudent.com domain: ${email}`
        );
        continue;
      }

      // Check for duplicates in the import list
      if (existingEmails.has(email)) {
        emailValidationErrors.push(`Row ${i + 1}: Duplicate email in import list: ${email}`);
        continue;
      }

      existingEmails.add(email);
      validatedUsers.push({
        ...user,
        email: email,
        displayName: user.displayName || email.split("@")[0],
      });
    }

    if (emailValidationErrors.length > 0) {
      throw new HttpsError(
        "invalid-argument",
        `Validation errors:\n${emailValidationErrors.join("\n")}`
      );
    }

    // 5. Check for existing users in Firebase Auth
    const existingUserChecks = await Promise.allSettled(
      validatedUsers.map(user => auth.getUserByEmail(user.email))
    );

    const alreadyExistingUsers: string[] = [];
    const newUsers: BulkImportUser[] = [];

    existingUserChecks.forEach((result, index) => {
      if (result.status === "fulfilled") {
        alreadyExistingUsers.push(validatedUsers[index].email);
      } else {
        newUsers.push(validatedUsers[index]);
      }
    });

    if (newUsers.length === 0) {
      return {
        success: false,
        message: "All users already exist",
        alreadyExisting: alreadyExistingUsers,
        imported: [],
        failed: [],
      };
    }

    // 6. Process class assignments
    // Support both direct classIds and enrollment codes
    const enrollmentCodeToClassId = new Map<string, string>();
    const validClassIds = new Set<string>();
    const classErrors: string[] = [];

    // First, validate all class IDs and look up enrollment codes
    for (const user of newUsers) {
      // Handle direct class IDs (preferred for admin bulk import)
      if (user.classIds && user.classIds.length > 0) {
        for (const classId of user.classIds) {
          // Verify each class ID exists
          if (!validClassIds.has(classId)) {
            const classDoc = await db.collection("classes").doc(classId).get();
            if (classDoc.exists) {
              validClassIds.add(classId);
              logger.info(`Validated class ID ${classId} for ${user.email}`);
            } else {
              classErrors.push(`Class ID ${classId} does not exist for ${user.email}`);
            }
          }
        }
      }
      // Handle enrollment codes (for CSV imports)
      else if (user.enrollmentCode && !enrollmentCodeToClassId.has(user.enrollmentCode)) {
        try {
          const classSnapshot = await db.collection("classes")
            .where("enrollmentCode", "==", user.enrollmentCode.toUpperCase())
            .where("isActive", "==", true)
            .limit(1)
            .get();

          if (!classSnapshot.empty) {
            const classDoc = classSnapshot.docs[0];
            enrollmentCodeToClassId.set(user.enrollmentCode, classDoc.id);
            validClassIds.add(classDoc.id);
            logger.info(`Found class ${classDoc.id} for enrollment code ${user.enrollmentCode}`);
          } else {
            classErrors.push(`No active class found for enrollment code: ${user.enrollmentCode}`);
          }
        } catch (error) {
          logger.error(`Error looking up enrollment code ${user.enrollmentCode}:`, error);
        }
      }
    }

    if (classErrors.length > 0) {
      logger.warn("Class assignment issues:", classErrors);
    }

    // 7. Prepare users for bulk import with generated UIDs
    const userUidMap = new Map<string, string>(); // email -> uid
    const importUserRecords: any[] = newUsers.map(user => {
      // Generate a unique UID for each user
      const uid = generateUid();
      userUidMap.set(user.email, uid);

      const record: any = {
        uid: uid, // REQUIRED: Must provide UID for importUsers
        email: user.email,
        displayName: user.displayName,
        emailVerified: true, // Mark as verified since admin is creating them
        disabled: false,
      };

      // For Google OAuth users, don't set a password
      // For email/password users, generate a temporary password
      if (!user.isGoogleAuth) {
        // Generate a temporary password that will be reset
        record.passwordHash = Buffer.from(generateTempPasswordHash());
        record.passwordSalt = Buffer.from(generateSalt());
      }

      // Set custom claims (removing className, keeping role)
      record.customClaims = {
        role: "student",
        gradeLevel: user.gradeLevel || null,
      };

      return record;
    });

    // 7. Perform bulk import using Admin SDK
    const results: ImportResult[] = [];
    let importResult;

    try {
      logger.info(`Starting bulk import of ${importUserRecords.length} students`);

      // Use the Admin SDK's importUsers method for efficient bulk creation
      importResult = await auth.importUsers(importUserRecords, {
        hash: {
          algorithm: "BCRYPT",
        },
      });

      // Process successful imports
      if (importResult.successCount > 0) {
        // For newer versions of Firebase Admin, the users array might be in a different place
        // We'll need to get the created users differently

        // Create Firestore documents in batch
        const batch = db.batch();
        const timestamp = admin.firestore.FieldValue.serverTimestamp();

        // We now have the UIDs from our generation step
        const studentClassMap = new Map<string, string[]>(); // uid -> classIds array

        for (let i = 0; i < newUsers.length; i++) {
          const originalData = newUsers[i];
          const uid = userUidMap.get(originalData.email);

          if (!uid) {
            logger.warn(`No UID found for ${originalData.email}`);
            continue;
          }

          // Collect all class IDs for this student
          const studentClassIds: string[] = [];

          // Handle direct class IDs
          if (originalData.classIds && originalData.classIds.length > 0) {
            for (const classId of originalData.classIds) {
              if (validClassIds.has(classId)) {
                studentClassIds.push(classId);
              }
            }
          }
          // Handle enrollment code
          else if (originalData.enrollmentCode && enrollmentCodeToClassId.has(originalData.enrollmentCode)) {
            const classId = enrollmentCodeToClassId.get(originalData.enrollmentCode)!;
            studentClassIds.push(classId);
          }

          // Store for later class updates
          if (studentClassIds.length > 0) {
            studentClassMap.set(uid, studentClassIds);
          }

          // Create user document
          const userRef = db.collection("users").doc(uid);
          const userDocData: any = {
            email: originalData.email,
            displayName: originalData.displayName,
            role: "student",
            gradeLevel: originalData.gradeLevel ? String(originalData.gradeLevel) : null,
            parentEmail: originalData.parentEmail || null,
            createdAt: timestamp,
            createdBy: request.auth!.uid,
            isEmailUser: !originalData.isGoogleAuth,
            isGoogleAuth: originalData.isGoogleAuth || false,
            profileComplete: false,
          };

          // Add student ID if provided
          if (originalData.studentId) {
            userDocData.studentId = originalData.studentId;
          }

          // Add class information if available
          if (studentClassIds.length > 0) {
            userDocData.classId = studentClassIds[0]; // Primary class
            userDocData.enrolledClasses = studentClassIds; // All classes
          }

          batch.set(userRef, userDocData);

          results.push({
            email: originalData.email,
            success: true,
            uid: uid,
          });
        }

        // Commit all Firestore writes in a single batch
        await batch.commit();

        // Update class documents to add students to studentIds array
        if (studentClassMap.size > 0) {
          const classUpdates = new Map<string, string[]>();

          // Group students by classes (handle multiple classes per student)
          for (const [studentId, classIds] of studentClassMap.entries()) {
            for (const classId of classIds) {
              if (!classUpdates.has(classId)) {
                classUpdates.set(classId, []);
              }
              classUpdates.get(classId)!.push(studentId);
            }
          }

          // Update each class with its new students
          const classUpdatePromises = [];
          for (const [classId, studentIds] of classUpdates.entries()) {
            const classRef = db.collection("classes").doc(classId);
            const updatePromise = classRef.update({
              studentIds: admin.firestore.FieldValue.arrayUnion(...studentIds),
              updatedAt: timestamp,
            });
            classUpdatePromises.push(updatePromise);
            logger.info(`Adding ${studentIds.length} students to class ${classId}`);
          }

          await Promise.all(classUpdatePromises);
        }

        // Send password reset emails for non-OAuth users
        if (sendPasswordResetEmails) {
          const emailPromises = results
            .filter((result) => {
              const originalUser = newUsers.find(u => u.email === result.email);
              return result.success && originalUser && !originalUser.isGoogleAuth;
            })
            .map(async (result) => {
              try {
                const link = await auth.generatePasswordResetLink(result.email);
                // In production, you would send this link via email
                // For now, we'll just log it
                logger.info(`Password reset link generated for ${result.email}: ${link}`);
              } catch (error) {
                logger.error(`Failed to generate password reset for ${result.email}:`, error);
              }
            });

          await Promise.allSettled(emailPromises);
        }
      }

      // Process failed imports
      if (importResult.errors && importResult.errors.length > 0) {
        for (const error of importResult.errors) {
          const failedUser = newUsers[error.index];
          results.push({
            email: failedUser.email,
            success: false,
            error: error.error.message,
          });
        }
      }

      // Log the bulk import activity
      await db.collection("activities").add({
        type: "bulk_import",
        action: "students_imported",
        performedBy: request.auth.uid,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        details: {
          totalAttempted: newUsers.length,
          successCount: importResult.successCount,
          failureCount: importResult.failureCount,
          alreadyExisting: alreadyExistingUsers.length,
        },
      });

      logger.info(
        `Bulk import completed: ${importResult.successCount} succeeded, ${importResult.failureCount} failed`
      );

    } catch (error) {
      logger.error("Error during bulk import:", error);
      throw new HttpsError("internal", `Bulk import failed: ${error}`);
    }

    // 8. Return comprehensive results
    return {
      success: true,
      message: `Imported ${importResult.successCount} of ${newUsers.length} users`,
      summary: {
        attempted: validatedUsers.length,
        imported: importResult.successCount,
        failed: importResult.failureCount,
        alreadyExisting: alreadyExistingUsers.length,
      },
      imported: results.filter(r => r.success),
      failed: results.filter(r => !r.success),
      alreadyExisting: alreadyExistingUsers,
    };
  }
);

/**
 * Parse CSV data into user objects
 */
function parseCSV(csvData: string): BulkImportUser[] {
  const lines = csvData.trim().split("\n");
  if (lines.length < 2) {
    throw new Error("CSV must have a header row and at least one data row");
  }

  // Parse header
  const headers = lines[0].split(",").map(h => h.trim().toLowerCase());

  // Validate required headers
  const requiredHeaders = ["name", "email"];
  const missingHeaders = requiredHeaders.filter(h => !headers.includes(h));
  if (missingHeaders.length > 0) {
    throw new Error(`Missing required CSV headers: ${missingHeaders.join(", ")}`);
  }

  // Find column indices
  const nameIndex = headers.indexOf("name");
  const emailIndex = headers.indexOf("email");
  const classIdsIndex = headers.indexOf("classids") !== -1 ? headers.indexOf("classids") : headers.indexOf("class_ids");
  const enrollmentCodeIndex = headers.indexOf("enrollmentcode") !== -1 ? headers.indexOf("enrollmentcode") : headers.indexOf("enrollment_code");
  const gradeIndex = headers.indexOf("grade") !== -1 ? headers.indexOf("grade") : headers.indexOf("gradelevel");
  const parentEmailIndex = headers.indexOf("parentemail") !== -1 ? headers.indexOf("parentemail") : headers.indexOf("parent_email");
  const authTypeIndex = headers.indexOf("authtype") !== -1 ? headers.indexOf("authtype") : headers.indexOf("auth_type");
  const studentIdIndex = headers.indexOf("studentid") !== -1 ? headers.indexOf("studentid") : headers.indexOf("student_id");

  // Parse data rows
  const users: BulkImportUser[] = [];

  for (let i = 1; i < lines.length; i++) {
    const line = lines[i].trim();
    if (!line) continue; // Skip empty lines

    const values = line.split(",").map(v => v.trim());

    const email = values[emailIndex];
    const displayName = values[nameIndex];

    if (!email || !displayName) {
      throw new Error(`Row ${i + 1}: Missing required data (name or email)`);
    }

    const userObj: BulkImportUser = {
      email: email.toLowerCase(),
      displayName: displayName,
      gradeLevel: gradeIndex !== -1 ? values[gradeIndex] : undefined,
      parentEmail: parentEmailIndex !== -1 ? values[parentEmailIndex] : undefined,
      isGoogleAuth: authTypeIndex !== -1 ? values[authTypeIndex]?.toLowerCase() === "google" : false,
    };

    // Add class IDs if present (can be semicolon-separated list)
    if (classIdsIndex !== -1 && values[classIdsIndex]) {
      userObj.classIds = values[classIdsIndex].split(';').map(id => id.trim());
    }

    // Add enrollment code if present
    if (enrollmentCodeIndex !== -1 && values[enrollmentCodeIndex]) {
      userObj.enrollmentCode = values[enrollmentCodeIndex];
    }

    // Add student ID if present
    if (studentIdIndex !== -1 && values[studentIdIndex]) {
      userObj.studentId = values[studentIdIndex];
    }

    users.push(userObj);
  }

  return users;
}

/**
 * Generate a temporary password hash
 * This will be immediately invalidated by sending a password reset email
 */
function generateTempPasswordHash(): string {
  // Generate a random bcrypt hash for a temporary password
  // This is just a placeholder since we'll send password reset emails
  return "$2b$10$" + randomString(53);
}

/**
 * Generate a salt for password hashing
 */
function generateSalt(): string {
  return randomString(16);
}

/**
 * Generate a random string for password hashing
 */
function randomString(length: number): string {
  const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
  let result = "";
  for (let i = 0; i < length; i++) {
    result += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return result;
}

/**
 * Generate a unique UID for Firebase Auth users
 * Firebase UIDs are typically 28 characters long
 */
function generateUid(): string {
  return randomString(28);
}

/**
 * Migration function to fix students with className instead of classId
 * This fixes the data structure for students created before the enrollment code fix
 */
export const migrateStudentClassEnrollment = onCall(
  {
    region: "us-east4",
    maxInstances: 10,
    memory: "256MiB",
    timeoutSeconds: 60,
  },
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

    logger.info("Starting student class enrollment migration");

    try {
      // Find all students with className field but no classId
      const studentsSnapshot = await db.collection("users")
        .where("role", "==", "student")
        .get();

      const migrationResults = {
        total: 0,
        migrated: 0,
        failed: 0,
        errors: [] as string[],
      };

      migrationResults.total = studentsSnapshot.size;

      // Get all classes for lookup
      const classesSnapshot = await db.collection("classes").get();
      const classNameToId = new Map<string, string>();
      const classIdToName = new Map<string, string>();

      classesSnapshot.forEach(doc => {
        const data = doc.data();
        if (data.name) {
          classNameToId.set(data.name.toLowerCase(), doc.id);
          classIdToName.set(doc.id, data.name);
        }
      });

      // Process each student
      const batch = db.batch();
      const classStudentUpdates = new Map<string, string[]>();

      for (const studentDoc of studentsSnapshot.docs) {
        const studentData = studentDoc.data();

        // Skip if already has classId
        if (studentData.classId) {
          continue;
        }

        // Check if has className that needs migration
        if (studentData.className) {
          const className = studentData.className.toLowerCase();
          const classId = classNameToId.get(className);

          if (classId) {
            // Update student document
            const studentRef = db.collection("users").doc(studentDoc.id);
            batch.update(studentRef, {
              classId: classId,
              enrolledClasses: [classId],
              className: admin.firestore.FieldValue.delete(), // Remove old field
            });

            // Track for class update
            if (!classStudentUpdates.has(classId)) {
              classStudentUpdates.set(classId, []);
            }
            classStudentUpdates.get(classId)!.push(studentDoc.id);

            migrationResults.migrated++;
            logger.info(`Migrating student ${studentData.email} to class ${classIdToName.get(classId)}`);
          } else {
            migrationResults.failed++;
            migrationResults.errors.push(`No class found for className: ${studentData.className}`);
          }
        }
      }

      // Commit student updates
      if (migrationResults.migrated > 0) {
        await batch.commit();

        // Update class documents with student IDs
        const classUpdatePromises = [];
        for (const [classId, studentIds] of classStudentUpdates.entries()) {
          const classRef = db.collection("classes").doc(classId);
          const updatePromise = classRef.update({
            studentIds: admin.firestore.FieldValue.arrayUnion(...studentIds),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          classUpdatePromises.push(updatePromise);
          logger.info(`Adding ${studentIds.length} students to class ${classId}`);
        }

        await Promise.all(classUpdatePromises);
      }

      logger.info(`Migration completed: ${migrationResults.migrated} students migrated, ${migrationResults.failed} failed`);

      return {
        success: true,
        message: `Migration completed: ${migrationResults.migrated} students migrated`,
        results: migrationResults,
      };

    } catch (error) {
      logger.error("Error during migration:", error);
      throw new HttpsError("internal", `Migration failed: ${error}`);
    }
  }
);