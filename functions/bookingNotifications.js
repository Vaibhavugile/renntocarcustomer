const {
  onDocumentCreated,
} = require("firebase-functions/v2/firestore");

const {
  logger,
} = require("firebase-functions");

const {
  getFirestore,
} = require("firebase-admin/firestore");

const {
  getMessaging,
} = require("firebase-admin/messaging");


// ============================================================
// CONFIGURATION
// ============================================================

const REGION = "asia-south1";

const MAX_TOKENS_PER_BATCH = 500;


// ============================================================
// FIRESTORE / FCM
// ============================================================

const db = getFirestore();

const messaging = getMessaging();


// ============================================================
// HELPERS
// ============================================================

/**
 * Safely converts a value to a trimmed string.
 *
 * @param {*} value
 * @param {string} fallback
 * @return {string}
 */
function cleanString(value, fallback = "") {
  if (value === null || value === undefined) {
    return fallback;
  }

  const result = String(value).trim();

  return result || fallback;
}


/**
 * Safely converts a value to a number.
 *
 * @param {*} value
 * @param {number} fallback
 * @return {number}
 */
function cleanNumber(value, fallback = 0) {
  const number = Number(value);

  if (!Number.isFinite(number)) {
    return fallback;
  }

  return number;
}


/**
 * Formats an amount as Indian Rupees.
 *
 * Example:
 * 2360 -> ₹2,360
 *
 * @param {*} value
 * @return {string}
 */
function formatCurrency(value) {
  const amount = cleanNumber(value);

  return new Intl.NumberFormat("en-IN", {
    maximumFractionDigits: 2,
    minimumFractionDigits: 0,
  }).format(amount);
}


/**
 * Converts Firestore Timestamp / Date / string into Date.
 *
 * @param {*} value
 * @return {Date|null}
 */
function toDate(value) {
  if (!value) {
    return null;
  }

  if (
    value &&
    typeof value.toDate === "function"
  ) {
    return value.toDate();
  }

  if (value instanceof Date) {
    return value;
  }

  const date = new Date(value);

  if (Number.isNaN(date.getTime())) {
    return null;
  }

  return date;
}


/**
 * Formats pickup date/time for the notification.
 *
 * Example:
 * 24 Sep, 7:00 PM
 *
 * @param {*} value
 * @return {string}
 */
function formatPickupDateTime(value) {
  const date = toDate(value);

  if (!date) {
    return "Pickup time not available";
  }

  return new Intl.DateTimeFormat(
      "en-IN",
      {
        timeZone: "Asia/Kolkata",
        day: "2-digit",
        month: "short",
        hour: "numeric",
        minute: "2-digit",
        hour12: true,
      },
  ).format(date);
}


/**
 * Reads a nested object safely.
 *
 * @param {*} value
 * @return {object}
 */
function cleanMap(value) {
  if (
    value &&
    typeof value === "object" &&
    !Array.isArray(value)
  ) {
    return value;
  }

  return {};
}


/**
 * Splits an array into chunks.
 *
 * @param {Array} array
 * @param {number} size
 * @return {Array<Array>}
 */
function chunkArray(array, size) {
  const chunks = [];

  for (
    let index = 0;
    index < array.length;
    index += size
  ) {
    chunks.push(
        array.slice(index, index + size),
    );
  }

  return chunks;
}


// ============================================================
// GET ADMIN DEVICE TOKENS
// ============================================================

/**
 * Gets all active FCM tokens belonging to active admins
 * of the specified tenant.
 *
 * Structure:
 *
 * tenants/{tenantId}/admins/{adminId}
 *     /notificationDevices/{deviceId}
 *
 * @param {string} tenantId
 * @return {Promise<Array>}
 */
