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
 * 2360 -> 2,360
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
 * Formats pickup date/time for the FCM notification.
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
// MSG91 WHATSAPP - ADMIN BOOKING NOTIFICATION
// ============================================================

/**
 * Formats a phone number for WhatsApp.
 *
 * Examples:
 * 8446442204
 * -> +918446442204
 *
 * +918446442204
 * -> +918446442204
 *
 * 00918446442204
 * -> +918446442204
 *
 * @param {*} value
 * @return {string}
 */
function normalizeWhatsAppPhone(value) {
  const raw = cleanString(value);

  if (!raw) {
    return "";
  }

  // Keep digits and an optional +.
  let digits = raw.replace(/[^\d+]/g, "");

  if (!digits) {
    return "";
  }

  if (digits.startsWith("00")) {
    digits = `+${digits.slice(2)}`;
  }

  if (digits.startsWith("+")) {
    return digits;
  }

  // Indian 10-digit mobile number.
  if (digits.length === 10) {
    return `+91${digits}`;
  }

  return `+${digits}`;
}


/**
 * Gets active admin WhatsApp phone numbers.
 *
 * Admin structure:
 *
 * tenants/{tenantId}/admins/{adminId}
 *
 * The phone field is used as the WhatsApp recipient.
 *
 * @param {string} tenantId
 * @return {Promise<Array>}
 */
async function getAdminWhatsAppRecipients(tenantId) {
  const cleanTenantId = cleanString(tenantId);

  if (!cleanTenantId) {
    return [];
  }

  const adminsSnapshot = await db
      .collection("tenants")
      .doc(cleanTenantId)
      .collection("admins")
      .where("isActive", "==", true)
      .get();

  const phoneSet = new Set();

  for (const adminDoc of adminsSnapshot.docs) {
    const adminData = adminDoc.data() || {};

    const phone = normalizeWhatsAppPhone(
        adminData.phone,
    );

    if (phone) {
      phoneSet.add(phone);
    } else {
      logger.warn(
          "Active admin has no valid WhatsApp phone.",
          {
            tenantId: cleanTenantId,
            adminId: adminDoc.id,
          },
      );
    }
  }

  return Array.from(phoneSet);
}


/**
 * Formats booking date/time in India time.
 *
 * Example:
 * 26 Sep 2026, 3:00 PM
 *
 * @param {*} value
 * @return {string}
 */
function formatBookingDateTime(value) {
  const date = toDate(value);

  if (!date) {
    return "Not available";
  }

  return new Intl.DateTimeFormat(
      "en-IN",
      {
        timeZone: "Asia/Kolkata",
        day: "2-digit",
        month: "short",
        year: "numeric",
        hour: "numeric",
        minute: "2-digit",
        hour12: true,
      },
  ).format(date);
}


/**
 * Sends the new booking WhatsApp template
 * to all active admins.
 *
 * IMPORTANT:
 * WhatsApp errors are completely isolated from FCM.
 *
 * @param {object} params
 * @return {Promise<object>}
 */
