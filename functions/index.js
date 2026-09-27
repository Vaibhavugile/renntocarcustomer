const {
  onCall,
  HttpsError,
} = require("firebase-functions/v2/https");

const {
  initializeApp,
} = require("firebase-admin/app");

const {
  getAuth,
} = require("firebase-admin/auth");

const {
  getFirestore,
  FieldValue,
} = require("firebase-admin/firestore");

// ============================================================
// BOOKING LIFECYCLE FUNCTION
// ============================================================

const {
  syncBookingLifecycle,
} = require("./bookingLifecycle");

// ============================================================
// ADMIN BOOKING NOTIFICATION FUNCTION
// ============================================================

const {
  notifyAdminsOnNewBooking,
} = require("./bookingNotifications");

// ============================================================
// CUSTOMER BOOKING NOTIFICATION FUNCTION
// ============================================================

const {
  notifyCustomerOnBookingUpdate,
} = require("./customerBookingNotifications");

// ============================================================
// MSG91 WHATSAPP OTP
// ============================================================

const {
  sendMsg91Otp,
  verifyMsg91Otp,
} = require("./msg91Otp");

// ============================================================
// RAZORPAY MULTI-TENANT PAYMENT
// ============================================================
//
// The actual Razorpay implementation is inside:
//
// functions/razorpay.js
//
// razorpay.js handles:
//
// - Tenant Razorpay configuration
// - Secret Manager
// - Razorpay client
// - Razorpay order creation
// - Outstanding amount calculation
// - Booking ownership validation
// - Razorpay signature verification
//
// Firestore:
//
// tenants/{tenantId}
//
//     razorpay:
//       enabled
//       configured
//       mode
//       keyId
//       currency
//
// Secret Manager:
//
// RAZORPAY_TENANT_001_KEY_SECRET
// RAZORPAY_TENANT_002_KEY_SECRET
// RAZORPAY_TENANT_003_KEY_SECRET
//
// The Razorpay Key Secret NEVER goes to Flutter.
//
// ============================================================

const {
  createRazorpayOrder,
  verifyRazorpaySignature,
} = require("./razorpay");

// ============================================================
// FIREBASE ADMIN INITIALIZATION
// ============================================================

initializeApp();

const auth = getAuth();

const db = getFirestore();

// ============================================================
// CREATE CUSTOMER
// ============================================================