async function getAdminNotificationTokens(
    tenantId,
) {
  const cleanTenantId =
    cleanString(tenantId);

  if (!cleanTenantId) {
    return [];
  }

  const tenantRef = db
      .collection("tenants")
      .doc(cleanTenantId);

  const adminsSnapshot = await tenantRef
      .collection("admins")
      .where("isActive", "==", true)
      .get();

  if (adminsSnapshot.empty) {
    logger.info(
        "No active admins found for tenant.",
        {
          tenantId: cleanTenantId,
        },
    );

    return [];
  }

  const tokenSet = new Set();

  const deviceReads = [];

  for (
    const adminDoc of adminsSnapshot.docs
  ) {
    const devicesRef = adminDoc.ref
        .collection("notificationDevices");

    deviceReads.push(
        devicesRef
            .where("isActive", "==", true)
            .get(),
    );
  }

  const deviceSnapshots =
    await Promise.all(deviceReads);

  for (
    const devicesSnapshot of deviceSnapshots
  ) {
    for (
      const deviceDoc of devicesSnapshot.docs
    ) {
      const deviceData =
        deviceDoc.data() || {};

      const token = cleanString(
          deviceData.fcmToken,
      );

      const deviceTenantId =
        cleanString(
            deviceData.tenantId,
        );

      const isAdmin =
        deviceData.isAdmin === true;

      const isActive =
        deviceData.isActive === true;

      if (!token) {
        continue;
      }

      if (!isActive) {
        continue;
      }

      if (!isAdmin) {
        continue;
      }

      if (
        deviceTenantId &&
        deviceTenantId !== cleanTenantId
      ) {
        logger.warn(
            "Ignoring admin device with tenant mismatch.",
            {
              tenantId: cleanTenantId,
              deviceTenantId,
              deviceId: deviceDoc.id,
            },
        );

        continue;
      }

      tokenSet.add(token);
    }
  }

  return Array.from(tokenSet);
}


// ============================================================
// SEND NOTIFICATION TO ADMIN DEVICES
// ============================================================

/**
 * Sends a new-booking notification to all active admin devices.
 *
 * @param {object} params
 * @return {Promise<object>}
 */
async function sendNewBookingNotification({
  tenantId,
  bookingId,
  customerName,
  carName,
  amount,
  pickupDateTime,
  pickupBranchName,
  paymentStatus,
  bookingStatus,
}) {
  const tokens =
    await getAdminNotificationTokens(
        tenantId,
    );

  if (tokens.length === 0) {
    logger.info(
        "No active admin notification devices found.",
        {
          tenantId,
          bookingId,
        },
    );

    return {
      successCount: 0,
      failureCount: 0,
      tokenCount: 0,
    };
  }

  const formattedAmount =
    formatCurrency(amount);

  const formattedPickup =
    formatPickupDateTime(
        pickupDateTime,
    );

  const safeCustomerName =
    customerName || "A customer";

  const safeCarName =
    carName || "Vehicle";

  const safeBranchName =
    pickupBranchName || "Rentocar";

  // ----------------------------------------------------------
  // PREMIUM NOTIFICATION
  // ----------------------------------------------------------

  const title =
    `🚗 New Booking • ₹${formattedAmount}`;

  const body =
    `${safeCustomerName} booked ${safeCarName}. ` +
    `Pickup: ${formattedPickup} • ${safeBranchName}`;

  // ----------------------------------------------------------
  // FCM DATA
  //
  // All values must be strings for FCM data payloads.
  // ----------------------------------------------------------

  const data = {
    type: "booking_created",

    tenantId:
      cleanString(tenantId),

    bookingId:
      cleanString(bookingId),

    customerName:
      cleanString(customerName),

    carName:
      cleanString(carName),

    amount:
      String(
          cleanNumber(amount),
      ),

    currency: "INR",

    pickupDateTime:
      pickupDateTime &&
      typeof pickupDateTime.toDate === "function"
        ? pickupDateTime.toDate().toISOString()
        : cleanString(
            pickupDateTime,
          ),

    pickupBranch:
      cleanString(
          pickupBranchName,
      ),

    paymentStatus:
      cleanString(
          paymentStatus,
      ),

    bookingStatus:
      cleanString(
          bookingStatus,
      ),
  };

  let successCount = 0;
  let failureCount = 0;

  const tokenChunks =
    chunkArray(
        tokens,
        MAX_TOKENS_PER_BATCH,
    );

  for (
    const tokenChunk of tokenChunks
  ) {
    try {
      const response =
        await messaging.sendEachForMulticast({
          tokens: tokenChunk,

          notification: {
            title,
            body,
          },

          data,

          android: {
            priority: "high",

            notification: {
              channelId:
                "booking_notifications",

              sound: "default",

              priority: "high",

              defaultVibrateTimings: true,

              notificationCount:
                1,
            },
          },

          apns: {
            payload: {
              aps: {
                sound: "default",

                badge: 1,
              },
            },
          },
        });

      successCount +=
        response.successCount;

      failureCount +=
        response.failureCount;

      // --------------------------------------------------------
      // Log individual failures.
      // --------------------------------------------------------

      response.responses.forEach(
          (result, index) => {
            if (!result.success) {
              logger.warn(
                  "Admin FCM delivery failed.",
                  {
                    tenantId,
                    bookingId,
                    token:
                      tokenChunk[index],
                    error:
                      result.error?.message ||
                      "Unknown FCM error",
                  },
              );
            }
          },
      );
    } catch (error) {
      logger.error(
          "Admin FCM multicast send failed.",
          {
            tenantId,
            bookingId,
            error:
              error?.message ||
              String(error),
          },
      );

      failureCount +=
        tokenChunk.length;
    }
  }

  return {
    successCount,
    failureCount,
    tokenCount: tokens.length,
  };
}


