// Test script for bulk import of students
const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
const serviceAccountPath = path.join(__dirname, '../serviceAccount.json');

// Check if service account file exists
if (!fs.existsSync(serviceAccountPath)) {
  console.error('Service account file not found at:', serviceAccountPath);
  console.log('Please ensure the serviceAccount.json file is in the root directory');
  process.exit(1);
}

const serviceAccount = require(serviceAccountPath);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: `https://${serviceAccount.project_id}.firebaseio.com`
});

const functions = admin.functions();
const db = admin.firestore();

async function testBulkImport() {
  try {
    console.log('Starting bulk import test...\n');

    // Read the student data
    const studentsPath = 'C:\\Users\\frank\\Downloads\\roselle_students.json';
    if (!fs.existsSync(studentsPath)) {
      console.error('Students JSON file not found at:', studentsPath);
      process.exit(1);
    }

    const studentsData = JSON.parse(fs.readFileSync(studentsPath, 'utf-8'));
    console.log(`Loaded ${studentsData.length} students from JSON file\n`);

    // Verify we have admin user to authenticate the call
    console.log('Checking admin authentication...');

    // Get an admin user's custom token to authenticate the function call
    // For testing, we'll create a custom token for the admin user
    const adminUid = 'jpgosZLAzoN5m3YPa8gm5nVTPLf2'; // Replace with actual admin UID if different

    const customToken = await admin.auth().createCustomToken(adminUid, {
      role: 'admin'
    });

    console.log('Admin token created successfully\n');

    // Prepare the function call
    const functionUrl = `https://us-east4-${serviceAccount.project_id}.cloudfunctions.net/bulkImportStudents`;

    console.log('Calling bulk import function...');
    console.log('Function URL:', functionUrl);
    console.log(`Importing ${studentsData.length} students...\n`);

    // Call the function using fetch
    const response = await fetch(functionUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${customToken}`
      },
      body: JSON.stringify({
        data: {
          users: studentsData,
          sendPasswordResetEmails: false // Set to true if you want to send emails
        }
      })
    });

    if (!response.ok) {
      const errorText = await response.text();
      console.error('Function call failed:', response.status, errorText);
      process.exit(1);
    }

    const result = await response.json();

    // Display results
    console.log('\n=== IMPORT RESULTS ===\n');

    if (result.result && result.result.summary) {
      const summary = result.result.summary;
      console.log('Summary:');
      console.log(`  - Attempted: ${summary.attempted}`);
      console.log(`  - Imported: ${summary.imported}`);
      console.log(`  - Failed: ${summary.failed}`);
      console.log(`  - Already Existing: ${summary.alreadyExisting}\n`);
    }

    if (result.result && result.result.imported && result.result.imported.length > 0) {
      console.log(`Successfully imported ${result.result.imported.length} students:`);
      result.result.imported.slice(0, 5).forEach(user => {
        console.log(`  - ${user.email} (UID: ${user.uid})`);
      });
      if (result.result.imported.length > 5) {
        console.log(`  ... and ${result.result.imported.length - 5} more\n`);
      }
    }

    if (result.result && result.result.failed && result.result.failed.length > 0) {
      console.log(`\nFailed to import ${result.result.failed.length} students:`);
      result.result.failed.forEach(user => {
        console.log(`  - ${user.email}: ${user.error}`);
      });
    }

    if (result.result && result.result.alreadyExisting && result.result.alreadyExisting.length > 0) {
      console.log(`\n${result.result.alreadyExisting.length} students already exist:`);
      result.result.alreadyExisting.slice(0, 5).forEach(email => {
        console.log(`  - ${email}`);
      });
      if (result.result.alreadyExisting.length > 5) {
        console.log(`  ... and ${result.result.alreadyExisting.length - 5} more`);
      }
    }

    // Verify class assignments
    console.log('\n=== VERIFYING CLASS ASSIGNMENTS ===\n');

    // Get unique class IDs from the imported data
    const classIds = new Set();
    studentsData.forEach(student => {
      if (student.classIds) {
        student.classIds.forEach(id => classIds.add(id));
      }
    });

    console.log(`Checking ${classIds.size} classes for student enrollments...\n`);

    for (const classId of classIds) {
      const classDoc = await db.collection('classes').doc(classId).get();
      if (classDoc.exists) {
        const classData = classDoc.data();
        const studentCount = classData.studentIds ? classData.studentIds.length : 0;
        console.log(`  Class ${classData.name || classId}: ${studentCount} students enrolled`);
      } else {
        console.log(`  Class ${classId}: NOT FOUND`);
      }
    }

    console.log('\n=== IMPORT TEST COMPLETE ===\n');

  } catch (error) {
    console.error('Error during bulk import test:', error);
    process.exit(1);
  }
}

// Run the test
testBulkImport().then(() => {
  console.log('Test completed successfully');
  process.exit(0);
}).catch(error => {
  console.error('Test failed:', error);
  process.exit(1);
});