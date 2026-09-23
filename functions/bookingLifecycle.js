const {onSchedule} = require("firebase-functions/v2/scheduler");
const {logger} = require("firebase-functions");
const admin = require("firebase-admin");

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

const REGION = "asia-south1";
const TIME_ZONE = "Asia/Kolkata";

const BATCH_SIZE = 500;
const MAX_BATCHES_PER_RUN = 20;

const STATUS = {
  CONFIRMED: "confirmed",
  PICKUP_PENDING: "pickupPending",
  ACTIVE: "active",
  RETURN_PENDING: "returnPending",
};

/**
 * Gets and validates the tenant ID for a booking.
 *
 * Expected structure:
 *
 * tenants/{tenantId}/bookings/{bookingId}
 *
 * Top-level bookings/{bookingId} documents are ignored.
 *
 * @param {FirebaseFirestore.QueryDocumentSnapshot} doc Booking document.
 * @param {Object} data Booking document data.
 * @return {string} Valid tenant ID or an empty string.
 */
function getTenantIdFromBooking(doc, data) {
  const collectionRef = doc.ref.parent;

  if (!collectionRef) {
    return "";
  }

  // ----------------------------------------------------------
  // DIRECT PARENT MUST BE "bookings"
  // ----------------------------------------------------------

  if (collectionRef.id !== "bookings") {
    logger.warn(
        "Skipping booking with invalid parent collection",
        {
          path: doc.ref.path,
          parentCollection: collectionRef.id,
        },
    );

    return "";
  }

  // ----------------------------------------------------------
  // EXPECT:
  //
  // tenants/{tenantId}/bookings/{bookingId}
  //
  // doc.ref.parent        -> bookings
  // collectionRef.parent  -> tenant document
  // ----------------------------------------------------------

  const tenantRef = collectionRef.parent;

  // ----------------------------------------------------------
  // REJECT TOP-LEVEL /bookings/{bookingId}
  // ----------------------------------------------------------

  if (!tenantRef) {
    logger.warn(
        "Skipping non-tenant booking document",
        {
          path: doc.ref.path,
          reason: "Booking is not inside a tenant",
        },
    );

    return "";
  }

  // ----------------------------------------------------------
  // TENANT DOCUMENT MUST BELONG TO "tenants"
  // ----------------------------------------------------------

  const tenantsCollection = tenantRef.parent;

  if (!tenantsCollection) {
    logger.warn(
        "Skipping booking without tenants parent",
        {
          path: doc.ref.path,
          tenantPath: tenantRef.path,
        },
    );

    return "";
  }

  if (tenantsCollection.id !== "tenants") {
    logger.warn(
        "Skipping booking outside tenants collection",
        {
          path: doc.ref.path,
          tenantPath: tenantRef.path,
          parentCollection: tenantsCollection.id,
        },
    );

    return "";
  }

  // ----------------------------------------------------------
  // TENANT ID FROM FIRESTORE PATH
  // ----------------------------------------------------------

  const pathTenantId = tenantRef.id.trim();

  if (!pathTenantId) {
    logger.warn(
        "Skipping booking because path tenant ID is empty",
        {
          path: doc.ref.path,
        },
    );

    return "";
  }

  // ----------------------------------------------------------
  // TENANT ID FROM BOOKING DOCUMENT
  // ----------------------------------------------------------

  const bookingTenantId =
    data.tenantId != null ?
      String(data.tenantId).trim() :
      "";

  if (!bookingTenantId) {
    logger.warn(
        "Skipping booking because tenantId field is missing",
        {
          path: doc.ref.path,
          tenantIdFromPath: pathTenantId,
        },
    );

    return "";
  }

  // ----------------------------------------------------------
  // SECURITY / DATA CONSISTENCY CHECK
  // ----------------------------------------------------------
  //
  // Example:
  //
  // Path:
  // tenants/tenant_001/bookings/ABC
  //
  // Booking:
  // tenantId = tenant_001
  //
  // These MUST match.
  // ----------------------------------------------------------

  if (bookingTenantId !== pathTenantId) {
    logger.error(
        "Booking tenant mismatch",
        {
          path: doc.ref.path,
          tenantIdFromPath: pathTenantId,
          tenantIdFromBooking: bookingTenantId,
        },
    );

    return "";
  }

  return pathTenantId;
}