// ============================================================
// NEW BOOKING FIRESTORE TRIGGER
// ============================================================
//
// Trigger:
//
// tenants/{tenantId}/bookings/{bookingId}
//
// This fires ONLY when the booking document is first created.
//
// It does NOT fire every time the booking is updated.
//
// ============================================================

exports.notifyAdminsOnNewBooking =
  onDocumentCreated(
      {
        document:
          "tenants/{tenantId}/bookings/{bookingId}",

        region: REGION,

        retry: true,
      },

      async (event) => {
        const snapshot =
          event.data;

        if (!snapshot) {
          logger.warn(
              "New booking event has no document data.",
          );

          return;
        }

        const data =
          snapshot.data() || {};

        const tenantId =
          cleanString(
              event.params.tenantId ||
              data.tenantId,
          );

        const bookingId =
          cleanString(
              event.params.bookingId ||
              data.bookingId ||
              snapshot.id,
          );

        // ------------------------------------------------------
        // Validate tenant.
        // ------------------------------------------------------

        if (!tenantId) {
          logger.error(
              "New booking has no tenantId.",
              {
                bookingId,
                path: snapshot.ref.path,
              },
          );

          return;
        }

        // ------------------------------------------------------
        // Validate booking tenant against path.
        // ------------------------------------------------------

        const documentTenantId =
          cleanString(
              data.tenantId,
          );

        if (
          documentTenantId &&
          documentTenantId !== tenantId
        ) {
          logger.error(
              "Booking tenantId does not match document path.",
              {
                tenantId,
                documentTenantId,
                bookingId,
                path: snapshot.ref.path,
              },
          );

          return;
        }

        // ------------------------------------------------------
        // Only process real customer/app bookings.
        //
        // If later you want admin-created bookings to also
        // generate notifications, this can be changed.
        // ------------------------------------------------------

        const bookingSource =
          cleanString(
              data.bookingSource,
          );

        const bookingChannel =
          cleanString(
              data.bookingChannel,
          );

        logger.info(
            "New booking notification trigger started.",
            {
              tenantId,
              bookingId,
              bookingSource,
              bookingChannel,
              status:
                cleanString(data.status),
            },
        );

        // ------------------------------------------------------
        // Customer
        // ------------------------------------------------------

        const customerName =
          cleanString(
              data.customerName,
              "A customer",
          );

        // ------------------------------------------------------
        // Car
        // ------------------------------------------------------

        const car =
          cleanMap(data.car);

        const carName =
          cleanString(
              car.name ||
              data.carName,
              "Vehicle",
          );

        // ------------------------------------------------------
        // Amount
        //
        // IMPORTANT:
        // Use totalAmount.
        //
        // Security deposit is NOT added to the rental amount.
        // ------------------------------------------------------

        const amount =
          cleanNumber(
              data.totalAmount,
          );

        // ------------------------------------------------------
        // Pickup
        // ------------------------------------------------------

        const pickupDateTime =
          data.pickupDateTime || null;

        // ------------------------------------------------------
        // Pickup branch
        // ------------------------------------------------------

        const pickupBranch =
          cleanMap(
              data.pickupBranch,
          );

        const pickupBranchName =
          cleanString(
              pickupBranch.name,
              "Rentocar",
          );

        // ------------------------------------------------------
        // Payment
        // ------------------------------------------------------

        const paymentStatus =
          cleanString(
              data.paymentStatus,
              "pending",
          );

        const bookingStatus =
          cleanString(
              data.status,
              "pending",
          );

        // ------------------------------------------------------
        // Send notification.
        // ------------------------------------------------------

        const result =
          await sendNewBookingNotification({
            tenantId,
            bookingId,
            customerName,
            carName,
            amount,
            pickupDateTime,
            pickupBranchName,
            paymentStatus,
            bookingStatus,
          });

        // ------------------------------------------------------
        // Final logging
        // ------------------------------------------------------

        logger.info(
            "New booking admin notification completed.",
            {
              tenantId,
              bookingId,
              customerName,
              carName,
              amount,
              paymentStatus,
              bookingStatus,
              pickupBranchName,
              successCount:
                result.successCount,
              failureCount:
                result.failureCount,
              tokenCount:
                result.tokenCount,
            },
        );
      },
  );