async function sendAdminBookingWhatsApp({
  tenantId,
  bookingId,
  customerName,
  carName,
  pickupDateTime,
  returnDateTime,
  pickupBranchName,
  amount,
  paymentStatus,
}) {
  try {
    const cleanTenantId = cleanString(
        tenantId,
    );

    const tenantSnapshot = await db
        .collection("tenants")
        .doc(cleanTenantId)
        .get();

    if (!tenantSnapshot.exists) {
      logger.warn(
          "Tenant not found for booking WhatsApp.",
          {
            tenantId: cleanTenantId,
            bookingId,
          },
      );

      return {
        success: false,
        sentCount: 0,
        recipientCount: 0,
      };
    }

    const tenantData =
      tenantSnapshot.data() || {};

    const msg91 =
      cleanMap(tenantData.msg91);

    // ----------------------------------------------------------
    // MSG91 ENABLED
    // ----------------------------------------------------------

    if (msg91.enabled !== true) {
      logger.info(
          "MSG91 WhatsApp is disabled.",
          {
            tenantId: cleanTenantId,
            bookingId,
          },
      );

      return {
        success: false,
        skipped: true,
        sentCount: 0,
        recipientCount: 0,
      };
    }

    // ----------------------------------------------------------
    // CHANNEL
    // ----------------------------------------------------------

    if (
      cleanString(msg91.channel).toLowerCase() !==
      "whatsapp"
    ) {
      logger.warn(
          "MSG91 channel is not WhatsApp.",
          {
            tenantId: cleanTenantId,
            bookingId,
            channel: msg91.channel,
          },
      );

      return {
        success: false,
        skipped: true,
        sentCount: 0,
        recipientCount: 0,
      };
    }

    // ----------------------------------------------------------
    // MSG91 CONFIGURATION
    // ----------------------------------------------------------

    const authKey =
      cleanString(msg91.authKey);

    const integratedNumber =
      cleanString(msg91.integratedNumber);

    const templateName =
      cleanString(
          msg91.bookingTemplateName,
          "new_booking_admin",
      );

    const languageCode =
      cleanString(
          msg91.bookingLanguageCode,
          "en",
      );

    const namespace =
      cleanString(
          msg91.bookingNamespace,
          cleanString(msg91.namespace),
      );

    if (
      !authKey ||
      !integratedNumber ||
      !templateName ||
      !languageCode ||
      !namespace
    ) {
      logger.error(
          "MSG91 booking WhatsApp configuration is incomplete.",
          {
            tenantId: cleanTenantId,
            bookingId,
            hasAuthKey: Boolean(authKey),
            hasIntegratedNumber:
              Boolean(integratedNumber),
            templateName,
            languageCode,
            hasNamespace: Boolean(namespace),
          },
      );

      return {
        success: false,
        skipped: true,
        sentCount: 0,
        recipientCount: 0,
      };
    }

    // ----------------------------------------------------------
    // ACTIVE ADMIN PHONE NUMBERS
    // ----------------------------------------------------------

    const recipients =
      await getAdminWhatsAppRecipients(
          cleanTenantId,
      );

    if (recipients.length === 0) {
      logger.info(
          "No active admin WhatsApp recipients found.",
          {
            tenantId: cleanTenantId,
            bookingId,
          },
      );

      return {
        success: false,
        skipped: true,
        sentCount: 0,
        recipientCount: 0,
      };
    }

    // ----------------------------------------------------------
    // TEMPLATE VARIABLES
    //
    // new_booking_admin
    //
    // {{1}} Booking ID
    // {{2}} Customer Name
    // {{3}} Vehicle
    // {{4}} Pickup
    // {{5}} Return
    // {{6}} Location
    // {{7}} Amount
    // {{8}} Payment
    // ----------------------------------------------------------

    const components = {
      body_1: {
        type: "text",
        value: cleanString(
            bookingId,
            "N/A",
        ),
      },

      body_2: {
        type: "text",
        value: cleanString(
            customerName,
            "A customer",
        ),
      },

      body_3: {
        type: "text",
        value: cleanString(
            carName,
            "Vehicle",
        ),
      },

      body_4: {
        type: "text",
        value: formatBookingDateTime(
            pickupDateTime,
        ),
      },

      body_5: {
        type: "text",
        value: formatBookingDateTime(
            returnDateTime,
        ),
      },

      body_6: {
        type: "text",
        value: cleanString(
            pickupBranchName,
            "Rentocar",
        ),
      },

      body_7: {
        type: "text",
        value: formatCurrency(
            amount,
        ),
      },

      body_8: {
        type: "text",
        value: cleanString(
            paymentStatus,
            "Pending",
        ),
      },
    };

    // ----------------------------------------------------------
    // MSG91 REQUEST
    // ----------------------------------------------------------

    const response = await fetch(
        "https://api.msg91.com/api/v5/whatsapp/whatsapp-outbound-message/bulk/",
        {
          method: "POST",

          headers: {
            "Content-Type": "application/json",
            "authkey": authKey,
          },

          body: JSON.stringify({
            integrated_number:
              integratedNumber,

            content_type:
              "template",

            payload: {
              messaging_product:
                "whatsapp",

              type:
                "template",

              template: {
                name:
                  templateName,

                language: {
                  code:
                    languageCode,

                  policy:
                    "deterministic",
                },

                namespace:
                  namespace,

                to_and_components:
                  recipients.map(
                      (phone) => ({
                        to: [
                          phone,
                        ],

                        components:
                          components,
                      }),
                  ),
              },
            },
          }),
        },
    );

    const responseText =
      await response.text();

    // ----------------------------------------------------------
    // MSG91 ERROR
    // ----------------------------------------------------------

    if (!response.ok) {
      logger.error(
          "MSG91 booking WhatsApp request failed.",
          {
            tenantId: cleanTenantId,
            bookingId,
            status:
              response.status,
            response:
              responseText,
          },
      );

      return {
        success: false,
        sentCount: 0,
        recipientCount:
          recipients.length,
      };
    }

    // ----------------------------------------------------------
    // SUCCESS
    // ----------------------------------------------------------

    logger.info(
        "Admin booking WhatsApp notification sent.",
        {
          tenantId: cleanTenantId,
          bookingId,
          recipientCount:
            recipients.length,
          templateName,
          response:
            responseText,
        },
    );

    return {
      success: true,
      sentCount:
        recipients.length,
      recipientCount:
        recipients.length,
    };
  } catch (error) {
    // ----------------------------------------------------------
    // VERY IMPORTANT:
    //
    // WhatsApp failure must NEVER throw into the
    // booking trigger and must NOT break FCM.
    // ----------------------------------------------------------

    logger.error(
        "Admin booking WhatsApp notification failed.",
        {
          tenantId,
          bookingId,
          error:
            error &&
            error.message ?
              error.message :
              String(error),
        },
    );

    return {
      success: false,
      sentCount: 0,
      recipientCount: 0,
    };
  }
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

  const tenantRef =
    db
        .collection("tenants")
        .doc(cleanTenantId);

  const adminsSnapshot =
    await tenantRef
        .collection("admins")
        .where(
            "isActive",
            "==",
            true,
        )
        .get();

  if (adminsSnapshot.empty) {
    logger.info(
        "No active admins found for tenant.",
        {
          tenantId:
            cleanTenantId,
        },
    );

    return [];
  }

  const tokenSet =
    new Set();

  const deviceReads =
    [];

  for (
    const adminDoc of
    adminsSnapshot.docs
  ) {
    const devicesRef =
      adminDoc.ref
          .collection(
              "notificationDevices",
          );

    deviceReads.push(
        devicesRef
            .where(
                "isActive",
                "==",
                true,
            )
            .get(),
    );
  }

  const deviceSnapshots =
    await Promise.all(
        deviceReads,
    );

  for (
    const devicesSnapshot of
    deviceSnapshots
  ) {
    for (
      const deviceDoc of
      devicesSnapshot.docs
    ) {
      const deviceData =
        deviceDoc.data() ||
        {};

      const token =
        cleanString(
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
        deviceTenantId !==
          cleanTenantId
      ) {
        logger.warn(
            "Ignoring admin device with tenant mismatch.",
            {
              tenantId:
                cleanTenantId,

              deviceTenantId,

              deviceId:
                deviceDoc.id,
            },
        );

        continue;
      }

      tokenSet.add(
          token,
      );
    }
  }

  return Array.from(
      tokenSet,
  );
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
    formatCurrency(
        amount,
    );

  const formattedPickup =
    formatPickupDateTime(
        pickupDateTime,
    );

  const safeCustomerName =
    customerName ||
    "A customer";

  const safeCarName =
    carName ||
    "Vehicle";

  const safeBranchName =
    pickupBranchName ||
    "Rentocar";

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
    type:
      "booking_created",

    tenantId:
      cleanString(
          tenantId,
      ),

    bookingId:
      cleanString(
          bookingId,
      ),

    customerName:
      cleanString(
          customerName,
      ),

    carName:
      cleanString(
          carName,
      ),

    amount:
      String(
          cleanNumber(
              amount,
          ),
      ),

    currency:
      "INR",

    pickupDateTime:
      pickupDateTime &&
      typeof pickupDateTime.toDate ===
        "function" ?
        pickupDateTime
            .toDate()
            .toISOString() :
        cleanString(
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
    const tokenChunk of
    tokenChunks
  ) {
    try {
      const response =
        await messaging
            .sendEachForMulticast({
              tokens:
                tokenChunk,

              notification: {
                title,
                body,
              },

              data,

              android: {
                priority:
                  "high",

                notification: {
                  channelId:
                    "booking_notifications",

                  sound:
                    "default",

                  priority:
                    "high",

                  defaultVibrateTimings:
                    true,

                  notificationCount:
                    1,
                },
              },

              apns: {
                payload: {
                  aps: {
                    sound:
                      "default",

                    badge:
                      1,
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
          (
              result,
              index,
          ) => {
            if (!result.success) {
              logger.warn(
                  "Admin FCM delivery failed.",
                  {
                    tenantId,
                    bookingId,

                    token:
                      tokenChunk[
                          index
                      ],

                    error:
                      result.error &&
                      result.error.message ?
                        result.error.message :
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
              error &&
              error.message ?
                error.message :
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
    tokenCount:
      tokens.length,
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

        region:
          REGION,

        retry:
          true,
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
          snapshot.data() ||
          {};

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
                path:
                  snapshot.ref.path,
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
          documentTenantId !==
            tenantId
        ) {
          logger.error(
              "Booking tenantId does not match document path.",
              {
                tenantId,
                documentTenantId,
                bookingId,
                path:
                  snapshot.ref.path,
              },
          );

          return;
        }

        // ------------------------------------------------------
        // Booking source/channel.
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
                cleanString(
                    data.status,
                ),
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
          cleanMap(
              data.car,
          );

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
        // Security deposit is NOT added to rental amount.
        // ------------------------------------------------------

        const amount =
          cleanNumber(
              data.totalAmount,
          );

        // ------------------------------------------------------
        // Pickup
        // ------------------------------------------------------

        const pickupDateTime =
          data.pickupDateTime ||
          null;

        // ------------------------------------------------------
        // Return
        // ------------------------------------------------------

        const returnDateTime =
          data.returnDateTime ||
          null;

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
        // SEND EXISTING FCM NOTIFICATION
        //
        // This remains independent and continues working
        // exactly as before.
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
        // SEND WHATSAPP NOTIFICATION
        //
        // This is deliberately separate from FCM.
        //
        // If MSG91 fails:
        // - FCM has already been sent
        // - function does not fail because of WhatsApp
        // ------------------------------------------------------

        const whatsappResult =
          await sendAdminBookingWhatsApp({
            tenantId,
            bookingId,
            customerName,
            carName,
            pickupDateTime,
            returnDateTime,
            pickupBranchName,
            amount,
            paymentStatus,
          });

        // ------------------------------------------------------
        // FINAL LOGGING
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

              // FCM
              successCount:
                result.successCount,

              failureCount:
                result.failureCount,

              tokenCount:
                result.tokenCount,

              // WhatsApp
              whatsappSuccess:
                whatsappResult.success,

              whatsappSentCount:
                whatsappResult.sentCount,

              whatsappRecipientCount:
                whatsappResult.recipientCount,
            },
        );
      },
  );
