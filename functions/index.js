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
const {getMessaging} = require("firebase-admin/messaging");
const {
  syncBookingLifecycle,
} = require("./bookingLifecycle");
const {
  aiCustomerChat,
} = require("./ai_customer_chat");

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
// Actual Razorpay implementation:
//     functions/razorpay.js
//
// Handles:
//
// - Tenant Razorpay configuration
// - Tenant-specific Secret Manager secret
// - Razorpay client
// - Razorpay order creation
// - Outstanding calculation
// - Partial/custom amount validation
// - Booking ownership validation
// - Payment attempt creation
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
// Razorpay Key Secret NEVER goes to Flutter.
//
// ============================================================

const {
  createRazorpayOrder,
  createRazorpayCheckoutOrder,
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
      // 4. Verify caller is active admin
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

exports.aiCustomerChat = aiCustomerChat;
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
// Supports:
//
// 1. PAY REMAINING
//
// Flutter:
// {
//   tenantId: "...",
//   bookingId: "..."
// }
//
// requestedAmount is omitted.
//
// razorpay.js reads the latest outstanding amount.
//
//
//
// 2. PAY OTHER AMOUNT
//
// Flutter:
// {
//   tenantId: "...",
//   bookingId: "...",
//   requestedAmount: 2000
// }
//
// razorpay.js:
//
// requestedAmount > 0
// requestedAmount <= latest outstanding
//
// The server is the final authority.
//
// ============================================================

// ============================================================
// MANUAL CUSTOMER PUSH NOTIFICATION
// ============================================================
//
// Sends a manually created push notification to customers
// belonging ONLY to the authenticated admin's tenant.
//
// Supports:
//
// - Title
// - Body
// - Image URL
// - Notification type
// - Action / deep link
// - Booking ID
// - Car ID
// - Offer ID
// - All customers
// - Specific customer
// - Invalid FCM token cleanup
// - Notification history
// - Success / failure counts
//
// Firestore:
//
// tenants/{tenantId}/notifications/{notificationId}
//
// Customer devices:
//
// tenants/{tenantId}/customers/{customerUid}/notificationDevices/{deviceId}
//
// ============================================================

// ============================================================
// MANUAL TENANT NOTIFICATION - FULL VERSION
// ============================================================
//
// Supports:
//
// 1. all_customers
// 2. specific_customer
// 3. all_admins
// 4. all_branch_admins
// 5. customers_and_admins
// 6. customers_and_branch_admins
// 7. all_tenant_users
//
// Supports:
//
// - Title
// - Body
// - Image URL
// - Notification type
// - Action / deep link
// - Booking ID
// - Car ID
// - Offer ID
// - Specific customer
// - Tenant admins
// - Branch admins
// - FCM token cleanup
// - Detailed logs
// - Notification history
// - Success/failure counts
// - Duplicate token protection
// - Tenant isolation
//
// CUSTOMER DEVICES:
//
// tenants/{tenantId}/customers/{customerUid}/notificationDevices/{deviceId}
//
// TENANT ADMIN DEVICES:
//
// tenants/{tenantId}/admins/{adminUid}/notificationDevices/{deviceId}
//
// BRANCH ADMIN DEVICES:
//
//
// ============================================================

// ============================================================
// MANUAL TENANT PUSH NOTIFICATION
// ============================================================
//
// Supports:
//
// 1. all_customers
// 2. specific_customer
// 3. all_admins
// 4. all_branch_admins
// 5. customers_and_admins
// 6. customers_and_branch_admins
// 7. all_tenant_users
//
// Supports:
//
// - Title
// - Body
// - Image URL
// - Notification type
// - Action / deep link
// - Booking ID
// - Car ID
// - Offer ID
// - Customer targeting
// - Tenant admin targeting
// - Branch admin targeting
// - Duplicate token protection
// - Invalid token cleanup
// - Detailed logs
// - Notification history
// - Success/failure counts
// - Tenant isolation
//
// ============================================================

exports.sendManualCustomerNotification = onCall(
    async (request) => {
      const LOG_PREFIX = "[MANUAL_NOTIFICATION]";

      try {
      // ========================================================
      // 1. AUTHENTICATION
      // ========================================================

        if (!request.auth) {
          console.error(
              `${LOG_PREFIX} ❌ Unauthenticated request`,
          );

          throw new HttpsError(
              "unauthenticated",
              "You must be logged in.",
          );
        }

        const callerUid = request.auth.uid;

        console.log(
            `${LOG_PREFIX} ==================================================`,
        );

        console.log(
            `${LOG_PREFIX} 🚀 Notification request started`,
        );

        console.log(
            `${LOG_PREFIX} callerUid=${callerUid}`,
        );

        // ========================================================
        // 2. REQUEST DATA
        // ========================================================

        const data = request.data || {};

        const tenantId =
        String(
            data.tenantId || "",
        ).trim();

        const title =
        String(
            data.title || "",
        ).trim();

        const body =
        String(
            data.body ||
          data.message ||
          "",
        ).trim();

        const imageUrl =
        String(
            data.imageUrl || "",
        ).trim();

        const type =
        String(
            data.type ||
          "general",
        ).trim();

        const action =
        String(
            data.action ||
          "home",
        ).trim();

        const bookingId =
        String(
            data.bookingId || "",
        ).trim();

        const carId =
        String(
            data.carId || "",
        ).trim();

        const offerId =
        String(
            data.offerId || "",
        ).trim();

        const targetType =
        String(
            data.targetType ||
          "all_customers",
        ).trim();

        const customerId =
        String(
            data.customerId || "",
        ).trim();

        const branchId =
        String(
            data.branchId || "",
        ).trim();

        console.log(
            `${LOG_PREFIX} 📦 REQUEST DATA`,
            {
              tenantId,
              callerUid,
              targetType,
              customerId:
            customerId || null,
              branchId:
            branchId || null,
              titleLength:
            title.length,
              bodyLength:
            body.length,
              type,
              action,
              bookingId:
            bookingId || null,
              carId:
            carId || null,
              offerId:
            offerId || null,
              hasImage:
            imageUrl.length > 0,
              imageUrlLength:
            imageUrl.length,
            },
        );

        // ========================================================
        // 3. IMAGE DEBUG / VALIDATION
        // ========================================================

        if (imageUrl) {
          console.log(
              `${LOG_PREFIX} 🖼️ IMAGE URL RECEIVED`,
              {
                hasImage: true,
                length:
              imageUrl.length,
                protocol:
              imageUrl.startsWith("https://") ?
                "https" :
                "non_https",
                preview:
              imageUrl.substring(
                  0,
                  300,
              ),
              },
          );

          if (
            !imageUrl.startsWith(
                "https://",
            )
          ) {
            console.warn(
                `${LOG_PREFIX} ⚠️ IMAGE URL IS NOT HTTPS`,
            );
          }
        } else {
          console.log(
              `${LOG_PREFIX} 🖼️ NO IMAGE ATTACHED`,
          );
        }

        // ========================================================
        // 4. BASIC VALIDATION
        // ========================================================

        if (!tenantId) {
          throw new HttpsError(
              "invalid-argument",
              "tenantId is required.",
          );
        }

        if (!title) {
          throw new HttpsError(
              "invalid-argument",
              "Notification title is required.",
          );
        }

        if (!body) {
          throw new HttpsError(
              "invalid-argument",
              "Notification message is required.",
          );
        }

        if (title.length > 150) {
          throw new HttpsError(
              "invalid-argument",
              "Notification title is too long.",
          );
        }

        if (body.length > 1000) {
          throw new HttpsError(
              "invalid-argument",
              "Notification message is too long.",
          );
        }

        const allowedTargetTypes = [
          "all_customers",
          "specific_customer",
          "all_admins",
          "all_branch_admins",
          "customers_and_admins",
          "customers_and_branch_admins",
          "all_tenant_users",
        ];

        if (
          !allowedTargetTypes.includes(
              targetType,
          )
        ) {
          throw new HttpsError(
              "invalid-argument",
              `Invalid targetType: ${targetType}`,
          );
        }

        if (
          targetType ===
          "specific_customer" &&
        !customerId
        ) {
          throw new HttpsError(
              "invalid-argument",
              "customerId is required for specific_customer.",
          );
        }

        // ========================================================
        // 5. VERIFY TENANT
        // ========================================================

        const tenantRef =
        db
            .collection("tenants")
            .doc(tenantId);

        const tenantSnap =
        await tenantRef.get();

        if (!tenantSnap.exists) {
          console.error(
              `${LOG_PREFIX} ❌ Tenant does not exist`,
              tenantId,
          );

          throw new HttpsError(
              "not-found",
              "Tenant was not found.",
          );
        }

        console.log(
            `${LOG_PREFIX} ✅ Tenant exists`,
            tenantId,
        );

        // ========================================================
        // 6. VERIFY CALLER IS TENANT ADMIN
        // ========================================================

        const adminRef =
        tenantRef
            .collection("admins")
            .doc(callerUid);

        const adminSnap =
        await adminRef.get();

        let isTenantAdmin =
        adminSnap.exists;

        console.log(
            `${LOG_PREFIX} 🔐 Tenant admin document exists=${isTenantAdmin}`,
        );

        // --------------------------------------------------------
        // users/{uid} fallback
        // --------------------------------------------------------

        if (!isTenantAdmin) {
          const userRef =
          db
              .collection("users")
              .doc(callerUid);

          const userSnap =
          await userRef.get();

          if (userSnap.exists) {
            const userData =
            userSnap.data() || {};

            const userTenantId =
            String(
                userData.tenantId || "",
            ).trim();

            const role =
            String(
                userData.role || "",
            ).toLowerCase();

            console.log(
                `${LOG_PREFIX} 🔎 USERS FALLBACK`,
                {
                  userTenantId,
                  role,
                },
            );

            if (
              userTenantId === tenantId &&
            [
              "admin",
              "superadmin",
              "owner",
              "tenant_admin",
            ].includes(role)
            ) {
              isTenantAdmin = true;
            }
          }
        }

        // --------------------------------------------------------
        // Firebase custom claims fallback
        // --------------------------------------------------------

        if (!isTenantAdmin) {
          const userRecord =
          await auth.getUser(
              callerUid,
          );

          const claims =
          userRecord.customClaims || {};

          const claimTenantId =
          String(
              claims.tenantId || "",
          ).trim();

          const claimRole =
          String(
              claims.role || "",
          ).toLowerCase();

          console.log(
              `${LOG_PREFIX} 🔎 CUSTOM CLAIMS`,
              {
                claimTenantId,
                claimRole,
              },
          );

          if (
            claimTenantId === tenantId &&
          [
            "admin",
            "superadmin",
            "owner",
            "tenant_admin",
          ].includes(claimRole)
          ) {
            isTenantAdmin = true;
          }
        }

        if (!isTenantAdmin) {
          console.error(
              `${LOG_PREFIX} ❌ Caller NOT authorized`,
              {
                callerUid,
                tenantId,
              },
          );

          throw new HttpsError(
              "permission-denied",
              "You are not authorized to send notifications for this tenant.",
          );
        }

        console.log(
            `${LOG_PREFIX} ✅ Caller authorized`,
            {
              tenantId,
              callerUid,
            },
        );

        // ========================================================
        // 7. CREATE NOTIFICATION HISTORY
        // ========================================================

        const notificationRef =
        tenantRef
            .collection("notifications")
            .doc();

        const notificationId =
        notificationRef.id;

        await notificationRef.set({
          notificationId,
          tenantId,
          title,
          body,
          imageUrl:
          imageUrl || null,
          type,
          action,
          bookingId:
          bookingId || null,
          carId:
          carId || null,
          offerId:
          offerId || null,
          targetType,
          targetCustomerId:
          customerId || null,
          targetBranchId:
          branchId || null,
          sentBy:
          callerUid,
          status:
          "processing",
          recipientCount:
          0,
          successCount:
          0,
          failureCount:
          0,
          failedTokens:
          [],
          createdAt:
          FieldValue.serverTimestamp(),
          sentAt:
          null,
        });

        console.log(
            `${LOG_PREFIX} 📝 Notification history created`,
            {
              notificationId,
              targetType,
              hasImage:
            !!imageUrl,
            },
        );

        // ========================================================
        // 8. DEVICE COLLECTION
        // ========================================================

        const deviceRefs = [];

        // ========================================================
        // ADD DEVICE HELPER
        // ========================================================

        const addDevice = ({
          token,
          deviceId,
          role,
          customerId:
          targetCustomerId,
          adminId,
          branchId:
          targetBranchId,
          sourcePath,
          deviceData,
        }) => {
          const cleanToken =
          String(
              token || "",
          ).trim();

          if (!cleanToken) {
            console.log(
                `${LOG_PREFIX} ⚠️ DEVICE SKIPPED - NO TOKEN`,
                {
                  role,
                  deviceId,
                  sourcePath,
                },
            );

            return;
          }

          const isActive =
          deviceData &&
          deviceData.isActive !== false;

          if (!isActive) {
            console.log(
                `${LOG_PREFIX} ⚠️ DEVICE SKIPPED - INACTIVE`,
                {
                  role,
                  deviceId,
                  sourcePath,
                },
            );

            return;
          }

          const platform =
          deviceData &&
          deviceData.platform ?
            deviceData.platform :
            null;

          const firebaseUid =
          deviceData &&
          deviceData.firebaseUid ?
            deviceData.firebaseUid :
            null;

          deviceRefs.push({
            token:
            cleanToken,

            deviceId:
            deviceId || "",

            role:
            role || "unknown",

            customerId:
            targetCustomerId || null,

            adminId:
            adminId || null,

            branchId:
            targetBranchId || null,

            sourcePath:
            sourcePath || "",

            platform,

            firebaseUid,
          });

          console.log(
              `${LOG_PREFIX} 📱 DEVICE ADDED`,
              {
                role,
                deviceId,
                customerId:
              targetCustomerId || null,
                adminId:
              adminId || null,
                branchId:
              targetBranchId || null,
                platform,
                firebaseUid,
                sourcePath,
                tokenPreview:
              `${cleanToken.substring(0, 12)}...`,
              },
          );
        };

        // ========================================================
        // 9. CUSTOMER DEVICES
        // ========================================================

        const shouldSendCustomers =
        targetType ===
          "all_customers" ||
        targetType ===
          "specific_customer" ||
        targetType ===
          "customers_and_admins" ||
        targetType ===
          "customers_and_branch_admins" ||
        targetType ===
          "all_tenant_users";

        if (shouldSendCustomers) {
          console.log(
              `${LOG_PREFIX} 👥 CUSTOMER TARGETING STARTED`,
          );

          // ------------------------------------------------------
          // SPECIFIC CUSTOMER
          // ------------------------------------------------------

          if (
            targetType ===
          "specific_customer"
          ) {
            const customerRef =
            tenantRef
                .collection("customers")
                .doc(customerId);

            const customerSnap =
            await customerRef.get();

            if (!customerSnap.exists) {
              throw new HttpsError(
                  "not-found",
                  "Customer was not found.",
              );
            }

            const customerData =
            customerSnap.data() || {};

            console.log(
                `${LOG_PREFIX} 👤 SPECIFIC CUSTOMER`,
                {
                  customerId,
                  isAdmin:
                customerData.isAdmin === true,
                },
            );

            if (
              customerData.isAdmin === true
            ) {
              console.warn(
                  `${LOG_PREFIX} ⚠️ Customer marked isAdmin=true. Skipping.`,
                  customerId,
              );
            } else {
              const devicesSnap =
              await customerRef
                  .collection(
                      "notificationDevices",
                  )
                  .get();

              console.log(
                  `${LOG_PREFIX} 📱 Customer devices=${devicesSnap.size}`,
                  {
                    customerId,
                  },
              );

              for (
                const deviceDoc of
                devicesSnap.docs
              ) {
                const deviceData =
                deviceDoc.data() || {};

                const token =
                deviceData.fcmToken ||
                deviceData.token ||
                "";

                addDevice({
                  token,
                  deviceId:
                  deviceDoc.id,
                  role:
                  "customer",
                  customerId,
                  sourcePath:
                  deviceDoc.ref.path,
                  deviceData,
                });
              }
            }
          } else {
          // ----------------------------------------------------
          // ALL CUSTOMERS
          // ----------------------------------------------------

            const customersSnap =
            await tenantRef
                .collection("customers")
                .get();

            console.log(
                `${LOG_PREFIX} 👥 TOTAL 
                CUSTOMER DOCUMENTS=${customersSnap.size}`,
            );

            for (
              const customerDoc of
              customersSnap.docs
            ) {
              const currentCustomerId =
              customerDoc.id;

              const customerData =
              customerDoc.data() || {};

              if (
                customerData.isAdmin === true
              ) {
                console.log(
                    `${LOG_PREFIX} ⏭️ CUSTOMER SKIPPED isAdmin=true`,
                    currentCustomerId,
                );

                continue;
              }

              const devicesSnap =
              await customerDoc.ref
                  .collection(
                      "notificationDevices",
                  )
                  .get();

              console.log(
                  `${LOG_PREFIX} 👤 CUSTOMER DEVICES`,
                  {
                    customerId:
                  currentCustomerId,
                    devices:
                  devicesSnap.size,
                  },
              );

              for (
                const deviceDoc of
                devicesSnap.docs
              ) {
                const deviceData =
                deviceDoc.data() || {};

                const token =
                deviceData.fcmToken ||
                deviceData.token ||
                "";

                addDevice({
                  token,
                  deviceId:
                  deviceDoc.id,
                  role:
                  "customer",
                  customerId:
                  currentCustomerId,
                  sourcePath:
                  deviceDoc.ref.path,
                  deviceData,
                });
              }
            }
          }
        }

        // ========================================================
        // 10. TENANT ADMIN DEVICES
        // ========================================================

        const shouldSendTenantAdmins =
        targetType ===
          "all_admins" ||
        targetType ===
          "customers_and_admins" ||
        targetType ===
          "all_tenant_users";

        if (shouldSendTenantAdmins) {
          console.log(
              `${LOG_PREFIX} 👨‍💼 TENANT ADMIN TARGETING STARTED`,
          );

          const adminsSnap =
          await tenantRef
              .collection("admins")
              .get();

          console.log(
              `${LOG_PREFIX} 👨‍💼 TENANT ADMINS=${adminsSnap.size}`,
          );

          for (
            const adminDoc of
            adminsSnap.docs
          ) {
            const targetAdminId =
            adminDoc.id;

            const adminData =
            adminDoc.data() || {};

            if (
              adminData.isActive === false
            ) {
              console.log(
                  `${LOG_PREFIX} ⏭️ ADMIN SKIPPED - INACTIVE`,
                  targetAdminId,
              );

              continue;
            }

            const devicesSnap =
            await adminDoc.ref
                .collection(
                    "notificationDevices",
                )
                .get();

            console.log(
                `${LOG_PREFIX} 👨‍💼 ADMIN DEVICES`,
                {
                  adminId:
                targetAdminId,
                  devices:
                devicesSnap.size,
                },
            );

            for (
              const deviceDoc of
              devicesSnap.docs
            ) {
              const deviceData =
              deviceDoc.data() || {};

              const token =
              deviceData.fcmToken ||
              deviceData.token ||
              "";

              addDevice({
                token,
                deviceId:
                deviceDoc.id,
                role:
                "admin",
                adminId:
                targetAdminId,
                sourcePath:
                deviceDoc.ref.path,
                deviceData,
              });
            }
          }
        }

        // ========================================================
        // 11. BRANCH ADMIN DEVICES
        // ========================================================

        const shouldSendBranchAdmins =
        targetType ===
          "all_branch_admins" ||
        targetType ===
          "customers_and_branch_admins" ||
        targetType ===
          "all_tenant_users";

        if (shouldSendBranchAdmins) {
          console.log(
              `${LOG_PREFIX} 🏢 BRANCH ADMIN TARGETING STARTED`,
          );

          const branchesSnap =
          await tenantRef
              .collection("branches")
              .get();

          console.log(
              `${LOG_PREFIX} 🏢 BRANCHES=${branchesSnap.size}`,
          );

          for (
            const branchDoc of
            branchesSnap.docs
          ) {
            const currentBranchId =
            branchDoc.id;

            const branchData =
            branchDoc.data() || {};

            console.log(
                `${LOG_PREFIX} 🏢 PROCESSING BRANCH`,
                {
                  branchId:
                currentBranchId,
                  branchName:
                branchData.name ||
                branchData.branchName ||
                null,
                },
            );

            const branchAdminsSnap =
            await branchDoc.ref
                .collection("admins")
                .get();

            console.log(
                `${LOG_PREFIX} 🏢 BRANCH ADMINS`,
                {
                  branchId:
                currentBranchId,
                  admins:
                branchAdminsSnap.size,
                },
            );

            for (
              const branchAdminDoc of
              branchAdminsSnap.docs
            ) {
              const branchAdminId =
              branchAdminDoc.id;

              const branchAdminData =
              branchAdminDoc.data() || {};

              if (
                branchAdminData.isActive ===
              false
              ) {
                console.log(
                    `${LOG_PREFIX} ⏭️ BRANCH ADMIN SKIPPED - INACTIVE`,
                    {
                      branchId:
                    currentBranchId,
                      adminId:
                    branchAdminId,
                    },
                );

                continue;
              }

              const devicesSnap =
              await branchAdminDoc.ref
                  .collection(
                      "notificationDevices",
                  )
                  .get();

              console.log(
                  `${LOG_PREFIX} 🏢 BRANCH ADMIN DEVICES`,
                  {
                    branchId:
                  currentBranchId,
                    adminId:
                  branchAdminId,
                    devices:
                  devicesSnap.size,
                  },
              );

              for (
                const deviceDoc of
                devicesSnap.docs
              ) {
                const deviceData =
                deviceDoc.data() || {};

                const token =
                deviceData.fcmToken ||
                deviceData.token ||
                "";

                addDevice({
                  token,
                  deviceId:
                  deviceDoc.id,
                  role:
                  "branch_admin",
                  adminId:
                  branchAdminId,
                  branchId:
                  currentBranchId,
                  sourcePath:
                  deviceDoc.ref.path,
                  deviceData,
                });
              }
            }
          }
        }

        // ========================================================
        // 12. RAW DEVICE SUMMARY
        // ========================================================

        console.log(
            `${LOG_PREFIX} 📊 RAW DEVICE SUMMARY`,
            {
              totalRawDevices:
            deviceRefs.length,

              customers:
            deviceRefs.filter(
                (device) =>
                  device.role ===
                "customer",
            ).length,

              admins:
            deviceRefs.filter(
                (device) =>
                  device.role ===
                "admin",
            ).length,

              branchAdmins:
            deviceRefs.filter(
                (device) =>
                  device.role ===
                "branch_admin",
            ).length,
            },
        );

        // ========================================================
        // 13. REMOVE DUPLICATE TOKENS
        // ========================================================

        const uniqueDevices = [];
        const duplicateDevices = [];
        const seenTokens = new Set();

        for (
          const device of deviceRefs
        ) {
          if (!device.token) {
            continue;
          }

          if (
            seenTokens.has(
                device.token,
            )
          ) {
            duplicateDevices.push(
                device,
            );

            console.warn(
                `${LOG_PREFIX} ⚠️ DUPLICATE TOKEN`,
                {
                  role:
                device.role,
                  deviceId:
                device.deviceId,
                  customerId:
                device.customerId,
                  adminId:
                device.adminId,
                  branchId:
                device.branchId,
                  tokenPreview:
                `${device.token.substring(0, 12)}...`,
                },
            );

            continue;
          }

          seenTokens.add(
              device.token,
          );

          uniqueDevices.push(
              device,
          );
        }

        console.log(
            `${LOG_PREFIX} 📊 UNIQUE DEVICE SUMMARY`,
            {
              rawDevices:
            deviceRefs.length,
              uniqueDevices:
            uniqueDevices.length,
              duplicates:
            duplicateDevices.length,
            },
        );

        // ========================================================
        // 14. ROLE SUMMARY
        // ========================================================

        const roleSummary = {
          customer: 0,
          admin: 0,
          branch_admin: 0,
        };

        for (
          const device of
          uniqueDevices
        ) {
          if (
            Object.prototype.hasOwnProperty.call(
                roleSummary,
                device.role,
            )
          ) {
            roleSummary[
                device.role
            ]++;
          }
        }

        console.log(
            `${LOG_PREFIX} 📊 FINAL ROLE SUMMARY`,
            roleSummary,
        );

        // ========================================================
        // 15. DETAILED RECIPIENT LOG
        // ========================================================

        for (
          const device of
          uniqueDevices
        ) {
          console.log(
              `${LOG_PREFIX} 🎯 FINAL RECIPIENT`,
              {
                role:
              device.role,
                customerId:
              device.customerId,
                adminId:
              device.adminId,
                branchId:
              device.branchId,
                deviceId:
              device.deviceId,
                platform:
              device.platform,
                firebaseUid:
              device.firebaseUid,
                sourcePath:
              device.sourcePath,
                tokenPreview:
              `${device.token.substring(0, 12)}...`,
              },
          );
        }

        // ========================================================
        // 16. NO RECIPIENTS
        // ========================================================

        if (
          uniqueDevices.length === 0
        ) {
          console.error(
              `${LOG_PREFIX} ❌ NO RECIPIENT DEVICES`,
              {
                tenantId,
                targetType,
                customerId:
              customerId || null,
                branchId:
              branchId || null,
              },
          );

          await notificationRef.update({
            status:
            "no_recipients",
            recipientCount:
            0,
            successCount:
            0,
            failureCount:
            0,
            failedTokens:
            [],
            sentAt:
            FieldValue.serverTimestamp(),
          });

          return {
            success:
            false,
            notificationId,
            recipientCount:
            0,
            successCount:
            0,
            failureCount:
            0,
            message:
            "No active notification devices were found.",
          };
        }

        // ========================================================
        // 17. FCM DATA PAYLOAD
        // ========================================================

        const dataPayload = {
          notificationId:
          String(
              notificationId,
          ),

          tenantId:
          String(
              tenantId,
          ),

          type:
          String(
              type,
          ),

          action:
          String(
              action,
          ),

          title:
          String(
              title,
          ),

          body:
          String(
              body,
          ),
        };

        if (bookingId) {
          dataPayload.bookingId =
          String(
              bookingId,
          );
        }

        if (carId) {
          dataPayload.carId =
          String(
              carId,
          );
        }

        if (offerId) {
          dataPayload.offerId =
          String(
              offerId,
          );
        }

        if (customerId) {
          dataPayload.customerId =
          String(
              customerId,
          );
        }

        if (branchId) {
          dataPayload.branchId =
          String(
              branchId,
          );
        }

        if (imageUrl) {
          dataPayload.imageUrl =
          String(
              imageUrl,
          );
        }

        console.log(
            `${LOG_PREFIX} 📨 FCM PAYLOAD PREPARED`,
            {
              title,
              body,
              hasImage:
            !!imageUrl,
              imageUrlLength:
            imageUrl.length,
              recipientCount:
            uniqueDevices.length,
            },
        );

        // ========================================================
        // 18. SEND FCM IN BATCHES
        // ========================================================

        const BATCH_SIZE = 500;

        let successCount = 0;
        let failureCount = 0;

        const failedTokens = [];
        const successfulRecipients = [];
        const failedRecipients = [];

        console.log(
            `${LOG_PREFIX} 🚀 STARTING FCM DELIVERY`,
            {
              totalRecipients:
            uniqueDevices.length,
              batchSize:
            BATCH_SIZE,
            },
        );

        for (
          let start = 0;
          start <
          uniqueDevices.length;
          start += BATCH_SIZE
        ) {
          const batch =
          uniqueDevices.slice(
              start,
              start +
              BATCH_SIZE,
          );

          console.log(
              `${LOG_PREFIX} 📦 PROCESSING FCM BATCH`,
              {
                batchStart:
              start,
                batchEnd:
              start +
              batch.length -
              1,
                batchSize:
              batch.length,
              },
          );

          const tokens =
          batch.map(
              (device) =>
                device.token,
          );

          // ======================================================
          // IMPORTANT FCM MESSAGE
          // ======================================================

          const message = {
            tokens,

            notification: {
              title:
              title,
              body:
              body,

              ...(imageUrl ?
              {
                imageUrl:
                    imageUrl,
              } :
              {}),
            },

            data:
            dataPayload,

            android: {
              priority:
              "high",

              notification: {
                channelId:
                "rentocar_notifications",

                sound:
                "default",

                defaultSound:
                false,

                ...(imageUrl ?
                {
                  imageUrl:
                      imageUrl,
                } :
                {}),
              },
            },

            apns: {
              payload: {
                aps: {
                  "alert": {
                    title:
                    title,
                    body:
                    body,
                  },

                  "sound":
                  "default",

                  "badge":
                  1,

                  "mutable-content":
                  1,
                },
              },

              ...(imageUrl ?
              {
                fcmOptions: {
                  imageUrl:
                      imageUrl,
                },
              } :
              {}),
            },
          };

          // ======================================================
          // LOG IMAGE PAYLOAD
          // ======================================================

          console.log(
              `${LOG_PREFIX} 🖼️ FCM IMAGE PAYLOAD`,
              {
                imageIncluded:
              !!imageUrl,

                imageUrl:
              imageUrl ?
                imageUrl.substring(
                    0,
                    300,
                ) :
                null,

                androidImageIncluded:
              !!(
                imageUrl
              ),

                apnsImageIncluded:
              !!(
                imageUrl
              ),
              },
          );

          // ======================================================
          // SEND
          // ======================================================

          let response;

          try {
            response =
            await getMessaging()
                .sendEachForMulticast(
                    message,
                );

            console.log(
                `${LOG_PREFIX} 📬 FCM BATCH RESPONSE`,
                {
                  batchSize:
                batch.length,

                  successCount:
                response.successCount,

                  failureCount:
                response.failureCount,
                },
            );
          } catch (
            fcmBatchError
          ) {
            console.error(
                `${LOG_PREFIX} ❌ FCM BATCH SEND FAILED`,
                {
                  errorCode:
                fcmBatchError &&
                fcmBatchError.code ?
                  fcmBatchError.code :
                  "",

                  errorMessage:
                fcmBatchError &&
                fcmBatchError.message ?
                  fcmBatchError.message :
                  "",

                  stack:
                fcmBatchError &&
                fcmBatchError.stack ?
                  fcmBatchError.stack :
                  "",
                },
            );

            for (
              const device of
              batch
            ) {
              failureCount++;

              failedRecipients.push({
                role:
                device.role,

                customerId:
                device.customerId,

                adminId:
                device.adminId,

                branchId:
                device.branchId,

                deviceId:
                device.deviceId,

                error:
                fcmBatchError &&
                fcmBatchError.code ?
                  fcmBatchError.code :
                  "batch_send_failed",
              });
            }

            continue;
          }

          successCount +=
          response.successCount;

          failureCount +=
          response.failureCount;

          // ======================================================
          // 19. PROCESS EACH RESULT
          // ======================================================

          for (
            let i = 0;
            i <
            response.responses.length;
            i++
          ) {
            const result =
            response.responses[i];

            const device =
            batch[i];

            if (
              result.success
            ) {
              successfulRecipients.push({
                role:
                device.role,

                customerId:
                device.customerId,

                adminId:
                device.adminId,

                branchId:
                device.branchId,

                deviceId:
                device.deviceId,

                messageId:
                result.messageId ||
                null,
              });

              console.log(
                  `${LOG_PREFIX} ✅ FCM SUCCESS`,
                  {
                    role:
                  device.role,

                    customerId:
                  device.customerId,

                    adminId:
                  device.adminId,

                    branchId:
                  device.branchId,

                    deviceId:
                  device.deviceId,

                    platform:
                  device.platform,

                    messageId:
                  result.messageId ||
                  null,
                  },
              );

              continue;
            }

            const errorCode =
            result.error &&
            result.error.code ?
              result.error.code :
              "unknown_error";

            const errorMessage =
            result.error &&
            result.error.message ?
              result.error.message :
              "Unknown FCM error.";

            console.error(
                `${LOG_PREFIX} ❌ FCM FAILURE`,
                {
                  role:
                device.role,

                  customerId:
                device.customerId,

                  adminId:
                device.adminId,

                  branchId:
                device.branchId,

                  deviceId:
                device.deviceId,

                  errorCode,
                  errorMessage,

                  tokenPreview:
                `${device.token.substring(0, 12)}...`,
                },
            );

            failedRecipients.push({
              role:
              device.role,

              customerId:
              device.customerId,

              adminId:
              device.adminId,

              branchId:
              device.branchId,

              deviceId:
              device.deviceId,

              error:
              errorCode,
            });

            failedTokens.push({
              role:
              device.role,

              customerId:
              device.customerId,

              adminId:
              device.adminId,

              branchId:
              device.branchId,

              deviceId:
              device.deviceId,

              error:
              errorCode,
            });

            // ====================================================
            // 20. INVALID TOKEN CLEANUP
            // ====================================================

            const invalidToken =
            errorCode ===
              "messaging/invalid-registration-token" ||
            errorCode ===
              "messaging/registration-token-not-registered";

            if (
              invalidToken
            ) {
              try {
                let deviceRef =
                null;

                if (
                  device.role ===
                "customer"
                ) {
                  deviceRef =
                  tenantRef
                      .collection(
                          "customers",
                      )
                      .doc(
                          device.customerId,
                      )
                      .collection(
                          "notificationDevices",
                      )
                      .doc(
                          device.deviceId,
                      );
                } else if (
                  device.role ===
                "admin"
                ) {
                  deviceRef =
                  tenantRef
                      .collection(
                          "admins",
                      )
                      .doc(
                          device.adminId,
                      )
                      .collection(
                          "notificationDevices",
                      )
                      .doc(
                          device.deviceId,
                      );
                } else if (
                  device.role ===
                "branch_admin"
                ) {
                  deviceRef =
                  tenantRef
                      .collection(
                          "branches",
                      )
                      .doc(
                          device.branchId,
                      )
                      .collection(
                          "admins",
                      )
                      .doc(
                          device.adminId,
                      )
                      .collection(
                          "notificationDevices",
                      )
                      .doc(
                          device.deviceId,
                      );
                }

                if (deviceRef) {
                  await deviceRef.update({
                    isActive:
                    false,

                    disabledAt:
                    FieldValue.serverTimestamp(),

                    disabledReason:
                    errorCode,
                  });

                  console.warn(
                      `${LOG_PREFIX} 🧹 INVALID TOKEN DISABLED`,
                      {
                        role:
                      device.role,

                        customerId:
                      device.customerId,

                        adminId:
                      device.adminId,

                        branchId:
                      device.branchId,

                        deviceId:
                      device.deviceId,

                        errorCode,
                      },
                  );
                }
              } catch (
                cleanupError
              ) {
                console.error(
                    `${LOG_PREFIX} ❌ INVALID TOKEN CLEANUP FAILED`,
                    {
                      error:
                    cleanupError &&
                    cleanupError.message ?
                      cleanupError.message :
                      cleanupError,
                    },
                );
              }
            }
          }
        }

        // ========================================================
        // 21. FINAL STATUS
        // ========================================================

        let finalStatus =
        "failed";

        if (
          successCount > 0 &&
        failureCount === 0
        ) {
          finalStatus =
          "sent";
        } else if (
          successCount > 0 &&
        failureCount > 0
        ) {
          finalStatus =
          "partial";
        }

        // ========================================================
        // 22. FINAL ROLE COUNTS
        // ========================================================

        const finalRoleCounts = {
          customers:
          uniqueDevices.filter(
              (device) =>
                device.role ===
              "customer",
          ).length,

          admins:
          uniqueDevices.filter(
              (device) =>
                device.role ===
              "admin",
          ).length,

          branchAdmins:
          uniqueDevices.filter(
              (device) =>
                device.role ===
              "branch_admin",
          ).length,
        };

        const successfulRoleCounts = {
          customers:
          successfulRecipients.filter(
              (device) =>
                device.role ===
              "customer",
          ).length,

          admins:
          successfulRecipients.filter(
              (device) =>
                device.role ===
              "admin",
          ).length,

          branchAdmins:
          successfulRecipients.filter(
              (device) =>
                device.role ===
              "branch_admin",
          ).length,
        };

        const failedRoleCounts = {
          customers:
          failedRecipients.filter(
              (device) =>
                device.role ===
              "customer",
          ).length,

          admins:
          failedRecipients.filter(
              (device) =>
                device.role ===
              "admin",
          ).length,

          branchAdmins:
          failedRecipients.filter(
              (device) =>
                device.role ===
              "branch_admin",
          ).length,
        };

        // ========================================================
        // 23. UPDATE NOTIFICATION HISTORY
        // ========================================================

        await notificationRef.update({
          status:
          finalStatus,

          recipientCount:
          uniqueDevices.length,

          successCount:
          successCount,

          failureCount:
          failureCount,

          failedTokens:
          failedTokens.slice(
              0,
              100,
          ),

          recipientSummary: {
            total:
            uniqueDevices.length,

            customers:
            finalRoleCounts.customers,

            admins:
            finalRoleCounts.admins,

            branchAdmins:
            finalRoleCounts.branchAdmins,
          },

          successSummary: {
            customers:
            successfulRoleCounts.customers,

            admins:
            successfulRoleCounts.admins,

            branchAdmins:
            successfulRoleCounts.branchAdmins,
          },

          failureSummary: {
            customers:
            failedRoleCounts.customers,

            admins:
            failedRoleCounts.admins,

            branchAdmins:
            failedRoleCounts.branchAdmins,
          },

          duplicateTokenCount:
          duplicateDevices.length,

          sentAt:
          FieldValue.serverTimestamp(),
        });

        // ========================================================
        // 24. FINAL LOG
        // ========================================================

        console.log(
            `${LOG_PREFIX} ==================================================`,
        );

        console.log(
            `${LOG_PREFIX} 🏁 NOTIFICATION COMPLETED`,
        );

        console.log(
            `${LOG_PREFIX} RESULT`,
            {
              notificationId,
              tenantId,
              targetType,

              status:
            finalStatus,

              hasImage:
            !!imageUrl,

              imageUrlLength:
            imageUrl.length,

              recipientCount:
            uniqueDevices.length,

              successCount,
              failureCount,

              duplicateTokenCount:
            duplicateDevices.length,

              customers:
            finalRoleCounts.customers,

              admins:
            finalRoleCounts.admins,

              branchAdmins:
            finalRoleCounts.branchAdmins,

              successfulCustomers:
            successfulRoleCounts.customers,

              successfulAdmins:
            successfulRoleCounts.admins,

              successfulBranchAdmins:
            successfulRoleCounts.branchAdmins,

              failedCustomers:
            failedRoleCounts.customers,

              failedAdmins:
            failedRoleCounts.admins,

              failedBranchAdmins:
            failedRoleCounts.branchAdmins,
            },
        );

        console.log(
            `${LOG_PREFIX} ==================================================`,
        );

        // ========================================================
        // 25. RETURN RESULT TO FLUTTER
        // ========================================================

        return {
          success:
          successCount > 0,

          notificationId,

          tenantId,

          targetType,

          recipientCount:
          uniqueDevices.length,

          successCount,

          failureCount,

          status:
          finalStatus,

          duplicateTokenCount:
          duplicateDevices.length,

          hasImage:
          !!imageUrl,

          recipientSummary: {
            customers:
            finalRoleCounts.customers,

            admins:
            finalRoleCounts.admins,

            branchAdmins:
            finalRoleCounts.branchAdmins,
          },

          successSummary: {
            customers:
            successfulRoleCounts.customers,

            admins:
            successfulRoleCounts.admins,

            branchAdmins:
            successfulRoleCounts.branchAdmins,
          },

          failureSummary: {
            customers:
            failedRoleCounts.customers,

            admins:
            failedRoleCounts.admins,

            branchAdmins:
            failedRoleCounts.branchAdmins,
          },

          message:
          successCount > 0 ?
            (
                finalStatus ===
                "partial" ?
                  "Notification partially delivered." :
                  "Notification sent successfully."
              ) :
            "Notification could not be delivered to any device.",
        };
      } catch (error) {
        console.error(
            "[MANUAL_NOTIFICATION] ❌ FUNCTION FAILED",
            {
              errorCode:
            error &&
            error.code ?
              error.code :
              "",

              errorMessage:
            error &&
            error.message ?
              error.message :
              "",

              stack:
            error &&
            error.stack ?
              error.stack :
              "",
            },
        );

        if (
          error instanceof HttpsError
        ) {
          throw error;
        }

        throw new HttpsError(
            "internal",
            "Failed to send notification.",
        );
      }
    },
);
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
        // requestedAmount
        // ------------------------------------------------------
        //
        // null / undefined / empty
        //     = PAY REMAINING
        //
        // numeric value
        //     = PAY OTHER AMOUNT
        //
        // IMPORTANT:
        // We don't trust the amount from Flutter.
        //
        // razorpay.js checks it against the latest Firestore
        // outstanding balance.
        // ------------------------------------------------------

        let requestedAmount = null;

        if (
          data.requestedAmount !==
            undefined &&
          data.requestedAmount !==
            null &&
          String(
              data.requestedAmount,
          ).trim() !== ""
        ) {
          requestedAmount =
            Number(
                data.requestedAmount,
            );

          if (
            !Number.isFinite(
                requestedAmount,
            ) ||
            requestedAmount <= 0
          ) {
            throw new HttpsError(
                "invalid-argument",
                "requestedAmount must be greater than zero.",
            );
          }

          requestedAmount =
            Number(
                requestedAmount.toFixed(2),
            );
        }

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
        // Call Razorpay service
        // ------------------------------------------------------
        //
        // razorpay.js will:
        //
        // 1. Read latest booking.
        // 2. Verify customer ownership.
        // 3. Calculate latest outstanding.
        // 4. Validate requestedAmount.
        // 5. Create Razorpay order.
        // 6. Save payment attempt.
        //
        // ------------------------------------------------------

        const result =
          await createRazorpayOrder({
            tenantId:
              tenantId,

            bookingId:
              bookingId,

            userId:
              userId,

            requestedAmount:
              requestedAmount,
          });

        return result;
      } catch (error) {
        console.error(
            "createRazorpayOrder failed:",
            error,
        );

        // ------------------------------------------------------
        // Preserve Firebase HttpsError
        // ------------------------------------------------------

        if (
          error instanceof HttpsError
        ) {
          throw error;
        }

        const message =
          error &&
          error.message ?
            error.message :
            "Unable to create Razorpay order.";

        // ------------------------------------------------------
        // Expected payment validation errors
        // ------------------------------------------------------

        if (
          message.includes(
              "Payment amount",
          ) ||
          message.includes(
              "outstanding",
          ) ||
          message.includes(
              "no outstanding",
          ) ||
          message.includes(
              "not available for payment",
          ) ||
          message.includes(
              "not authorized",
          ) ||
          message.includes(
              "not configured",
          ) ||
          message.includes(
              "disabled",
          ) ||
          message.includes(
              "Booking not found",
          )
        ) {
          throw new HttpsError(
              "failed-precondition",
              message,
          );
        }

        // ------------------------------------------------------
        // Unknown backend error
        // ------------------------------------------------------

        throw new HttpsError(
            "internal",
            message,
        );
      }
    },
);
// ============================================================
// RAZORPAY CREATE CHECKOUT ORDER
// ============================================================
//
// NEW CUSTOMER BOOKING FLOW
//
// Review Booking
//      ↓
// Payment Screen
//      ↓
// createRazorpayCheckoutOrder()
//      ↓
// Razorpay Order
//      ↓
// Customer pays
//      ↓
// Payment verified
//      ↓
// Real booking is created
//
// IMPORTANT:
//
// This function DOES NOT create:
//
// tenants/{tenantId}/bookings/{bookingId}
//
// It creates only a temporary:
//
// tenants/{tenantId}/checkoutAttempts/{checkoutAttemptId}
//
// The real booking is created only after successful payment.
// ============================================================