/**
 * Processes one automatic booking lifecycle transition.
 *
 * Examples:
 *
 * confirmed + pickupDateTime <= now
 *     -> pickupPending
 *
 * active + returnDateTime <= now
 *     -> returnPending
 *
 * @param {Object} options Transition configuration.
 * @param {string} options.sourceStatus Current booking status.
 * @param {string} options.targetStatus Target booking status.
 * @param {string} options.timeField Firestore timestamp field.
 * @param {Date} options.now Current execution time.
 * @return {Promise<Object>} Transition execution summary.
 */
async function processTransition({
  sourceStatus,
  targetStatus,
  timeField,
  now,
}) {
  let totalRead = 0;
  let totalUpdated = 0;
  let totalSkipped = 0;
  let batchNumber = 0;

  const nowTimestamp =
    admin.firestore.Timestamp.fromDate(now);

  while (batchNumber < MAX_BATCHES_PER_RUN) {
    batchNumber++;

    // --------------------------------------------------------
    // QUERY ONLY DUE BOOKINGS
    // --------------------------------------------------------
    //
    // This DOES NOT load every booking.
    //
    // It only reads documents where:
    //
    // status == sourceStatus
    //
    // AND
    //
    // timeField <= now
    //
    // collectionGroup is used because bookings exist under
    // multiple tenant documents.
    //
    // Invalid top-level /bookings documents are rejected by
    // getTenantIdFromBooking().
    // --------------------------------------------------------

    const snapshot = await db
        .collectionGroup("bookings")
        .where(
            "status",
            "==",
            sourceStatus,
        )
        .where(
            timeField,
            "<=",
            nowTimestamp,
        )
        .orderBy(
            timeField,
            "asc",
        )
        .limit(BATCH_SIZE)
        .get();

    totalRead += snapshot.size;

    if (snapshot.empty) {
      break;
    }

    // --------------------------------------------------------
    // BULK WRITER
    // --------------------------------------------------------

    const writer = db.bulkWriter();

    let updatedThisBatch = 0;
    let skippedThisBatch = 0;

    // --------------------------------------------------------
    // WRITE ERROR HANDLING
    // --------------------------------------------------------

    writer.onWriteError((error) => {
      if (error.failedAttempts < 5) {
        return true;
      }

      logger.error(
          "BulkWriter write failed",
          {
            path: error.documentRef.path,
            error: error.message,
            failedAttempts: error.failedAttempts,
          },
      );

      return false;
    });

    // --------------------------------------------------------
    // PROCESS MATCHING BOOKINGS
    // --------------------------------------------------------

    for (const doc of snapshot.docs) {
      const data = doc.data();

      // ------------------------------------------------------
      // STATUS CHECK
      // ------------------------------------------------------

      if (data.status !== sourceStatus) {
        skippedThisBatch++;
        continue;
      }

      // ------------------------------------------------------
      // TIME FIELD CHECK
      // ------------------------------------------------------

      const scheduledTime = data[timeField];

      if (!scheduledTime) {
        logger.warn(
            "Booking has no lifecycle time field",
            {
              path: doc.ref.path,
              timeField,
            },
        );

        skippedThisBatch++;
        continue;
      }

      // ------------------------------------------------------
      // FIRESTORE TIMESTAMP CHECK
      // ------------------------------------------------------

      if (
        typeof scheduledTime.toMillis !== "function"
      ) {
        logger.warn(
            "Booking lifecycle time is not a timestamp",
            {
              path: doc.ref.path,
              timeField,
            },
        );

        skippedThisBatch++;
        continue;
      }

      // ------------------------------------------------------
      // DEFENSIVE DUE-TIME CHECK
      // ------------------------------------------------------

      if (
        scheduledTime.toMillis() >
        now.getTime()
      ) {
        skippedThisBatch++;
        continue;
      }

      // ------------------------------------------------------
      // TENANT VALIDATION
      // ------------------------------------------------------

      const tenantId = getTenantIdFromBooking(
          doc,
          data,
      );

      if (!tenantId) {
        skippedThisBatch++;
        continue;
      }

      // ------------------------------------------------------
      // BOOKING ID
      // ------------------------------------------------------

      const bookingId =
        data.bookingId != null ?
          String(data.bookingId).trim() :
          doc.id;

      // ------------------------------------------------------
      // LOG TRANSITION
      // ------------------------------------------------------

      logger.info(
          "Booking lifecycle transition scheduled",
          {
            path: doc.ref.path,
            bookingId,
            tenantId,
            sourceStatus,
            targetStatus,
            timeField,
            scheduledTime:
              scheduledTime.toDate().toISOString(),
          },
      );

      // ------------------------------------------------------
      // UPDATE BOOKING
      // ------------------------------------------------------
      //
      // lastUpdateTime protects against overwriting a booking
      // that changed after this function read it.
      // ------------------------------------------------------

      writer.update(
          doc.ref,
          {
            status: targetStatus,

            updatedAt:
              admin.firestore.FieldValue
                  .serverTimestamp(),

            lifecycleAutomation: {
              previousStatus: sourceStatus,
              lastTransition: targetStatus,

              transitionedAt:
                admin.firestore.FieldValue
                    .serverTimestamp(),

              source: "cloud_function",

              tenantId,
            },
          },
          {
            lastUpdateTime: doc.updateTime,
          },
      );

      updatedThisBatch++;
    }

    // --------------------------------------------------------
    // COMMIT WRITES
    // --------------------------------------------------------

    await writer.close();

    totalUpdated += updatedThisBatch;
    totalSkipped += skippedThisBatch;

    // --------------------------------------------------------
    // BATCH LOG
    // --------------------------------------------------------

    logger.info(
        "Booking lifecycle batch completed",
        {
          batchNumber,
          sourceStatus,
          targetStatus,
          timeField,
          read: snapshot.size,
          updated: updatedThisBatch,
          skipped: skippedThisBatch,
        },
    );

    // --------------------------------------------------------
    // STOP IF THERE ARE NO MORE DOCUMENTS
    // --------------------------------------------------------

    if (snapshot.size < BATCH_SIZE) {
      break;
    }

    // Updated documents no longer have sourceStatus.
    //
    // Therefore the next query automatically continues
    // draining any remaining due bookings.
  }

  return {
    totalRead,
    totalUpdated,
    totalSkipped,
    batches: batchNumber,
  };
}

