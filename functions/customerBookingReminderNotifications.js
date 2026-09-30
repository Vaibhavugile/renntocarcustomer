"use strict";

/* eslint-disable require-jsdoc */

const {
  onSchedule,
} = require("firebase-functions/v2/scheduler");

const {
  getFirestore,
} = require("firebase-admin/firestore");

const {
  getMessaging,
} = require("firebase-admin/messaging");

const {
  logger,
} = require("firebase-functions");

const db = getFirestore();

const REGION = "asia-south1";

const CHANNEL_ID = "booking_notifications";

const MAX_TOKENS_PER_BATCH = 500;

// ------------------------------------------------------------
// HELPERS
// ------------------------------------------------------------

function cleanString(value, fallback = "") {
  if (
    value === null ||
    value === undefined
  ) {
    return fallback;
  }

  const valueString = String(value).trim();

  return valueString || fallback;
}

function cleanNumber(value, fallback = 0) {
  const number = Number(value);

  return Number.isFinite(number) ?
    number :
    fallback;
}

function normalizeStatus(status) {
  return cleanString(
      status,
      "",
  )
      .toLowerCase()
      .replace(/[\s-]+/g, "_");
}

function toDate(value) {
  if (!value) {
    return null;
  }

  if (value instanceof Date) {
    return value;
  }

  if (
    typeof value.toDate ===
    "function"
  ) {
    return value.toDate();
  }

  if (
    typeof value ===
    "string"
  ) {
    const date = new Date(value);

    return Number.isNaN(
        date.getTime(),
    ) ?
      null :
      date;
  }

  if (
    typeof value ===
    "number"
  ) {
    const date = new Date(value);

    return Number.isNaN(
        date.getTime(),
    ) ?
      null :
      date;
  }

  return null;
}


function formatDateTime(value) {
  const date = toDate(value);

  if (!date) {
    return "";
  }

  return new Intl.DateTimeFormat(
      "en-IN",
      {
        day: "2-digit",
        month: "short",
        year: "numeric",
        hour: "numeric",
        minute: "2-digit",
        hour12: true,
        timeZone: "Asia/Kolkata",
      },
  ).format(date);
}

function formatTime(value) {
  const date = toDate(value);

  if (!date) {
    return "";
  }

  return new Intl.DateTimeFormat(
      "en-IN",
      {
        hour: "numeric",
        minute: "2-digit",
        hour12: true,
        timeZone: "Asia/Kolkata",
      },
  ).format(date);
}

function chunkArray(array, size) {
  const result = [];

  for (
    let i = 0;
    i < array.length;
    i += size
  ) {
    result.push(
        array.slice(
            i,
            i + size,
        ),
    );
  }

  return result;
}

// ------------------------------------------------------------
// BOOKING DATA
// ------------------------------------------------------------

function getBookingInfo(data) {
  const car =
    data.car &&
    typeof data.car ===
      "object" ?
      data.car :
      {};

  const pickupBranch =
    data.pickupBranch &&
    typeof data.pickupBranch ===
      "object" ?
      data.pickupBranch :
      {};

  return {
    customerUid:
      cleanString(
          data.customerFirebaseUid,
          cleanString(
              data.customerUid,
              cleanString(
                  data.userId,
              ),
          ),
      ),

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
          cleanString(
              data.registrationNumber,
          ),
      ),

    branchName:
      cleanString(
          pickupBranch.name,
          cleanString(
              data.branchName,
              "your pickup location",
          ),
      ),

    totalAmount:
      cleanNumber(
          data.totalAmount,
      ),

    status:
      normalizeStatus(
          data.status,
      ),

    pickupDateTime:
      data.pickupDateTime,

    returnDateTime:
      data.returnDateTime,
  };
}

// ------------------------------------------------------------
// ACTIVE BOOKING CHECK
// ------------------------------------------------------------

function isEligibleBooking(booking) {
  const blockedStatuses = [
    "cancelled",
    "canceled",
    "rejected",
    "completed",
    "no_show",
    "noshow",
  ];

  if (
    blockedStatuses.includes(
        booking.status,
    )
  ) {
    return false;
  }

  return true;
}

