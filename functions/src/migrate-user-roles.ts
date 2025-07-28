import * as admin from "firebase-admin";

/**
 * Migration script to set custom claims for all existing users
 * This script should be run once after deploying the Cloud Functions
 * to ensure all existing users have the correct custom claims set.
 */

// Initialize Firebase Admin
admin.initializeApp();

async function migrateUserRoles() {
  console.log("Starting user role migration...");
  
  const firestore = admin.firestore();
  const auth = admin.auth();
  
  try {
    // Get all users from Firestore
    const usersSnapshot = await firestore.collection("users").get();
    
    console.log(`Found ${usersSnapshot.size} users to migrate`);
    
    let successCount = 0;
    let errorCount = 0;
    
    // Process each user
    for (const doc of usersSnapshot.docs) {
      const userId = doc.id;
      const userData = doc.data();
      const role = userData.role;
      
      if (!role || !["teacher", "student"].includes(role)) {
        console.warn(`User ${userId} has invalid or missing role: ${role}`);
        errorCount++;
        continue;
      }
      
      try {
        // Set custom claim for the user
        await auth.setCustomUserClaims(userId, { role });
        console.log(`✓ Set custom claim for user ${userId} with role: ${role}`);
        successCount++;
      } catch (error) {
        console.error(`✗ Error setting custom claim for user ${userId}:`, error);
        errorCount++;
      }
    }
    
    console.log("\nMigration completed!");
    console.log(`Success: ${successCount} users`);
    console.log(`Errors: ${errorCount} users`);
    
    // List users without roles
    const usersWithoutRoles = usersSnapshot.docs.filter(doc => {
      const role = doc.data().role;
      return !role || !["teacher", "student"].includes(role);
    });
    
    if (usersWithoutRoles.length > 0) {
      console.log("\nUsers without valid roles:");
      usersWithoutRoles.forEach(doc => {
        console.log(`- ${doc.id}: role = ${doc.data().role || "undefined"}`);
      });
    }
    
  } catch (error) {
    console.error("Error during migration:", error);
    process.exit(1);
  }
  
  process.exit(0);
}

// Run the migration
migrateUserRoles();