const {
  onDocumentUpdated,
} = require("firebase-functions/v2/firestore");

const {
  logger,
} = require("firebase-functions");

const {
  getFirestore,
  getMessaging,
} = require("firebase-admin");

const REGION = "asia-south1";
const MAX_TOKENS_PER_BATCH = 500;
const TIME_ZONE = "Asia/Kolkata";
const CURRENCY = "INR";

const STATUS = {
  PENDING: "pending",
  CONFIRMED: "confirmed",
  PICKUP_PENDING: "pickupPending",
  ACTIVE: "active",
  RETURN_PENDING: "returnPending",
  COMPLETED: "completed",
  CANCELLED: "cancelled",
  REJECTED: "rejected",
  NO_SHOW: "noShow",
};


// ================================================================
// BASIC HELPERS
// ================================================================

/**
 * Converts a value into a trimmed string.
 *
 * @param {*} value Value to convert.
 * @param {string} fallback Fallback value.
 * @return {string} Clean string.
 */
function cleanString(value, fallback = "") {
  if (value === null || value === undefined) {
    return fallback;
  }

  const text = String(value).trim();

  return text || fallback;
}


/**
 * Converts a value into a finite number.
 *
 * @param {*} value Value to convert.
 * @param {number} fallback Fallback value.
 * @return {number} Clean number.
 */
function cleanNumber(value, fallback = 0) {
  if (
    typeof value === "number" &&
    Number.isFinite(value)
  ) {
    return value;
  }

  if (typeof value === "string") {
    const parsed = Number(value);

    if (Number.isFinite(parsed)) {
      return parsed;
    }
  }

  return fallback;
}


/**
 * Converts Firestore/date values into JavaScript Date.
 *
 * @param {*} value Date-like value.
 * @return {Date|null} Converted date or null.
 */
function toDate(value) {
  if (!value) {
    return null;
  }

  if (value instanceof Date) {
    return value;
  }

  if (
    value &&
    typeof value.toDate === "function"
  ) {
    return value.toDate();
  }

  if (
    value &&
    typeof value.toMillis === "function"
  ) {
    return new Date(value.toMillis());
  }

  if (typeof value === "string") {
    const parsed = new Date(value);

    if (!Number.isNaN(parsed.getTime())) {
      return parsed;
    }
  }

  return null;
}


/**
 * Formats an amount using Indian number formatting.
 *
 * @param {*} amount Amount to format.
 * @return {string} Formatted amount.
 */
function formatCurrency(amount) {
  const value = cleanNumber(amount);

  return new Intl.NumberFormat(
      "en-IN",
      {
        maximumFractionDigits: 2,
        minimumFractionDigits: 0,
      },
  ).format(value);
}


/**
 * Formats a date/time using India timezone.
 *
 * @param {*} value Date-like value.
 * @return {string} Formatted date/time.
 */
function formatDateTime(value) {
  const date = toDate(value);

  if (!date) {
    return "Not specified";
  }

  return new Intl.DateTimeFormat(
      "en-IN",
      {
        timeZone: TIME_ZONE,
        day: "2-digit",
        month: "short",
        hour: "numeric",
        minute: "2-digit",
        hour12: true,
      },
  ).format(date);
}


/**
 * Converts a booking status into readable text.
 *
 * @param {*} value Status value.
 * @return {string} Human-readable status.
 */
function prettyStatus(value) {
  const status = cleanString(value)
      .replace(
          /([a-z])([A-Z])/g,
          "$1 $2",
      )
      .replace(
          /[_-]+/g,
          " ",
      )
      .trim();

  if (!status) {
    return "Updated";
  }

  return status
      .split(" ")
      .map(
          (word) =>
            word.charAt(0).toUpperCase() +
        word.slice(1),
      )
      .join(" ");
}


/**
 * Splits an array into chunks.
 *
 * @param {Array} items Items to split.
 * @param {number} size Chunk size.
 * @return {Array[]} Array chunks.
 */
