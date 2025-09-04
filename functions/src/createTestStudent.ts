import * as admin from "firebase-admin";
import {onCall} from "firebase-functions/v2/https";

// Initialize Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

export const createTestStudent = onCall(async (request) => {
  // Set a default test password - matching what user expects
  const testPassword = "Test123!";
  
  // Generate a unique UID for this test student
  const testUid = admin.firestore().collection("users").doc().id;
  
  const studentData = {
    // Required fields from your specifications
    uid: testUid,
    username: "teststudent",
    role: "student",
    firstName: "Test",
    lastName: "Student",
    displayName: "Test Student",
    
    // Profile and email fields - using the synthetic email pattern for students
    profileCompleted: true,
    email: "teststudent@students.fermi-app.local",
    realEmail: null,
    hasLinkedEmail: false,
    photoURL: null,
    
    // Timestamps
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    lastActive: admin.firestore.FieldValue.serverTimestamp(),
  };

  try {
    // First, create the Firebase Auth user
    try {
      await admin.auth().createUser({
        uid: testUid,
        email: studentData.email,
        password: testPassword,
        displayName: studentData.displayName,
        emailVerified: true, // Set as verified for testing
      });
      console.log("✅ Auth user created");
    } catch (authError: any) {
      if (authError.code === 'auth/uid-already-exists') {
        console.log("⚠️ Auth user already exists, updating password...");
        // Update the existing user's password
        await admin.auth().updateUser(testUid, {
          password: testPassword,
        });
      } else {
        throw authError;
      }
    }
    
    // Then create/update the Firestore document
    await db.collection("users").doc(testUid).set(studentData);
    
    console.log("✅ Test student created successfully!");
    
    return { 
      success: true, 
      credentials: {
        username: studentData.username,
        password: testPassword,
        uid: testUid,
        role: studentData.role,
        displayName: studentData.displayName,
        email: studentData.email,
      },
      message: `Test student created! Login with username: ${studentData.username} and password: ${testPassword}`
    };
  } catch (error) {
    console.error("❌ Error creating test student:", error);
    throw error;
  }
});