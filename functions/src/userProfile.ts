import {beforeUserCreated, beforeUserSignedIn} from "firebase-functions/v2/identity";
import * as admin from "firebase-admin";
import {logger} from "firebase-functions/v2";

/**
 * Handle user creation before they are saved to Firebase Auth.
 * This creates the user profile in Firestore and sets custom claims.
 * Runs BEFORE the user is actually created in Firebase Auth.
 */
export const handleUserCreation = beforeUserCreated(
  {
    region: "us-east4",
    // Set reasonable limits for Gen2
    timeoutSeconds: 10,
    memory: "256MiB",
  },
  async (event) => {
    const user = event.data;
    
    // Check if user data exists
    if (!user) {
      logger.error("No user data in beforeUserCreated event");
      return;
    }

    const {uid, email, displayName, photoURL, emailVerified} = user;

    logger.info(`Processing user creation for ${uid} (${email})`);

    try {
      // Check if profile already exists (shouldn't happen in beforeUserCreated)
      const userDoc = await admin.firestore()
        .collection("users")
        .doc(uid)
        .get();

      if (userDoc.exists) {
        logger.warn(`User profile already exists for ${uid} during creation`);
        // Don't block creation, just skip profile creation
        return;
      }

      // Determine role based on sign-in method
      let role: string | null = 'student'; // Default role

      // Check provider data to determine role
      const providers = user.providerData || [];
      const isGoogleProvider = providers.some(
        (provider) => provider.providerId === 'google.com'
      );
      const isAppleProvider = providers.some(
        (provider) => provider.providerId === 'apple.com'
      );

      // Check custom providers (from event context)
      const customProviders = event.data?.customClaims?.providers || [];
      const hasGoogleInCustom = customProviders.includes('google.com');

      // Teachers use Google Sign-In, students typically use email/password
      if (isGoogleProvider || hasGoogleInCustom) {
        role = 'teacher';
        logger.info(`Google Sign-In detected for ${uid}, assigning teacher role`);
      } else if (isAppleProvider) {
        // For Apple Sign-In, default to null to trigger role selection
        logger.info(`Apple Sign-In detected for ${uid}, role selection required`);
        role = null;
      } else {
        // Email/password sign-in defaults to student
        logger.info(`Email/password sign-in detected for ${uid}, assigning student role`);
      }

      // Parse name from displayName
      const nameParts = displayName?.split(' ') || [];
      const firstName = nameParts[0] || '';
      const lastName = nameParts.slice(1).join(' ') || '';

      // Create username from email
      const username = email?.split('@')[0] || `user_${Date.now()}`;

      // Create user profile document
      const userProfileData: any = {
        uid,
        email: email || '',
        username: username.toLowerCase(),
        firstName,
        lastName,
        displayName: displayName || '',
        photoURL: photoURL || '',
        emailVerified: emailVerified || false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        lastActive: admin.firestore.FieldValue.serverTimestamp(),
        isActive: true,
      };

      // Only set role if it was determined
      if (role !== null) {
        userProfileData.role = role;
      }

      // Create the profile document
      await admin.firestore().collection('users').doc(uid).set(userProfileData);
      logger.info(`Successfully created profile for ${uid} with role ${role || 'pending'}`);

      // Create username mapping for login lookups
      if (username && !username.startsWith('user_')) {
        try {
          await admin.firestore()
            .collection('public_usernames')
            .doc(username.toLowerCase())
            .set({
              uid,
              role: role || 'pending',
              createdAt: admin.firestore.FieldValue.serverTimestamp(),
            });
          logger.info(`Created username mapping for ${username}`);
        } catch (error) {
          // Don't fail the whole process if username mapping fails
          logger.warn(`Failed to create username mapping for ${username}:`, error);
        }
      }

      // Return custom claims to be set on the user
      if (role) {
        return {
          customClaims: {
            role: role
          }
        };
      }

      // Return empty object if no role set
      return {};

    } catch (error) {
      logger.error(`Failed to create profile for ${uid}:`, error);
      // Don't throw - let user be created but log the error
      // The beforeUserSignedIn function will attempt to create profile as fallback
      return {};
    }
  }
);

