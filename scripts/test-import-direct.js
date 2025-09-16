// Direct test of bulk import function using Firebase Admin SDK
const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
const serviceAccountPath = path.join(__dirname, '../serviceAccount.json');

// Check if service account file exists
if (!fs.existsSync(serviceAccountPath)) {
  console.error('Service account file not found at:', serviceAccountPath);
  console.log('Please create serviceAccount.json in the root directory');
  console.log('Download it from Firebase Console > Project Settings > Service Accounts');
  process.exit(1);
}

const serviceAccount = require(serviceAccountPath);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: `https://${serviceAccount.project_id}.firebaseio.com`
});

const auth = admin.auth();
const db = admin.firestore();

// Generate a random 28-character UID
function generateUid() {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  let result = '';
  for (let i = 0; i < 28; i++) {
    result += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return result;
}

async function testDirectImport() {
  try {
    console.log('Starting direct bulk import test...\n');

    // Read the student data
    const studentsPath = 'C:\\Users\\frank\\Downloads\\roselle_students.json';
    if (!fs.existsSync(studentsPath)) {
      console.error('Students JSON file not found at:', studentsPath);
      process.exit(1);
    }

    const studentsData = JSON.parse(fs.readFileSync(studentsPath, 'utf-8'));
    console.log(`Loaded ${studentsData.length} students from JSON file\n`);

    // Check for existing users first
    console.log('Checking for existing users...');
    const existingEmails = [];
    const newUsers = [];

    for (const student of studentsData) {
      try {
        await auth.getUserByEmail(student.email);
        existingEmails.push(student.email);
      } catch (error) {
        if (error.code === 'auth/user-not-found') {
          newUsers.push(student);
        }
      }
    }

    console.log(`Found ${existingEmails.length} existing users`);
    console.log(`Will import ${newUsers.length} new users\n`);

    if (newUsers.length === 0) {
      console.log('All users already exist. Nothing to import.');
      process.exit(0);
    }

    // Prepare users for import with UIDs
    const userUidMap = new Map();
    const importUsers = newUsers.map(student => {
      const uid = generateUid();
      userUidMap.set(student.email, uid);

      return {
        uid: uid,
        email: student.email,
        displayName: student.displayName,
        emailVerified: true,
        disabled: false,
        customClaims: {
          role: 'student',
          gradeLevel: student.gradeLevel
        }
      };
    });

    // Perform bulk import
    console.log(`Importing ${importUsers.length} new students...`);

    const importResult = await auth.importUsers(importUsers, {
      hash: {
        algorithm: 'BCRYPT'
      }
    });

    console.log(`\nImport Result:`);
    console.log(`  - Success: ${importResult.successCount}`);
    console.log(`  - Failures: ${importResult.failureCount}\n`);

    if (importResult.errors && importResult.errors.length > 0) {
      console.log('Import errors:');
      importResult.errors.forEach(error => {
        console.log(`  - Index ${error.index}: ${error.error.message}`);
      });
    }

    // Create Firestore documents for successfully imported users
    if (importResult.successCount > 0) {
      console.log('Creating Firestore documents...');

      const batch = db.batch();
      const timestamp = admin.firestore.FieldValue.serverTimestamp();
      const classStudentMap = new Map();

      for (const student of newUsers) {
        const uid = userUidMap.get(student.email);
        if (!uid) continue;

        // Create user document
        const userRef = db.collection('users').doc(uid);
        const userDocData = {
          email: student.email,
          displayName: student.displayName,
          role: 'student',
          gradeLevel: String(student.gradeLevel),
          parentEmail: student.parentEmail || null,
          createdAt: timestamp,
          createdBy: 'bulk_import_script',
          isEmailUser: !student.isGoogleAuth,
          isGoogleAuth: student.isGoogleAuth || false,
          profileComplete: false,
          studentId: student.studentId || null
        };

        // Add class information
        if (student.classIds && student.classIds.length > 0) {
          userDocData.classId = student.classIds[0]; // Primary class
          userDocData.enrolledClasses = student.classIds; // All classes

          // Track for class updates
          if (!classStudentMap.has(student.classIds[0])) {
            classStudentMap.set(student.classIds[0], []);
          }
          student.classIds.forEach(classId => {
            if (!classStudentMap.has(classId)) {
              classStudentMap.set(classId, []);
            }
            classStudentMap.get(classId).push(uid);
          });
        }

        batch.set(userRef, userDocData);
      }

      await batch.commit();
      console.log('Firestore documents created successfully\n');

      // Update class documents with student IDs
      if (classStudentMap.size > 0) {
        console.log('Updating class enrollments...');

        for (const [classId, studentIds] of classStudentMap.entries()) {
          try {
            const classRef = db.collection('classes').doc(classId);
            await classRef.update({
              studentIds: admin.firestore.FieldValue.arrayUnion(...studentIds),
              updatedAt: timestamp
            });
            console.log(`  Added ${studentIds.length} students to class ${classId}`);
          } catch (error) {
            console.error(`  Error updating class ${classId}:`, error.message);
          }
        }
      }
    }

    // Verify results
    console.log('\n=== VERIFICATION ===\n');

    // Check a few users in Auth
    console.log('Checking imported users in Firebase Auth:');
    const sampleUsers = newUsers.slice(0, 3);
    for (const user of sampleUsers) {
      try {
        const authUser = await auth.getUserByEmail(user.email);
        console.log(`  ✓ ${user.email} (UID: ${authUser.uid})`);
      } catch (error) {
        console.log(`  ✗ ${user.email} - Not found`);
      }
    }

    // Check classes
    console.log('\nChecking class enrollments:');
    const classIds = new Set();
    studentsData.forEach(s => s.classIds?.forEach(id => classIds.add(id)));

    for (const classId of Array.from(classIds).slice(0, 3)) {
      const classDoc = await db.collection('classes').doc(classId).get();
      if (classDoc.exists) {
        const data = classDoc.data();
        console.log(`  Class ${data.name || classId}: ${data.studentIds?.length || 0} students`);
      }
    }

    console.log('\n=== IMPORT COMPLETE ===\n');
    console.log(`Successfully imported ${importResult.successCount} students`);

  } catch (error) {
    console.error('Error during import:', error);
    process.exit(1);
  }
}

// Run the test
testDirectImport().then(() => {
  console.log('\nTest completed');
  process.exit(0);
}).catch(error => {
  console.error('Test failed:', error);
  process.exit(1);
});