function chunkArray(items, size) {
  const chunks = [];

  for (
    let index = 0;
    index < items.length;
    index += size
  ) {
    chunks.push(
        items.slice(
            index,
            index + size,
        ),
    );
  }

  return chunks;
}


/**
 * Compares two Firestore-compatible values.
 *
 * @param {*} a First value.
 * @param {*} b Second value.
 * @return {boolean} Whether values are equal.
 */
function valuesEqual(a, b) {
  if (
    a === null ||
    a === undefined
  ) {
    return (
      b === null ||
      b === undefined
    );
  }

  if (
    b === null ||
    b === undefined
  ) {
    return false;
  }

  const dateA = toDate(a);
  const dateB = toDate(b);

  if (dateA && dateB) {
    return (
      dateA.getTime() ===
      dateB.getTime()
    );
  }

  if (
    typeof a === "number" ||
    typeof b === "number"
  ) {
    return (
      cleanNumber(a) ===
      cleanNumber(b)
    );
  }

  return String(a) === String(b);
}


// ================================================================
// TENANT VALIDATION
// ================================================================

/**
 * Validates and returns the booking tenant ID.
 *
 * @param {string} eventTenantId Tenant ID from document path.
 * @param {Object} data Booking document data.
 * @return {string} Valid tenant ID.
 */
function getTenantId(
    eventTenantId,
    data,
) {
  const pathTenantId =
    cleanString(eventTenantId);

  const dataTenantId =
    cleanString(data.tenantId);

  if (!pathTenantId) {
    throw new Error(
        "Booking document has no tenant ID in path.",
    );
  }

  if (
    dataTenantId &&
    dataTenantId !== pathTenantId
  ) {
    throw new Error(
        "Booking tenant ID does not match document tenant path.",
    );
  }

  return pathTenantId;
}


// ================================================================
// CUSTOMER DEVICE TOKENS
// ================================================================

/**
 * Gets active FCM tokens for a customer.
 *
 * @param {Object} params Function parameters.
 * @param {string} params.tenantId Tenant ID.
 * @param {string} params.customerUid Customer Firebase UID.
 * @return {Promise<string[]>} Active FCM tokens.
 */
async function getCustomerNotificationTokens({
  tenantId,
  customerUid,
}) {
  const cleanTenantId =
    cleanString(tenantId);

  const cleanCustomerUid =
    cleanString(customerUid);

  if (
    !cleanTenantId ||
    !cleanCustomerUid
  ) {
    return [];
  }

  const db = getFirestore();

  const devicesRef = db
      .collection("tenants")
      .doc(cleanTenantId)
      .collection("customers")
      .doc(cleanCustomerUid)
      .collection("notificationDevices");

  const snapshot = await devicesRef
      .where(
          "isActive",
          "==",
          true,
      )
      .get();

  const tokens = new Set();

  for (const doc of snapshot.docs) {
    const data = doc.data() || {};

    const token =
      cleanString(data.fcmToken);

    if (!token) {
      continue;
    }

    const deviceTenantId =
      cleanString(data.tenantId);

    if (
      deviceTenantId &&
      deviceTenantId !== cleanTenantId
    ) {
      continue;
    }

    const deviceUid =
      cleanString(data.firebaseUid);

    if (
      deviceUid &&
      deviceUid !== cleanCustomerUid
    ) {
      continue;
    }

    const role =
      cleanString(data.role);

    if (
      role &&
      role !== "customer"
    ) {
      continue;
    }

    tokens.add(token);
  }

  return Array.from(tokens);
}


// ================================================================
// BOOKING DISPLAY DATA
// ================================================================

/**
 * Extracts normalized booking information.
 *
 * @param {Object} data Booking document.
 * @return {Object} Normalized booking information.
 */