// ------------------------------------------------------------
// CUSTOMER TOKENS
// ------------------------------------------------------------

async function getCustomerTokens({
  tenantId,
  customerUid,
}) {
  if (
    !tenantId ||
    !customerUid
  ) {
    return [];
  }

  const snapshot =
    await db
        .collection("tenants")
        .doc(tenantId)
        .collection("customers")
        .doc(customerUid)
        .collection("notificationDevices")
        .where(
            "isActive",
            "==",
            true,
        )
        .get();

  const tokens = new Set();

  for (
    const doc of snapshot.docs
  ) {
    const data =
      doc.data() || {};

    const token =
      cleanString(
          data.fcmToken,
      );

    if (!token) {
      continue;
    }

    if (
      cleanString(
          data.tenantId,
      ) &&
      cleanString(
          data.tenantId,
      ) !== tenantId
    ) {
      continue;
    }

    if (
      cleanString(
          data.firebaseUid,
      ) &&
      cleanString(
          data.firebaseUid,
      ) !== customerUid
    ) {
      continue;
    }

    if (
      data.role &&
      cleanString(
          data.role,
      ) !== "customer"
    ) {
      continue;
    }

    tokens.add(token);
  }

  return Array.from(tokens);
}

// ------------------------------------------------------------
// PREMIUM MESSAGE
// ------------------------------------------------------------

function buildNotification({
  type,
  reminder,
  booking,
  eventDate,
}) {
  const car =
    booking.carName;

  const time =
    formatTime(
        eventDate,
    );

  const fullDate =
    formatDateTime(
        eventDate,
    );

  // ----------------------------------------------------------
  // PICKUP
  // ----------------------------------------------------------

  if (
    type === "pickup"
  ) {
    if (
      reminder === "4h"
    ) {
      return {
        type:
          "pickup_reminder_4h",

        title:
          "Your journey starts soon ✨",

        body:
          `${car} pickup is scheduled in 4 hours · ${time}. ` +
          "We'll be ready for you.",

        eventDate:
          fullDate,
      };
    }

    if (
      reminder === "3h"
    ) {
      return {
        type:
          "pickup_reminder_3h",

        title:
          "Your car is getting ready 🚗",

        body:
          `${car} pickup is in 3 hours at ${time}. ` +
          "Everything is set for your journey.",

        eventDate:
          fullDate,
      };
    }

    if (
      reminder === "2h"
    ) {
      return {
        type:
          "pickup_reminder_2h",

        title:
          "2 hours to go ✨",

        body:
          `Your ${car} pickup is approaching · ${fullDate}.`,

        eventDate:
          fullDate,
      };
    }

    if (
      reminder === "1h"
    ) {
      return {
        type:
          "pickup_reminder_1h",

        title:
          "Your pickup is in 1 hour 🚗",

        body:
          `${car} will be ready at ${time}. ` +
          "Have your required documents ready for a smooth handover.",

        eventDate:
          fullDate,
      };
    }

    if (
      reminder === "30m"
    ) {
      return {
        type:
          "pickup_reminder_30m",

        title:
          "Almost time. ⏱️",

        body:
          `Your ${car} pickup is in 30 minutes · ${time}.`,

        eventDate:
          fullDate,
      };
    }

    return {
      type:
        "pickup_reminder_now",

      title:
        "Your pickup time is now 🚗",

      body:
        `Your scheduled pickup for ${car} is now. ` +
        "Have a great journey. ✨",

      eventDate:
        fullDate,
    };
  }

  // ----------------------------------------------------------
  // RETURN
  // ----------------------------------------------------------

  if (
    reminder === "4h"
  ) {
    return {
      type:
        "return_reminder_4h",

      title:
        "Your return is coming up ✨",

      body:
        `Your ${car} return is scheduled in 4 hours · ${time}. ` +
        "We hope you're enjoying the journey.",

      eventDate:
        fullDate,
    };
  }

  if (
    reminder === "3h"
  ) {
    return {
      type:
        "return_reminder_3h",

      title:
        "3 hours until return 🚗",

      body:
        `Your ${car} return is scheduled for ${time}. ` +
        "Please plan your journey accordingly.",

      eventDate:
        fullDate,
    };
  }

  if (
    reminder === "2h"
  ) {
    return {
      type:
        "return_reminder_2h",

      title:
        "2 hours to return",

      body:
        `Your ${car} return is approaching · ${fullDate}.`,

      eventDate:
        fullDate,
    };
  }

  if (
    reminder === "1h"
  ) {
    return {
      type:
        "return_reminder_1h",

      title:
        "Your return is in 1 hour 🔄",

      body:
        "Please make your way toward the designated return location. " +
        `Return time: ${time}.`,

      eventDate:
        fullDate,
    };
  }

  if (
    reminder === "30m"
  ) {
    return {
      type:
        "return_reminder_30m",

      title:
        "30 minutes to return ⏱️",

      body:
        `Your ${car} return time is approaching · ${time}.`,

      eventDate:
        fullDate,
    };
  }

  return {
    type:
      "return_reminder_now",

    title:
      "Return time is now 🔄",

    body:
      `Your scheduled ${car} return time has arrived. ` +
      "Thank you for choosing us. ✨",

    eventDate:
      fullDate,
  };
}