exports.createCustomer = onCall(
    async (request) => {
      // -------------------------------------------------------
      // 1. Verify caller is authenticated
      // -------------------------------------------------------

      if (!request.auth) {
        throw new HttpsError(
            "unauthenticated",
            "You must be logged in to create a customer.",
        );
      }

      const callerUid =
        request.auth.uid;

      // -------------------------------------------------------
      // 2. Validate request
      // -------------------------------------------------------

      const data =
        request.data || {};

      const tenantId =
        String(
            data.tenantId || "",
        ).trim();

      const fullName =
        String(
            data.fullName || "",
        ).trim();

      const phone =
        String(
            data.phone || "",
        ).trim();

      const email =
        String(
            data.email || "",
        ).trim();

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

      // -------------------------------------------------------
      // 3. Verify tenant exists
      // -------------------------------------------------------

      const tenantRef =
        db
            .collection("tenants")
            .doc(tenantId);

      const tenantSnap =
        await tenantRef.get();

      if (!tenantSnap.exists) {
        throw new HttpsError(
            "not-found",
            "Tenant does not exist.",
        );
      }

      // -------------------------------------------------------
      // 4. Verify caller is an active admin
      // -------------------------------------------------------

      const adminRef =
        tenantRef
            .collection("admins")
            .doc(callerUid);

      const adminSnap =
        await adminRef.get();

      if (!adminSnap.exists) {
        throw new HttpsError(
            "permission-denied",
            "You are not an admin of this tenant.",
        );
      }

      const adminData =
        adminSnap.data() || {};

      if (adminData.isActive !== true) {
        throw new HttpsError(
            "permission-denied",
            "Your admin account is inactive.",
        );
      }

      // -------------------------------------------------------
      // 5. Check duplicate customer by phone
      // -------------------------------------------------------

      const customersRef =
        tenantRef.collection(
            "customers",
        );

      const existingSnapshot =
        await customersRef
            .where(
                "phone",
                "==",
                phone,
            )
            .limit(1)
            .get();

      if (!existingSnapshot.empty) {
        const existingDoc =
          existingSnapshot.docs[0];

        throw new HttpsError(
            "already-exists",
            "A customer with this phone number already exists.",
            {
              customerId:
                existingDoc.id,
            },
        );
      }

      // -------------------------------------------------------
      // 6. Create Firebase Authentication user
      // -------------------------------------------------------

      let firebaseUser;

      try {
        firebaseUser =
          await auth.createUser({
            phoneNumber:
              phone,

            ...(email ?
              {
                email:
                  email,
              } :
              {}),

            displayName:
              fullName,

            disabled:
              false,
          });
      } catch (error) {
        console.error(
            "Firebase Auth user creation failed:",
            error,
        );

        if (
          error.code ===
          "auth/phone-number-already-exists"
        ) {
          throw new HttpsError(
              "already-exists",
              "A Firebase user with this phone number already exists.",
          );
        }

        if (
          error.code ===
          "auth/invalid-phone-number"
        ) {
          throw new HttpsError(
              "invalid-argument",
              "The phone number is invalid. Use +91.",
          );
        }

        if (
          error.code ===
          "auth/email-already-exists"
        ) {
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

      const uid =
        firebaseUser.uid;

      // -------------------------------------------------------
      // 7. Create customer Firestore document
      // -------------------------------------------------------

      const customerRef =
        customersRef.doc(uid);

      try {
        await customerRef.set({
          customerId:
            uid,

          tenantId:
            tenantId,

          fullName:
            fullName,

          phone:
            phone,

          email:
            email,

          profileImageUrl:
            "",

          dateOfBirth:
            "",

          gender:
            "",

          address:
            null,

          emergencyContact:
            null,

          kycStatus:
            "not_started",

          profileCompleted:
            false,

          isActive:
            true,

          totalBookings:
            0,

          completedBookings:
            0,

          createdAt:
            FieldValue.serverTimestamp(),

          updatedAt:
            FieldValue.serverTimestamp(),

          createdByAdminId:
            callerUid,

          createdByAdminName:
            adminData.name || "",
        });

        // -----------------------------------------------------
        // 8. Return success
        // -----------------------------------------------------

        return {
          success:
            true,

          customerId:
            uid,

          firebaseUid:
            uid,

          tenantId:
            tenantId,

          message:
            "Customer created successfully.",
        };
      } catch (error) {
        console.error(
            "Customer Firestore creation failed:",
            error,
        );

        // -----------------------------------------------------
        // Rollback Firebase Auth user
        // -----------------------------------------------------

        try {
          await auth.deleteUser(
              uid,
          );
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
    },
);

// ============================================================
// AUTOMATIC BOOKING LIFECYCLE
// ============================================================
//
// bookingLifecycle.js contains:
//
// confirmed + pickupDateTime reached
//              ↓
//         pickupPending
//
// active + returnDateTime reached
//              ↓
//         returnPending
//
// Physical handover and return inspection remain manual.
//
// ============================================================

exports.syncBookingLifecycle =
  syncBookingLifecycle;

// ============================================================
// NEW BOOKING ADMIN NOTIFICATION
// ============================================================

exports.notifyAdminsOnNewBooking =
  notifyAdminsOnNewBooking;

// ============================================================
// CUSTOMER BOOKING NOTIFICATIONS
// ============================================================

exports.notifyCustomerOnBookingUpdate =
  notifyCustomerOnBookingUpdate;

// ============================================================
// MSG91 WHATSAPP OTP
// ============================================================

exports.sendMsg91Otp =
  sendMsg91Otp;

exports.verifyMsg91Otp =
  verifyMsg91Otp;

// ============================================================
// RAZORPAY CREATE ORDER
// ============================================================
//
// IMPORTANT:
//
// createRazorpayOrder() imported from razorpay.js is a NORMAL
// helper function.
//
// Firebase requires the exported Cloud Function itself to be
// wrapped with onCall().
//
// Flutter sends:
//
// {
//   tenantId: "...",
//   bookingId: "..."
//
// }
//
// Firebase Auth UID is taken from request.auth.uid.
//
// razorpay.js then:
//
// 1. Loads tenant Razorpay configuration
// 2. Loads tenant-specific secret from Secret Manager
// 3. Loads booking from:
//      tenants/{tenantId}/bookings/{bookingId}
// 4. Verifies customer ownership
// 5. Checks booking status
// 6. Calculates outstanding amount from Firestore
// 7. Creates Razorpay order
// 8. Saves payment attempt
// 9. Returns order details
//
// Razorpay Key Secret is NEVER returned to Flutter.
//
// ============================================================

exports.createRazorpayOrder = onCall(
    async (request) => {
      try {
        // ------------------------------------------------------
        // Authentication
        // ------------------------------------------------------

        if (!request.auth) {
          throw new HttpsError(
              "unauthenticated",
              "You must be logged in to make a payment.",
          );
        }

        // ------------------------------------------------------
        // Request data
        // ------------------------------------------------------

        const data =
          request.data || {};

        const tenantId =
          String(
              data.tenantId || "",
          ).trim();

        const bookingId =
          String(
              data.bookingId || "",
          ).trim();

        const userId =
          String(
              request.auth.uid || "",
          ).trim();

        // ------------------------------------------------------
        // Validate tenant
        // ------------------------------------------------------

        if (!tenantId) {
          throw new HttpsError(
              "invalid-argument",
              "tenantId is required.",
          );
        }

        // ------------------------------------------------------
        // Validate booking
        // ------------------------------------------------------

        if (!bookingId) {
          throw new HttpsError(
              "invalid-argument",
              "bookingId is required.",
          );
        }

        // ------------------------------------------------------
        // Call actual Razorpay service
        // ------------------------------------------------------

        const result =
          await createRazorpayOrder({
            tenantId:
              tenantId,

            bookingId:
              bookingId,

            userId:
              userId,
          });

        return result;
      } catch (error) {
        console.error(
            "createRazorpayOrder failed:",
            error,
        );

        // Preserve Firebase HttpsError.
        if (
          error instanceof HttpsError
        ) {
          throw error;
        }

        throw new HttpsError(
            "internal",
            error.message ||
              "Unable to create Razorpay order.",
        );
      }
    },
);

// ============================================================
// RAZORPAY VERIFY PAYMENT
// ============================================================
//
// Flutter sends:
//
// {
//   tenantId: "...",
//   orderId: "...",
//   paymentId: "...",
//   signature: "..."
//
// }
//
// razorpay.js uses the tenant-specific Razorpay secret to
// calculate:
//
// HMAC-SHA256(orderId + "|" + paymentId)
//
// and compares it securely against the Razorpay signature.
//
// ============================================================

exports.verifyRazorpaySignature = onCall(
    async (request) => {
      try {
        // ------------------------------------------------------
        // Authentication
        // ------------------------------------------------------

        if (!request.auth) {
          throw new HttpsError(
              "unauthenticated",
              "You must be logged in to verify payment.",
          );
        }

        // ------------------------------------------------------
        // Request data
        // ------------------------------------------------------

        const data =
          request.data || {};

        const tenantId =
          String(
              data.tenantId || "",
          ).trim();

        const orderId =
          String(
              data.orderId || "",
          ).trim();

        const paymentId =
          String(
              data.paymentId || "",
          ).trim();

        const signature =
          String(
              data.signature || "",
          ).trim();

        // ------------------------------------------------------
        // Validate tenant
        // ------------------------------------------------------

        if (!tenantId) {
          throw new HttpsError(
              "invalid-argument",
              "tenantId is required.",
          );
        }

        // ------------------------------------------------------
        // Validate order
        // ------------------------------------------------------

        if (!orderId) {
          throw new HttpsError(
              "invalid-argument",
              "orderId is required.",
          );
        }

        // ------------------------------------------------------
        // Validate payment
        // ------------------------------------------------------

        if (!paymentId) {
          throw new HttpsError(
              "invalid-argument",
              "paymentId is required.",
          );
        }

        // ------------------------------------------------------
        // Validate signature
        // ------------------------------------------------------

        if (!signature) {
          throw new HttpsError(
              "invalid-argument",
              "signature is required.",
          );
        }

        // ------------------------------------------------------
        // Verify actual Razorpay signature
        // ------------------------------------------------------

        const verified =
          await verifyRazorpaySignature({
            tenantId:
              tenantId,

            orderId:
              orderId,

            paymentId:
              paymentId,

            signature:
              signature,
          });

        // ------------------------------------------------------
        // Invalid signature
        // ------------------------------------------------------

        if (!verified) {
          throw new HttpsError(
              "permission-denied",
              "Invalid Razorpay payment signature.",
          );
        }

        // ------------------------------------------------------
        // Success
        // ------------------------------------------------------

        return {
          success:
            true,

          verified:
            true,

          tenantId:
            tenantId,

          orderId:
            orderId,

          paymentId:
            paymentId,
        };
      } catch (error) {
        console.error(
            "verifyRazorpaySignature failed:",
            error,
        );

        // Preserve Firebase HttpsError.
        if (
          error instanceof HttpsError
        ) {
          throw error;
        }

        throw new HttpsError(
            "internal",
            error.message ||
              "Unable to verify Razorpay payment.",
        );
      }
    },
);