function getBookingDisplayData(data) {
  const car =
    data.car &&
    typeof data.car === "object" ?
      data.car :
      {};

  const pickupBranch =
    data.pickupBranch &&
    typeof data.pickupBranch === "object" ?
      data.pickupBranch :
      {};

  const pricing =
    data.pricing &&
    typeof data.pricing === "object" ?
      data.pricing :
      {};

  return {
    customerName:
      cleanString(
          data.customerName,
          "Customer",
      ),

    carName:
      cleanString(
          car.name,
          cleanString(
              data.carName,
              "your vehicle",
          ),
      ),

    registrationNumber:
      cleanString(
          car.registrationNumber,
      ),

    pickupBranch:
      cleanString(
          pickupBranch.name,
          "Pickup location",
      ),

    pickupCity:
      cleanString(
          pickupBranch.city,
      ),

    pickupDateTime:
      data.pickupDateTime,

    returnDateTime:
      data.returnDateTime,

    totalAmount:
      cleanNumber(
          data.totalAmount,
          cleanNumber(
              pricing.totalAmount,
          ),
      ),

    paidAmount:
      cleanNumber(
          data.paidAmount,
      ),

    refundAmount:
      cleanNumber(
          data.refundAmount,
      ),

    balanceAmount:
      cleanNumber(
          data.balanceAmount,
      ),

    discountAmount:
      cleanNumber(
          data.discountAmount,
      ),

    securityDeposit:
      cleanNumber(
          data.securityDeposit,
      ),

    paymentStatus:
      cleanString(
          data.paymentStatus,
          "pending",
      ),

    paymentMethod:
      cleanString(
          data.paymentMethod,
      ),

    status:
      cleanString(
          data.status,
          STATUS.PENDING,
      ),

    includedKm:
      cleanNumber(
          data.includedKm,
      ),

    extraKmAmount:
      cleanNumber(
          data.extraKmAmount,
      ),

    extraTimeAmount:
      cleanNumber(
          data.extraTimeAmount,
      ),

    addOnsAmount:
      cleanNumber(
          data.addOnsAmount,
      ),
  };
}


// ================================================================
// EVENT DETECTION
// ================================================================

/**
 * Detects meaningful customer-facing booking changes.
 *
 * @param {Object} before Previous booking document.
 * @param {Object} after Updated booking document.
 * @return {Object[]} Detected events.
 */
function detectBookingEvents(
    before,
    after,
) {
  const events = [];

  const oldStatus =
    cleanString(before.status);

  const newStatus =
    cleanString(after.status);

  if (oldStatus !== newStatus) {
    events.push({
      type: "status_changed",
      oldStatus,
      newStatus,
    });
  }

  const paymentChanged =
    !valuesEqual(
        before.paidAmount,
        after.paidAmount,
    ) ||
    !valuesEqual(
        before.refundAmount,
        after.refundAmount,
    ) ||
    !valuesEqual(
        before.paymentStatus,
        after.paymentStatus,
    ) ||
    !valuesEqual(
        before.paymentMethod,
        after.paymentMethod,
    );

  if (paymentChanged) {
    events.push({
      type: "payment_changed",
    });
  }

  const amountChanged =
    !valuesEqual(
        before.totalAmount,
        after.totalAmount,
    ) ||
    !valuesEqual(
        before.discountAmount,
        after.discountAmount,
    ) ||
    !valuesEqual(
        before.balanceAmount,
        after.balanceAmount,
    ) ||
    !valuesEqual(
        before.extraKmAmount,
        after.extraKmAmount,
    ) ||
    !valuesEqual(
        before.extraTimeAmount,
        after.extraTimeAmount,
    ) ||
    !valuesEqual(
        before.addOnsAmount,
        after.addOnsAmount,
    );

  if (amountChanged) {
    events.push({
      type: "amount_changed",
    });
  }

  if (
    !valuesEqual(
        before.pickupDateTime,
        after.pickupDateTime,
    )
  ) {
    events.push({
      type: "pickup_schedule_changed",
    });
  }

  if (
    !valuesEqual(
        before.returnDateTime,
        after.returnDateTime,
    )
  ) {
    events.push({
      type: "return_schedule_changed",
    });
  }

  const oldBranch =
    before.pickupBranch || {};

  const newBranch =
    after.pickupBranch || {};

  if (
    cleanString(oldBranch.name) !==
      cleanString(newBranch.name) ||
    cleanString(oldBranch.city) !==
      cleanString(newBranch.city)
  ) {
    events.push({
      type: "pickup_branch_changed",
    });
  }

  if (
    !valuesEqual(
        before.securityDeposit,
        after.securityDeposit,
    ) ||
    !valuesEqual(
        before.securityDepositType,
        after.securityDepositType,
    ) ||
    !valuesEqual(
        before.securityDepositDetails,
        after.securityDepositDetails,
    )
  ) {
    events.push({
      type: "security_deposit_changed",
    });
  }

  if (
    !valuesEqual(
        before.includedKm,
        after.includedKm,
    ) ||
    !valuesEqual(
        before.kmPackageName,
        after.kmPackageName,
    ) ||
    !valuesEqual(
        before.unlimitedKm,
        after.unlimitedKm,
    )
  ) {
    events.push({
      type: "km_package_changed",
    });
  }

  return events;
}