/**
 * Handle user sign-in after credentials are verified.
 * This ensures the profile exists and updates last active timestamp.
 * Runs on EVERY sign-in, including the first one after account creation.
 */
export const handleUserSignIn = beforeUserSignedIn(
  {
    region: "us-east4",
    timeoutSeconds: 10,
    memory: "256MiB",
  },
  async (event) => {
    const user = event.data;
    
    // Check if user data exists
    if (!user) {
      logger.error("No user data in beforeUserSignedIn event");
      return;
    }

    const {uid, email, displayName, photoURL} = user;

    logger.info(`Processing sign-in for ${uid} (${email})`);

    try {
      // Check if user profile exists
      const userDoc = await admin.firestore()
        .collection('users')
        .doc(uid)
        .get();

      let userData = userDoc.data();
      let role = userData?.role;

      // If profile doesn't exist, create it (fallback for any edge cases)
      if (!userDoc.exists) {
        logger.warn(`Profile missing during sign-in for ${uid}, creating now`);

        // Determine role based on provider
        const providers = user.providerData || [];
        const isGoogleProvider = providers.some(
          (provider) => provider.providerId === 'google.com'
        );
        const isAppleProvider = providers.some(
          (provider) => provider.providerId === 'apple.com'
        );

        if (isGoogleProvider) {
          role = 'teacher';
        } else if (isAppleProvider) {
          role = null; // Needs role selection
        } else {
          role = 'student';
        }

        // Parse name
        const nameParts = displayName?.split(' ') || [];
        const firstName = nameParts[0] || '';
        const lastName = nameParts.slice(1).join(' ') || '';
        const username = email?.split('@')[0] || `user_${Date.now()}`;

        // Create profile
        const userProfileData: any = {
          uid,
          email: email || '',
          username: username.toLowerCase(),
          firstName,
          lastName,
          displayName: displayName || '',
          photoURL: photoURL || '',
          emailVerified: user.emailVerified || false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          lastActive: admin.firestore.FieldValue.serverTimestamp(),
          isActive: true,
        };

        if (role) {
          userProfileData.role = role;
        }

        await admin.firestore().collection('users').doc(uid).set(userProfileData);
        logger.info(`Created missing profile for ${uid} with role ${role || 'pending'}`);

        // Create username mapping
        if (username && !username.startsWith('user_')) {
          try {
            await admin.firestore()
              .collection('public_usernames')
              .doc(username.toLowerCase())
              .set({
                uid,
                role: role || 'pending',
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
              });
          } catch (error) {
            logger.warn(`Failed to create username mapping:`, error);
          }
        }
      } else {
        // Profile exists - validate and update

        // Check provider consistency for existing users
        const providers = user.providerData || [];
        const isGoogleProvider = providers.some(
          (provider) => provider.providerId === 'google.com'
        );

        // If signing in with Google but role is not teacher, update it
        if (isGoogleProvider && role && role !== 'teacher') {
          logger.warn(`Role mismatch for Google Sign-In user ${uid}: has role ${role}, updating to teacher`);
          
          await admin.firestore()
            .collection('users')
            .doc(uid)
            .update({
              role: 'teacher',
              lastActive: admin.firestore.FieldValue.serverTimestamp(),
            });
          
          role = 'teacher';
        } else {
          // Just update last active timestamp
          await admin.firestore()
            .collection('users')
            .doc(uid)
            .update({
              lastActive: admin.firestore.FieldValue.serverTimestamp(),
            })
            .catch((error) => {
              logger.warn(`Failed to update last active for ${uid}:`, error);
            });
        }
      }

      // Set custom claims if we have a role
      if (role) {
        // Set custom claims on the token
        return {
          customClaims: {
            role: role
          },
          sessionClaims: {
            role: role
          }
        };
      }
      
      // Return empty object if no role
      return {};

    } catch (error) {
      logger.error(`Error in handleUserSignIn for ${uid}:`, error);
      // Don't block sign-in on errors
      return {};
    }
  }
);