exports.createRazorpayCheckoutOrder = onCall(
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

        const booking =
          data.booking;

        const requestedAmount =
          data.requestedAmount !== undefined &&
          data.requestedAmount !== null ?
            Number(data.requestedAmount) :
            null;

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
        // Validate booking payload
        // ------------------------------------------------------

        if (
          !booking ||
          typeof booking !== "object" ||
          Array.isArray(booking)
        ) {
          throw new HttpsError(
              "invalid-argument",
              "Booking data is required.",
          );
        }

        // ------------------------------------------------------
        // Customer ownership
        // ------------------------------------------------------
        //
        // Review screen sends the authenticated customer's UID.
        //
        // Backend does NOT allow one customer to create a
        // checkout using another customer's booking payload.
        // ------------------------------------------------------

        const authenticatedUserId =
          String(
              request.auth.uid || "",
          ).trim();

        const bookingCustomerId =
          String(
              booking.customerId ||
              booking.userId ||
              "",
          ).trim();

        if (!bookingCustomerId) {
          throw new HttpsError(
              "invalid-argument",
              "booking.customerId is required.",
          );
        }

        if (
          bookingCustomerId !==
          authenticatedUserId
        ) {
          throw new HttpsError(
              "permission-denied",
              "You are not authorized to create this checkout.",
          );
        }

        // ------------------------------------------------------
        // Tenant ownership
        // ------------------------------------------------------

        const bookingTenantId =
          String(
              booking.tenantId || "",
          ).trim();

        if (
          bookingTenantId &&
          bookingTenantId !== tenantId
        ) {
          throw new HttpsError(
              "permission-denied",
              "Booking does not belong to this tenant.",
          );
        }

        // ------------------------------------------------------
        // Validate requested amount
        // ------------------------------------------------------

        if (
          requestedAmount !== null &&
          (
            !Number.isFinite(
                requestedAmount,
            ) ||
            requestedAmount <= 0
          )
        ) {
          throw new HttpsError(
              "invalid-argument",
              "requestedAmount must be greater than zero.",
          );
        }

        // ------------------------------------------------------
        // Create Razorpay checkout order
        // ------------------------------------------------------

        const result =
          await createRazorpayCheckoutOrder({
            tenantId:
              tenantId,

            booking:
              booking,

            requestedAmount:
              requestedAmount,
          });

        // ------------------------------------------------------
        // Return result to Flutter
        // ------------------------------------------------------

        return result;
      } catch (error) {
        console.error(
            "createRazorpayCheckoutOrder failed:",
            error,
        );

        // Preserve Firebase HttpsError.
        if (
          error instanceof HttpsError
        ) {
          throw error;
        }

        // ------------------------------------------------------
        // Convert common validation errors
        // ------------------------------------------------------

        const message =
          error &&
          error.message ?
            error.message :
            "Unable to create Razorpay checkout order.";

        if (
          message.includes("required") ||
          message.includes("Invalid") ||
          message.includes("invalid")
        ) {
          throw new HttpsError(
              "invalid-argument",
              message,
          );
        }

        if (
          message.includes("authorized") ||
          message.includes("permission") ||
          message.includes("does not belong")
        ) {
          throw new HttpsError(
              "permission-denied",
              message,
          );
        }

        throw new HttpsError(
            "internal",
            message,
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
// }
//
// razorpay.js verifies:
//
// HMAC-SHA256(
//     orderId + "|" + paymentId
// )
//
// using the tenant-specific Razorpay Key Secret.
//
// Secret NEVER goes to Flutter.
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

        const result =
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
        // Support both return formats
        // ------------------------------------------------------
        //
        // Your updated razorpay.js may return:
        //
        // true
        //
        // OR:
        //
        // {
        //   verified: true,
        //   ...
        // }
        //
        // This wrapper supports both.
        // ------------------------------------------------------

        const verified =
          result === true ||
          (
            result &&
            result.verified === true
          );

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

        // ------------------------------------------------------
        // Preserve Firebase HttpsError
        // ------------------------------------------------------

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