/**
 * Scheduled automatic booking lifecycle worker.
 *
 * Runs every five minutes.
 *
 * Automatic transitions:
 *
 * confirmed -> pickupPending
 * active -> returnPending
 *
 * Manual transitions:
 *
 * pickupPending -> active
 * returnPending -> completed
 *
 * @return {Promise<void>}
 */
async function runBookingLifecycle() {
  const startedAt = Date.now();

  const now = new Date();

  logger.info(
      "Booking lifecycle sync started",
      {
        now: now.toISOString(),
        region: REGION,
        timeZone: TIME_ZONE,
      },
  );

  try {
    // --------------------------------------------------------
    // CONFIRMED -> PICKUP_PENDING
    // --------------------------------------------------------

    const pickupResult =
      await processTransition({
        sourceStatus: STATUS.CONFIRMED,
        targetStatus: STATUS.PICKUP_PENDING,
        timeField: "pickupDateTime",
        now,
      });

    // --------------------------------------------------------
    // ACTIVE -> RETURN_PENDING
    // --------------------------------------------------------

    const returnResult =
      await processTransition({
        sourceStatus: STATUS.ACTIVE,
        targetStatus: STATUS.RETURN_PENDING,
        timeField: "returnDateTime",
        now,
      });

    // --------------------------------------------------------
    // SUMMARY
    // --------------------------------------------------------

    const durationMs =
      Date.now() - startedAt;

    logger.info(
        "Booking lifecycle sync completed",
        {
          durationMs,
          pickup: pickupResult,
          return: returnResult,
        },
    );
  } catch (error) {
    logger.error(
        "Booking lifecycle sync failed",
        {
          message:
            error && error.message ?
              error.message :
              String(error),

          stack:
            error && error.stack ?
              error.stack :
              "",
        },
    );

    throw error;
  }
}

// ------------------------------------------------------------
// CLOUD SCHEDULER FUNCTION
// ------------------------------------------------------------
//
// Runs every 5 minutes.
//
// Firestore:
//
// tenants/{tenantId}/bookings/{bookingId}
//
// Automatic:
//
// confirmed
//    +
// pickupDateTime <= now
//    ↓
// pickupPending
//
// active
//    +
// returnDateTime <= now
//    ↓
// returnPending
//
// Manual:
//
// pickupPending -> active
// returnPending -> completed
//
// ------------------------------------------------------------

exports.syncBookingLifecycle = onSchedule(
    {
      schedule: "every 5 minutes",

      timeZone: TIME_ZONE,

      region: REGION,

      timeoutSeconds: 60,

      memory: "256MiB",

      maxInstances: 1,
    },
    runBookingLifecycle,
);