// ================================================================
// NOTIFICATION BUILDER
// ================================================================

/**
 * Builds a customer-facing notification.
 *
 * @param {Object} params Notification parameters.
 * @param {Object} params.event Detected event.
 * @param {Object} params.before Previous booking.
 * @param {Object} params.after Updated booking.
 * @return {Object|null} Notification payload.
 */
function buildNotification({
  event,
  before,
  after,
}) {
  const booking =
    getBookingDisplayData(after);

  const previous =
    getBookingDisplayData(before);

  if (
    event.type ===
    "status_changed"
  ) {
    switch (event.newStatus) {
      case STATUS.CONFIRMED:
        return {
          title:
            "✅ Booking Confirmed",
          body:
            `Your booking for ${booking.carName} ` +
            `is confirmed. Pickup: ` +
            `${formatDateTime(
                booking.pickupDateTime,
            )}.`,
          type:
            "booking_confirmed",
        };

      case STATUS.PICKUP_PENDING:
        return {
          title:
            "🚗 Pickup Ready",
          body:
            `Your ${booking.carName} booking ` +
            `is ready for pickup. Pickup: ` +
            `${formatDateTime(
                booking.pickupDateTime,
            )} • ${booking.pickupBranch}.`,
          type:
            "pickup_pending",
        };

      case STATUS.ACTIVE:
        return {
          title:
            "🔑 Rental Started",
          body:
            `Your ${booking.carName} rental ` +
            `has started. Have a safe journey!`,
          type:
            "rental_started",
        };

      case STATUS.RETURN_PENDING:
        return {
          title:
            "🔄 Return Required",
          body:
            `Your ${booking.carName} rental ` +
            `is ready for return. Scheduled return: ` +
            `${formatDateTime(
                booking.returnDateTime,
            )}.`,
          type:
            "return_pending",
        };

      case STATUS.COMPLETED:
        return {
          title:
            "🎉 Booking Completed",
          body:
            `Your ${booking.carName} booking ` +
            `has been completed successfully.`,
          type:
            "booking_completed",
        };

      case STATUS.CANCELLED:
        return {
          title:
            "❌ Booking Cancelled",
          body:
            `Your booking for ${booking.carName} ` +
            `has been cancelled.`,
          type:
            "booking_cancelled",
        };

      case STATUS.REJECTED:
        return {
          title:
            "❌ Booking Rejected",
          body:
            `Your booking for ${booking.carName} ` +
            `was rejected.`,
          type:
            "booking_rejected",
        };

      case STATUS.NO_SHOW:
        return {
          title:
            "⚠️ Booking Updated",
          body:
            `Your ${booking.carName} booking ` +
            `has been marked as no-show.`,
          type:
            "booking_no_show",
        };

      default:
        return {
          title:
            "🔔 Booking Updated",
          body:
            `Your ${booking.carName} booking ` +
            `status changed to ${prettyStatus(
                event.newStatus,
            )}.`,
          type:
            "booking_status_changed",
        };
    }
  }

  if (
    event.type ===
    "payment_changed"
  ) {
    const paidDifference =
      booking.paidAmount -
      previous.paidAmount;

    const refundDifference =
      booking.refundAmount -
      previous.refundAmount;

    if (refundDifference > 0.009) {
      return {
        title:
          `↩️ Payment Refunded • ₹${formatCurrency(
              refundDifference,
          )}`,
        body:
          `A refund has been recorded for ` +
          `your ${booking.carName} booking. ` +
          `Paid: ₹${formatCurrency(
              booking.paidAmount,
          )} • Balance: ₹${formatCurrency(
              booking.balanceAmount,
          )}.`,
        type:
          "payment_refunded",
      };
    }

    if (paidDifference > 0.009) {
      return {
        title:
          `💳 Payment Received • ₹${formatCurrency(
              paidDifference,
          )}`,
        body:
          `Your payment for ${booking.carName} ` +
          `has been recorded. Paid: ` +
          `₹${formatCurrency(
              booking.paidAmount,
          )} • Balance: ₹${formatCurrency(
              booking.balanceAmount,
          )}.`,
        type:
          "payment_received",
      };
    }

    return {
      title:
        "💳 Payment Updated",
      body:
        `Payment details for your ${booking.carName} ` +
        `booking have been updated. Status: ` +
        `${prettyStatus(
            booking.paymentStatus,
        )}.`,
      type:
        "payment_updated",
    };
  }

  if (
    event.type ===
    "amount_changed"
  ) {
    const oldTotal =
      previous.totalAmount;

    const newTotal =
      booking.totalAmount;

    if (
      booking.discountAmount >
      previous.discountAmount
    ) {
      const discountDifference =
        booking.discountAmount -
        previous.discountAmount;

      return {
        title:
          `🎁 Discount Updated • ₹${formatCurrency(
              discountDifference,
          )}`,
        body:
          `A discount of ₹${formatCurrency(
              discountDifference,
          )} was applied to your ` +
          `${booking.carName} booking. Total: ` +
          `₹${formatCurrency(
              newTotal,
          )}.`,
        type:
          "discount_updated",
      };
    }

    if (
      !valuesEqual(
          oldTotal,
          newTotal,
      )
    ) {
      return {
        title:
          "💰 Booking Amount Updated",
        body:
          `Your ${booking.carName} booking ` +
          `amount changed from ₹${formatCurrency(
              oldTotal,
          )} to ₹${formatCurrency(
              newTotal,
          )}.`,
        type:
          "booking_amount_updated",
      };
    }

    return {
      title:
        "💰 Booking Updated",
      body:
        `Charges for your ${booking.carName} ` +
        `booking have been updated. Total: ` +
        `₹${formatCurrency(
            newTotal,
        )}.`,
      type:
        "booking_charges_updated",
    };
  }

  if (
    event.type ===
    "pickup_schedule_changed"
  ) {
    return {
      title:
        "📅 Pickup Schedule Updated",
      body:
        `Your pickup time changed to ` +
        `${formatDateTime(
            booking.pickupDateTime,
        )}.`,
      type:
        "pickup_schedule_changed",
    };
  }

  if (
    event.type ===
    "return_schedule_changed"
  ) {
    return {
      title:
        "📅 Return Schedule Updated",
      body:
        `Your return time changed to ` +
        `${formatDateTime(
            booking.returnDateTime,
        )}.`,
      type:
        "return_schedule_changed",
    };
  }

  if (
    event.type ===
    "pickup_branch_changed"
  ) {
    return {
      title:
        "📍 Pickup Location Updated",
      body:
        `Your pickup location is now ` +
        `${booking.pickupBranch}.`,
      type:
        "pickup_branch_changed",
    };
  }

  if (
    event.type ===
    "security_deposit_changed"
  ) {
    return {
      title:
        "🔐 Security Deposit Updated",
      body:
        `Your security deposit for ` +
        `${booking.carName} is ₹${formatCurrency(
            booking.securityDeposit,
        )}.`,
      type:
        "security_deposit_changed",
    };
  }

  if (
    event.type ===
    "km_package_changed"
  ) {
    return {
      title:
        "🛣️ KM Package Updated",
      body:
        `Your KM package for ${booking.carName} ` +
        `has been updated.`,
      type:
        "km_package_changed",
    };
  }

  return null;
}