// ------------------------------------------------------------
// REMINDER DEFINITIONS
// ------------------------------------------------------------

const REMINDERS = [
  {
    key: "4h",
    milliseconds:
      4 * 60 * 60 * 1000,
  },
  {
    key: "3h",
    milliseconds:
      3 * 60 * 60 * 1000,
  },
  {
    key: "2h",
    milliseconds:
      2 * 60 * 60 * 1000,
  },
  {
    key: "1h",
    milliseconds:
      1 * 60 * 60 * 1000,
  },
  {
    key: "30m",
    milliseconds:
      30 * 60 * 1000,
  },
  {
    key: "now",
    milliseconds: 0,
  },
];

// ------------------------------------------------------------
// FIND REMINDER
// ------------------------------------------------------------

function getReminderForEvent(
    eventDate,
    now,
) {
  const difference =
    eventDate.getTime() -
    now.getTime();

  // We run every minute.
  //
  // Give a ±90 second window so a scheduler delay
  // does not cause the reminder to be missed.

  const tolerance =
    90 * 1000;

  for (
    const reminder of REMINDERS
  ) {
    const distance =
      Math.abs(
          difference -
        reminder.milliseconds,
      );

    if (
      distance <= tolerance
    ) {
      return reminder;
    }
  }

  return null;
}

// ------------------------------------------------------------
// IDEMPOTENCY / CLAIM
// ------------------------------------------------------------

async function claimReminder({
  bookingRef,
  reminderKey,
}) {
  const reminderRef =
    bookingRef
        .collection(
            "notificationReminders",
        )
        .doc(
            reminderKey,
        );

  const claimed =
    await db.runTransaction(
        async (transaction) => {
          const snapshot =
          await transaction.get(
              reminderRef,
          );

          const existing =
          snapshot.exists ?
            snapshot.data() || {} :
            null;

          // Already sent.
          if (
            existing &&
          existing.status ===
            "sent"
          ) {
            return false;
          }

          // Someone else is currently
          // processing it.
          if (
            existing &&
          existing.status ===
            "processing"
          ) {
            const processingAt =
            existing.processingAt &&
            typeof existing
                .processingAt
                .toDate ===
              "function" ?
              existing.processingAt.toDate() :
              null;

            if (
              processingAt &&
            Date.now() -
              processingAt.getTime() <
              5 * 60 * 1000
            ) {
              return false;
            }
          }

          transaction.set(
              reminderRef,
              {
                status:
              "processing",

                reminderKey,

                processingAt:
              new Date(),

                updatedAt:
              new Date(),
              },
              {
                merge: true,
              },
          );

          return true;
        },
    );

  return {
    claimed,
    reminderRef,
  };
}

// ------------------------------------------------------------
// MARK AS SENT
// ------------------------------------------------------------

