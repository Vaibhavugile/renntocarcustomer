const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {initializeApp} = require("firebase-admin/app");
const {
  getAuth,
} = require("firebase-admin/auth");
const {
  getFirestore,
  FieldValue,
} = require("firebase-admin/firestore");

initializeApp();

const auth = getAuth();
const db = getFirestore();

exports.createCustomer = onCall(async (request) => {
  // ---------------------------------------------------------
  // 1. Verify caller is authenticated
  // ---------------------------------------------------------
  if (!request.auth) {
    throw new HttpsError(
        "unauthenticated",
        "You must be logged in to create a customer.",
    );
  }

  const callerUid = request.auth.uid;

  // ---------------------------------------------------------
  // 2. Validate request
  // ---------------------------------------------------------
  const data = request.data || {};

  const tenantId = String(data.tenantId || "").trim();
  const fullName = String(data.fullName || "").trim();
  const phone = String(data.phone || "").trim();
  const email = String(data.email || "").trim();

  if (!tenantId) {
    throw new HttpsError(
        "invalid-argument",
        "tenantId is required.",
    );
  }

  if (!fullName) {
    throw new HttpsError(
        "invalid-argument",
        "Customer name is required.",
    );
  }

  if (!phone) {
    throw new HttpsError(
        "invalid-argument",
        "Customer phone number is required.",
    );
  }

  // ---------------------------------------------------------
  // 3. Verify tenant exists
  // ---------------------------------------------------------
  const tenantRef = db.collection("tenants").doc(tenantId);
  const tenantSnap = await tenantRef.get();

  if (!tenantSnap.exists) {
    throw new HttpsError(
        "not-found",
        "Tenant does not exist.",
    );
  }

  // ---------------------------------------------------------
  // 4. Verify caller is an active admin
  // ---------------------------------------------------------
  const adminRef = tenantRef
      .collection("admins")
      .doc(callerUid);

  const adminSnap = await adminRef.get();

  if (!adminSnap.exists) {
    throw new HttpsError(
        "permission-denied",
        "You are not an admin of this tenant.",
    );
  }

  const adminData = adminSnap.data() || {};

  if (adminData.isActive !== true) {
    throw new HttpsError(
        "permission-denied",
        "Your admin account is inactive.",
    );
  }

  // ---------------------------------------------------------
  // 5. Check duplicate customer by phone
  // ---------------------------------------------------------
  const customersRef = tenantRef.collection("customers");

  const existingSnapshot = await customersRef
      .where("phone", "==", phone)
      .limit(1)
      .get();

  if (!existingSnapshot.empty) {
    const existingDoc = existingSnapshot.docs[0];

    throw new HttpsError(
        "already-exists",
        "A customer with this phone number already exists.",
        {
          customerId: existingDoc.id,
        },
    );
  }

  // ---------------------------------------------------------
  // 6. Create Firebase Authentication user
  // ---------------------------------------------------------
  let firebaseUser;

  try {
    firebaseUser = await auth.createUser({
      phoneNumber: phone,
      ...(email ? {email} : {}),
      displayName: fullName,
      disabled: false,
    });
  } catch (error) {
    console.error("Firebase Auth user creation failed:", error);

    if (error.code === "auth/phone-number-already-exists") {
      throw new HttpsError(
          "already-exists",
          "A Firebase user with this phone number already exists.",
      );
    }

    if (error.code === "auth/invalid-phone-number") {
      throw new HttpsError(
          "invalid-argument",
          "The phone number is invalid. Use +91",
      );
    }

    if (error.code === "auth/email-already-exists") {
      throw new HttpsError(
          "already-exists",
          "This email is already associated with another Firebase user.",
      );
    }

    throw new HttpsError(
        "internal",
        "Unable to create Firebase customer account.",
    );
  }

  const uid = firebaseUser.uid;

  // ---------------------------------------------------------
  // 7. Create customer Firestore document
  // ---------------------------------------------------------
  const customerRef = customersRef.doc(uid);

  try {
    await customerRef.set({
      customerId: uid,
      tenantId: tenantId,

      fullName: fullName,
      phone: phone,
      email: email,

      profileImageUrl: "",
      dateOfBirth: "",
      gender: "",

      address: null,
      emergencyContact: null,

      kycStatus: "not_started",
      profileCompleted: false,
      isActive: true,

      totalBookings: 0,
      completedBookings: 0,

      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),

      createdByAdminId: callerUid,
      createdByAdminName: adminData.name || "",
    });

    // -------------------------------------------------------
    // 8. Return success
    // -------------------------------------------------------
    return {
      success: true,
      customerId: uid,
      firebaseUid: uid,
      tenantId: tenantId,
      message: "Customer created successfully.",
    };
  } catch (error) {
    console.error(
        "Customer Firestore creation failed:",
        error,
    );

    // -------------------------------------------------------
    // IMPORTANT:
    // If Firestore creation fails after Auth user creation,
    // remove the Auth user so we don't leave an orphan user.
    // -------------------------------------------------------
    try {
      await auth.deleteUser(uid);
    } catch (deleteError) {
      console.error(
          "Failed to rollback Firebase Auth user:",
          deleteError,
      );
    }

    throw new HttpsError(
        "internal",
        "Customer account could not be created.",
    );
  }
});