// ================================================================
// SEND CUSTOMER NOTIFICATION
// ================================================================

/**
 * Sends a notification to all active customer devices.
 *
 * @param {Object} params Notification parameters.
 * @param {string} params.tenantId Tenant ID.
 * @param {string} params.customerUid Customer Firebase UID.
 * @param {string} params.bookingId Booking ID.
 * @param {Object} params.notification Notification payload.
 * @param {Object} params.booking Normalized booking.
 * @return {Promise<Object>} FCM delivery statistics.
 */
async function sendCustomerNotification({
  tenantId,
  customerUid,
  bookingId,
  notification,
  booking,
}) {
  const tokens =
    await getCustomerNotificationTokens({
      tenantId,
      customerUid,
    });

  if (tokens.length === 0) {
    logger.warn(
        "No active customer notification tokens found.",
        {
          tenantId,
          customerUid,
          bookingId,
        },
    );

    return {
      tokenCount: 0,
      successCount: 0,
      failureCount: 0,
    };
  }

  const messaging =
    getMessaging();

  const chunks =
    chunkArray(
        tokens,
        MAX_TOKENS_PER_BATCH,
    );

  let successCount = 0;
  let failureCount = 0;

  for (
    const tokenChunk of chunks
  ) {
    const message = {
      tokens: tokenChunk,

      notification: {
        title:
          notification.title,
        body:
          notification.body,
      },

      data: {
        type:
          cleanString(
              notification.type,
          ),

        tenantId:
          cleanString(
              tenantId,
          ),

        bookingId:
          cleanString(
              bookingId,
          ),

        customerId:
          cleanString(
              customerUid,
          ),

        customerName:
          cleanString(
              booking.customerName,
          ),

        carName:
          cleanString(
              booking.carName,
          ),

        bookingStatus:
          cleanString(
              booking.status,
          ),

        paymentStatus:
          cleanString(
              booking.paymentStatus,
          ),

        amount:
          String(
              booking.totalAmount,
          ),

        paidAmount:
          String(
              booking.paidAmount,
          ),

        balanceAmount:
          String(
              booking.balanceAmount,
          ),

        currency:
          CURRENCY,

        pickupBranch:
          cleanString(
              booking.pickupBranch,
          ),
      },

      android: {
        priority: "high",

        notification: {
          channelId:
            "booking_notifications",

          sound:
            "default",

          defaultVibrateTimings:
            true,
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
    };

    const response =
      await messaging
          .sendEachForMulticast(
              message,
          );

    successCount +=
      response.successCount;

    failureCount +=
      response.failureCount;

    response.responses.forEach(
        (result, index) => {
          if (result.success) {
            return;
          }

          logger.warn(
              "Customer FCM token failed.",
              {
                tenantId,
                customerUid,
                bookingId,
                tokenIndex: index,
                error:
              result.error &&
              result.error.message ?
                result.error.message :
                "Unknown FCM error",
              },
          );
        },
    );
  }

  return {
    tokenCount:
      tokens.length,

    successCount,

    failureCount,
  };
}


// ================================================================
// MAIN CUSTOMER BOOKING NOTIFICATION FUNCTION
// ================================================================

/**
 * Sends customer notifications when a booking changes.
 */
exports.notifyCustomerOnBookingUpdate =
  onDocumentUpdated(
      {
        document:
        "tenants/{tenantId}/bookings/{bookingId}",

        region:
        REGION,

        retry:
        true,
      },

      async (event) => {
        const startedAt =
        Date.now();

        logger.info(
            "Customer booking notification trigger started.",
            {
              tenantId:
            event.params.tenantId,

              bookingId:
            event.params.bookingId,
            },
        );

        if (
          !event.data ||
        !event.data.before ||
        !event.data.after
        ) {
          logger.warn(
              "Booking update event has no before/after snapshots.",
          );

          return;
        }

        const before =
        event.data.before.data() || {};

        const after =
        event.data.after.data() || {};

        const tenantId =
        getTenantId(
            event.params.tenantId,
            after,
        );

        const bookingId =
        cleanString(
            event.params.bookingId,
        );

        if (!bookingId) {
          logger.warn(
              "Booking update has no booking ID.",
          );

          return;
        }

        // ------------------------------------------------------------
        // CUSTOMER UID
        // ------------------------------------------------------------

        const customerUid =
        cleanString(
            after.customerFirebaseUid,
            cleanString(
                after.customerUid,
            ),
        );

        if (!customerUid) {
          logger.warn(
              "Booking has no customer Firebase UID.",
              {
                tenantId,
                bookingId,
              },
          );

          return;
        }

        // ------------------------------------------------------------
        // DETECT EVENTS
        // ------------------------------------------------------------

        const events =
        detectBookingEvents(
            before,
            after,
        );

        if (events.length === 0) {
          logger.info(
              "Booking updated but no customer-notifiable fields changed.",
              {
                tenantId,
                bookingId,
              },
          );

          return;
        }

        const booking =
        getBookingDisplayData(
            after,
        );

        // ------------------------------------------------------------
        // ONLY ONE NOTIFICATION PER BOOKING UPDATE
        //
        // Priority:
        //
        // 1. Status
        // 2. Payment
        // 3. Amount
        // 4. Other booking changes
        // ------------------------------------------------------------

        let selectedEvent = null;

        const statusEvent =
        events.find(
            (item) =>
              item.type ===
            "status_changed",
        );

        if (statusEvent) {
          selectedEvent = statusEvent;
        } else {
          const paymentEvent =
          events.find(
              (item) =>
                item.type ===
              "payment_changed",
          );

          if (paymentEvent) {
            selectedEvent =
            paymentEvent;
          } else {
            const amountEvent =
            events.find(
                (item) =>
                  item.type ===
                "amount_changed",
            );

            if (amountEvent) {
              selectedEvent =
              amountEvent;
            } else {
              selectedEvent =
              events[0];
            }
          }
        }

        if (!selectedEvent) {
          return;
        }

        // ------------------------------------------------------------
        // BUILD NOTIFICATION
        // ------------------------------------------------------------

        const notification =
        buildNotification({
          event:
            selectedEvent,

          before,

          after,
        });

        if (!notification) {
          logger.info(
              "No notification template found.",
              {
                tenantId,
                bookingId,
                eventType:
              selectedEvent.type,
              },
          );

          return;
        }

        // ------------------------------------------------------------
        // SEND
        // ------------------------------------------------------------

        const result =
        await sendCustomerNotification({
          tenantId,
          customerUid,
          bookingId,
          notification,
          booking,
        });

        logger.info(
            "Customer booking notification completed.",
            {
              tenantId,
              bookingId,
              customerUid,

              eventType:
            selectedEvent.type,

              notificationType:
            notification.type,

              title:
            notification.title,

              tokenCount:
            result.tokenCount,

              successCount:
            result.successCount,

              failureCount:
            result.failureCount,

              durationMs:
            Date.now() - startedAt,
            },
        );
      },
  );