async function markReminderSent({
  reminderRef,
  result,
}) {
  await reminderRef.set(
      {
        status:
        "sent",

        sentAt:
        new Date(),

        tokenCount:
        result.tokenCount,

        successCount:
        result.successCount,

        failureCount:
        result.failureCount,

        updatedAt:
        new Date(),
      },
      {
        merge: true,
      },
  );
}

// ------------------------------------------------------------
// MARK FAILED
// ------------------------------------------------------------

async function markReminderFailed({
  reminderRef,
  error,
}) {
  await reminderRef.set(
      {
        status:
        "failed",

        error:
        cleanString(
            error &&
          error.message,
            "Unknown notification error",
        ),

        failedAt:
        new Date(),

        updatedAt:
        new Date(),
      },
      {
        merge: true,
      },
  );
}

// ------------------------------------------------------------
// SEND FCM
// ------------------------------------------------------------

async function sendReminderNotification({
  tenantId,
  bookingId,
  booking,
  notification,
}) {
  const tokens =
    await getCustomerTokens({
      tenantId,
      customerUid:
        booking.customerUid,
    });

  if (
    tokens.length === 0
  ) {
    logger.warn(
        "No customer notification devices.",
        {
          tenantId,
          bookingId,
          customerUid:
          booking.customerUid,
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
      tokens:
        tokenChunk,

      notification: {
        title:
          notification.title,

        body:
          notification.body,
      },

      data: {
        type:
          notification.type,

        tenantId:
          tenantId,

        bookingId:
          bookingId,

        customerId:
          booking.customerUid,

        customerName:
          booking.customerName,

        carName:
          booking.carName,

        registrationNumber:
          booking.registrationNumber,

        bookingStatus:
          booking.status,

        amount:
          String(
              booking.totalAmount,
          ),

        currency:
          "INR",

        reminder:
          notification.type,

        eventDate:
          notification.eventDate,

        pickupBranch:
          booking.branchName,

        action:
          "booking_details",
      },

      android: {
        priority:
          "high",

        notification: {
          channelId:
            CHANNEL_ID,

          sound:
            "default",

          defaultVibrateTimings:
            true,
        },
      },

      apns: {
        payload: {
          aps: {
            "sound":
              "default",

            "badge":
              1,

            "content-available":
              1,
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
        (
            result,
            index,
        ) => {
          if (
            result.success
          ) {
            return;
          }

          logger.warn(
              "Customer reminder FCM token failed.",
              {
                tenantId,
                bookingId,

                tokenIndex:
              index,

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

// ------------------------------------------------------------
// PROCESS ONE EVENT
// ------------------------------------------------------------

async function processReminder({
  tenantId,
  bookingRef,
  bookingId,
  bookingData,
  type,
  eventDate,
  reminder,
}) {
  const booking =
    getBookingInfo(
        bookingData,
    );

  if (
    !booking.customerUid
  ) {
    return;
  }

  if (
    !isEligibleBooking(
        booking,
    )
  ) {
    return;
  }

  const notification =
    buildNotification({
      type,

      reminder:
        reminder.key,

      booking,

      eventDate,
    });

  const reminderKey =
    `${type}_${reminder.key}`;

  const {
    claimed,
    reminderRef,
  } =
    await claimReminder({
      bookingRef,

      reminderKey,
    });

  if (!claimed) {
    return;
  }

  try {
    logger.info(
        "Sending premium booking reminder.",
        {
          tenantId,

          bookingId,

          type,

          reminder:
          reminder.key,

          eventDate:
          eventDate.toISOString(),
        },
    );

    const result =
      await sendReminderNotification({
        tenantId,

        bookingId,

        booking,

        notification,
      });

    await markReminderSent({
      reminderRef,

      result,
    });

    logger.info(
        "Premium booking reminder sent.",
        {
          tenantId,

          bookingId,

          type,

          reminder:
          reminder.key,

          successCount:
          result.successCount,

          failureCount:
          result.failureCount,
        },
    );
  } catch (error) {
    await markReminderFailed({
      reminderRef,

      error,
    });

    logger.error(
        "Premium booking reminder failed.",
        {
          tenantId,

          bookingId,

          type,

          reminder:
          reminder.key,

          error:
          error.message,
        },
    );

    throw error;
  }
}

// ------------------------------------------------------------
// SCHEDULED FUNCTION
// ------------------------------------------------------------
//
// Runs every minute.
//
// It checks a rolling window around:
// 4h, 3h, 2h, 1h, 30m and now.
//
// ------------------------------------------------------------

exports.sendCustomerBookingTimeReminders =
  onSchedule(
      {
        schedule:
        "* * * * *",

        timeZone:
        "Asia/Kolkata",

        region:
        REGION,

        retryCount:
        3,

        memory:
        "256MiB",

        timeoutSeconds:
        120,
      },

      async () => {
        const startedAt =
        Date.now();

        const now =
        new Date();

        const earliestEvent =
        new Date(
            now.getTime() -
          90 * 1000,
        );

        const latestEvent =
        new Date(
            now.getTime() +
          4 * 60 * 60 * 1000 +
          90 * 1000,
        );

        logger.info(
            "Customer booking reminder scheduler started.",
            {
              now:
            now.toISOString(),

              earliestEvent:
            earliestEvent.toISOString(),

              latestEvent:
            latestEvent.toISOString(),
            },
        );

        // --------------------------------------------------------
        // PICKUP REMINDERS
        // --------------------------------------------------------

        const pickupSnapshot =
        await db
            .collectionGroup(
                "bookings",
            )
            .where(
                "pickupDateTime",
                ">=",
                earliestEvent,
            )
            .where(
                "pickupDateTime",
                "<=",
                latestEvent,
            )
            .get();

        // --------------------------------------------------------
        // RETURN REMINDERS
        // --------------------------------------------------------

        const returnSnapshot =
        await db
            .collectionGroup(
                "bookings",
            )
            .where(
                "returnDateTime",
                ">=",
                earliestEvent,
            )
            .where(
                "returnDateTime",
                "<=",
                latestEvent,
            )
            .get();

        let processed = 0;

        // --------------------------------------------------------
        // PICKUP
        // --------------------------------------------------------

        for (
          const doc of
          pickupSnapshot.docs
        ) {
          const data =
          doc.data() || {};

          const tenantId =
          cleanString(
              data.tenantId ||
            (
              doc.ref.parent
                  .parent &&
              doc.ref.parent
                  .parent.id
            ),
          );

          if (!tenantId) {
            continue;
          }

          const eventDate =
          toDate(
              data.pickupDateTime,
          );

          if (!eventDate) {
            continue;
          }

          const reminder =
          getReminderForEvent(
              eventDate,
              now,
          );

          if (!reminder) {
            continue;
          }

          await processReminder({
            tenantId,

            bookingRef:
            doc.ref,

            bookingId:
            doc.id,

            bookingData:
            data,

            type:
            "pickup",

            eventDate,

            reminder,
          });

          processed++;
        }

        // --------------------------------------------------------
        // RETURN
        // --------------------------------------------------------

        for (
          const doc of
          returnSnapshot.docs
        ) {
          const data =
          doc.data() || {};

          const tenantId =
          cleanString(
              data.tenantId ||
            (
              doc.ref.parent
                  .parent &&
              doc.ref.parent
                  .parent.id
            ),
          );

          if (!tenantId) {
            continue;
          }

          const eventDate =
          toDate(
              data.returnDateTime,
          );

          if (!eventDate) {
            continue;
          }

          const reminder =
          getReminderForEvent(
              eventDate,
              now,
          );

          if (!reminder) {
            continue;
          }

          await processReminder({
            tenantId,

            bookingRef:
            doc.ref,

            bookingId:
            doc.id,

            bookingData:
            data,

            type:
            "return",

            eventDate,

            reminder,
          });

          processed++;
        }

        logger.info(
            "Customer booking reminder scheduler completed.",
            {
              pickupBookings:
            pickupSnapshot.size,

              returnBookings:
            returnSnapshot.size,

              processed,

              durationMs:
            Date.now() -
            startedAt,
            },
        );
      },
  );
