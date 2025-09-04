const admin = require('firebase-admin');

// Initialize admin SDK with service account
const serviceAccount = require('../path-to-service-account-key.json'); // You need to download this from Firebase Console

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'teacher-dashboard-flutterfire'
});

const auth = admin.auth();
const db = admin.firestore();

async function createTestStudent() {
  const username = 'teststudent';
  const password = 'Test123!';
  const syntheticEmail = `${username}@students.fermi-app.local`;
  
  console.log('Creating test student account...');
  console.log(`Username: ${username}`);
  console.log(`Password: ${password}`);
  console.log(`Synthetic Email: ${syntheticEmail}`);
  
  try {
    // Step 1: Create Firebase Auth user
    let userRecord;
    try {
      userRecord = await auth.createUser({
        email: syntheticEmail,
        password: password,
        displayName: 'Test Student',
        emailVerified: true // Auto-verify for testing
      });
      console.log('✅ Created new Firebase Auth user with UID:', userRecord.uid);
    } catch (error) {
      if (error.code === 'auth/email-already-exists') {
        // User exists, get their UID
        userRecord = await auth.getUserByEmail(syntheticEmail);
        console.log('⚠️ Auth user already exists with UID:', userRecord.uid);
        
        // Update password to ensure it matches
        await auth.updateUser(userRecord.uid, {
          password: password
        });
        console.log('✅ Updated password for existing user');
      } else {
        throw error;
      }
    }
    
    // Step 2: Create/Update Firestore document with MATCHING UID
    const userData = {
      uid: userRecord.uid, // THIS MUST MATCH THE AUTH UID
      username: username,
      role: 'student',
      firstName: 'Test',
      lastName: 'Student',
      displayName: 'Test Student',
      email: syntheticEmail,
      realEmail: null,
      hasLinkedEmail: false,
      profileCompleted: true,
      photoURL: null,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      lastActive: admin.firestore.FieldValue.serverTimestamp()
    };
    
    // Use the AUTH UID as the document ID to ensure they match
    await db.collection('users').doc(userRecord.uid).set(userData);
    console.log('✅ Created/Updated Firestore document with matching UID');
    
    console.log('\n✨ Test student account created successfully!');
    console.log('====================================');
    console.log(`Username: ${username}`);
    console.log(`Password: ${password}`);
    console.log(`UID: ${userRecord.uid}`);
    console.log('====================================');
    console.log('\nYou can now login with these credentials in the app.');
    
  } catch (error) {
    console.error('❌ Error creating test student:', error);
    process.exit(1);
  }
  
  process.exit(0);
}

// Run the function
createTestStudent();