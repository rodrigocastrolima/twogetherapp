import { HttpsError, onCall, CallableRequest } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";

// Initialize Firebase Admin SDK (if not already done)
try {
  if (admin.apps.length === 0) {
    admin.initializeApp();
    logger.info("Firebase Admin SDK initialized in userManagement.");
  }
} catch (e) {
  logger.info("Firebase Admin SDK already initialized.");
}

// --- Interfaces ---

interface CreateUserParams {
  email: string;
  password: string;
  role: string;
  firestoreData: Record<string, any>;
}

interface CreateUserResult {
  uid: string;
}

interface DeleteUserParams {
  uid: string;
}

interface DeleteUserResult {
  success: boolean;
}

// --- Admin Check Helper ---

async function assertAdmin(request: CallableRequest<any>) {
  if (!request.auth) {
    logger.error("Authentication failed: User is not authenticated.");
    throw new HttpsError("unauthenticated", "User must be authenticated.");
  }
  const adminUid = request.auth.uid;
  logger.info("Authenticated user (Admin):", { uid: adminUid });

  try {
    const userDoc = await admin.firestore().collection('users').doc(adminUid).get();
    if (!userDoc.exists || userDoc.data()?.role !== 'admin') {
      logger.error("Authorization failed: User is not an admin.", { uid: adminUid });
      throw new HttpsError("permission-denied", "User does not have permission.");
    }
    logger.info("User authorized as Admin.", { uid: adminUid });
  } catch (dbError: any) {
    logger.error("Error fetching admin user document:", { uid: adminUid, error: dbError });
    throw new HttpsError("internal", "Failed to verify user permissions.");
  }
}

// --- Cloud Function: Create User ---

export const createUserWithFirestore = onCall(
  {
    timeoutSeconds: 30,
    memory: "256MiB",
    region: "us-central1",
    // enforceAppCheck: true, // Enable in production
  },
  async (request: CallableRequest<CreateUserParams>): Promise<CreateUserResult> => {
    logger.info("createUserWithFirestore function triggered");

    await assertAdmin(request);

    const { email, password, role, firestoreData } = request.data;

    if (!email || !password || !role) {
      logger.error("Validation failed: Missing required fields (email, password, role)");
      throw new HttpsError("invalid-argument", "Missing required fields.");
    }

    // 1. Create Auth user
    const userRecord = await admin.auth().createUser({
      email,
      password,
      emailVerified: false,
      disabled: false,
    });

    // 2. Set custom claims (optional, if you use them)
    await admin.auth().setCustomUserClaims(userRecord.uid, { role });

    // 3. Create Firestore user doc
    await admin.firestore().collection("users").doc(userRecord.uid).set({
      uid: userRecord.uid,
      email,
      role,
      ...firestoreData,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      isFirstLogin: true,
      isActive: true,
      isEnabled: true,
    });

    logger.info("User created successfully", { uid: userRecord.uid });
    return { uid: userRecord.uid };
  }
);

// --- Cloud Function: Delete User ---

export const deleteUserAndFirestore = onCall(
  {
    timeoutSeconds: 30,
    memory: "256MiB",
    region: "us-central1",
    // enforceAppCheck: true, // Enable in production
  },
  async (request: CallableRequest<DeleteUserParams>): Promise<DeleteUserResult> => {
    logger.info("deleteUserAndFirestore function triggered");

    await assertAdmin(request);

    const { uid } = request.data;
    if (!uid) {
      logger.error("Validation failed: Missing UID.");
      throw new HttpsError("invalid-argument", "Missing UID.");
    }

    // 1. Delete Auth user
    await admin.auth().deleteUser(uid);

    // 2. Delete Firestore user doc
    await admin.firestore().collection("users").doc(uid).delete();

    logger.info("User deleted successfully", { uid });
    return { success: true };
  }
); 