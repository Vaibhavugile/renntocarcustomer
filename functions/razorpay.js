"use strict";

/* eslint-disable require-jsdoc */
/* eslint-disable valid-jsdoc */

const admin = require("firebase-admin");
const {
  SecretManagerServiceClient,
} = require("@google-cloud/secret-manager");
const Razorpay = require("razorpay");
const crypto = require("crypto");

const db = admin.firestore();
const secretManager = new SecretManagerServiceClient();

/**
 * ============================================================
 * RAZORPAY MULTI-TENANT SERVICE
 * ============================================================
 *
 * Firestore:
 *
 * tenants/{tenantId}
 *   razorpay:
 *     enabled: true
 *     mode: "live"
 *     keyId: "rzp_live_xxxxx"
 *     currency: "INR"
 *     configured: true
 *
 * Secret Manager:
 *
 * RAZORPAY_TENANT_001_KEY_SECRET
 * RAZORPAY_TENANT_002_KEY_SECRET
 * RAZORPAY_TENANT_003_KEY_SECRET
 *
 * IMPORTANT:
 * Razorpay Key Secret is NEVER returned to Flutter.
 * ============================================================
 */

// ------------------------------------------------------------
// Helpers
// ------------------------------------------------------------

function normalizeTenantId(tenantId) {
  const value = String(tenantId || "").trim();

  if (!value) {
    throw new Error("Tenant ID is required.");
  }

  // Only allow safe characters for Secret Manager secret names.
  if (!/^[a-zA-Z0-9_-]+$/.test(value)) {
    throw new Error("Invalid tenant ID.");
  }

  return value;
}

/**
 * tenant_001
 *      ↓
 * RAZORPAY_TENANT_001_KEY_SECRET
 */
function getTenantSecretName(tenantId) {
  const normalized = normalizeTenantId(tenantId);

  return `RAZORPAY_${normalized.toUpperCase()}_KEY_SECRET`;
}

/**
 * Reads the Razorpay secret from Google Secret Manager.
 */
async function getTenantRazorpaySecret(tenantId) {
  const secretName = getTenantSecretName(tenantId);

  const projectId =
    process.env.GCLOUD_PROJECT ||
    process.env.GCP_PROJECT;

  if (!projectId) {
    throw new Error(
        "Firebase project ID is not available.",
    );
  }

  const name =
    `projects/${projectId}/secrets/${secretName}/versions/latest`;

  try {
    const [version] =
      await secretManager.accessSecretVersion({
        name,
      });

    const secret =
      version &&
      version.payload &&
      version.payload.data ?
        version.payload.data.toString("utf8").trim() :
        "";

    if (!secret) {
      throw new Error(
          `Razorpay secret is empty for tenant ${tenantId}.`,
      );
    }

    return secret;
  } catch (error) {
    console.error(
        "Unable to load Razorpay secret.",
        {
          tenantId,
          secretName,
          error: error.message,
        },
    );

    throw new Error(
        `Razorpay credentials are not configured for tenant ${tenantId}.`,
    );
  }
}

/**
 * Loads the tenant's public Razorpay configuration
 * from Firestore.
 */
async function getTenantRazorpayConfig(tenantId) {
  const normalizedTenantId =
    normalizeTenantId(tenantId);

  const tenantRef = db
      .collection("tenants")
      .doc(normalizedTenantId);

  const snapshot = await tenantRef.get();

  if (!snapshot.exists) {
    throw new Error(
        "Tenant configuration was not found.",
    );
  }

  const tenant = snapshot.data() || {};

  const razorpay =
    tenant.razorpay || {};

  if (razorpay.enabled !== true) {
    throw new Error(
        "Razorpay is disabled for this tenant.",
    );
  }

  if (razorpay.configured !== true) {
    throw new Error(
        "Razorpay is not configured for this tenant.",
    );
  }

  const keyId =
    String(razorpay.keyId || "").trim();

  if (!keyId) {
    throw new Error(
        "Razorpay Key ID is missing.",
    );
  }

  const mode =
    String(razorpay.mode || "test")
        .trim()
        .toLowerCase();

  if (mode !== "test" && mode !== "live") {
    throw new Error(
        "Invalid Razorpay mode.",
    );
  }

  const currency =
    String(
        razorpay.currency ||
      tenant.currency ||
      "INR",
    )
        .trim()
        .toUpperCase();

  return {
    tenantId: normalizedTenantId,
    enabled: true,
    configured: true,
    mode,
    keyId,
    currency,
  };
}

/**
 * Creates a Razorpay client for a tenant.
 *
 * Secret never leaves the backend.
 */
async function getTenantRazorpayClient(tenantId) {
  const config =
    await getTenantRazorpayConfig(tenantId);

  const secret =
    await getTenantRazorpaySecret(tenantId);

  const razorpay =
    new Razorpay({
      key_id: config.keyId,
      key_secret: secret,
    });

  return {
    razorpay,
    config,
  };
}

// ------------------------------------------------------------
// Booking helpers
// ------------------------------------------------------------

async function getTenantBooking({
  tenantId,
  bookingId,
}) {
  const normalizedTenantId =
    normalizeTenantId(tenantId);

  const normalizedBookingId =
    String(bookingId || "").trim();

  if (!normalizedBookingId) {
    throw new Error(
        "Booking ID is required.",
    );
  }

  const bookingRef = db
      .collection("tenants")
      .doc(normalizedTenantId)
      .collection("bookings")
      .doc(normalizedBookingId);

  const snapshot =
    await bookingRef.get();

  if (!snapshot.exists) {
    throw new Error(
        "Booking not found.",
    );
  }

  const booking =
    snapshot.data() || {};

  if (
    String(booking.tenantId || "").trim() !==
    normalizedTenantId
  ) {
    throw new Error(
        "Booking does not belong to this tenant.",
    );
  }

  return {
    ref: bookingRef,
    id: snapshot.id,
    data: booking,
  };
}

/**
 * Calculates the amount that may actually be paid.
 *
 * Total:
 * booking.totalAmount
 *
 * Paid:
 * booking.paidAmount
 *
 * Refund:
 * booking.refundAmount
 *
 * Outstanding:
 * total - paid + refund
 *
 * We DO NOT trust an amount sent from Flutter.
 */
function getOutstandingAmount(booking) {
  const totalAmount =
    Number(booking.totalAmount || 0);

  const paidAmount =
    Number(booking.paidAmount || 0);

  const refundAmount =
    Number(booking.refundAmount || 0);

  const outstanding =
    totalAmount -
    paidAmount +
    refundAmount;

  return Math.max(
      0,
      Number(outstanding.toFixed(2)),
  );
}

/**
 * Validates a customer requested payment amount
 * against the latest Firestore outstanding balance.
 *
 * IMPORTANT:
 * This validation happens on the backend.
 */
function validateRequestedPaymentAmount(
    requestedAmount,
    outstandingAmount,
) {
  const amount =
    Number(requestedAmount);

  if (
    !Number.isFinite(amount) ||
    amount <= 0
  ) {
    throw new Error(
        "Payment amount must be greater than zero.",
    );
  }

  if (
    !Number.isFinite(outstandingAmount) ||
    outstandingAmount <= 0
  ) {
    throw new Error(
        "There is no outstanding amount for this booking.",
    );
  }

  // Small tolerance for floating point calculations.
  const epsilon = 0.01;

  if (
    amount >
    outstandingAmount + epsilon
  ) {
    throw new Error(
        `Payment amount cannot exceed the 
        outstanding balance of ${outstandingAmount.toFixed(2)}.`,
    );
  }

  return Number(amount.toFixed(2));
}

/**
 * Razorpay expects amount in paise.
 *
 * ₹1000.50
 * ↓
 * 100050
 */
function rupeesToPaise(amount) {
  if (
    !Number.isFinite(amount) ||
    amount <= 0
  ) {
    throw new Error(
        "Invalid payment amount.",
    );
  }

  return Math.round(
      amount * 100,
  );
}

// ------------------------------------------------------------
// CREATE ORDER FOR EXISTING BOOKING
// ------------------------------------------------------------

/**
 * Creates a Razorpay order for a tenant booking.
 *
 * Supports:
 *
 * 1. Pay Remaining
 *
 * requestedAmount omitted
 *        ↓
 * current outstanding is used
 *
 * 2. Pay Other Amount
 *
 * requestedAmount provided
 *        ↓
 * backend validates it
 *        ↓
 * custom amount is used
 *
 * Input:
 *
 * {
 *   tenantId: "tenant_001",
 *   bookingId: "BOOKING_ID",
 *   userId: "CUSTOMER_UID",
 *   requestedAmount: 2000
 * }
 *
 * requestedAmount is optional.
 *
 * If omitted:
 *
 *     full outstanding amount is used.
 *
 * If provided:
 *
 *     requestedAmount must be:
 *
 *     > 0
 *     <= current outstanding
 */
async function createRazorpayOrder({
  tenantId,
  bookingId,
  userId = null,
  requestedAmount = null,
}) {
  const normalizedTenantId =
    normalizeTenantId(tenantId);

  const config =
    await getTenantRazorpayConfig(
        normalizedTenantId,
    );

  const booking =
    await getTenantBooking({
      tenantId: normalizedTenantId,
      bookingId,
    });

  const bookingData =
    booking.data;

  // ----------------------------------------------------------
  // Customer ownership check
  // ----------------------------------------------------------

  if (
    userId &&
    String(bookingData.customerId || "").trim() !==
      String(userId).trim()
  ) {
    throw new Error(
        "You are not authorized to pay for this booking.",
    );
  }

  // ----------------------------------------------------------
  // Booking status protection
  // ----------------------------------------------------------

  const status =
    String(
        bookingData.status || "",
    )
        .trim()
        .toLowerCase();

  const blockedStatuses = [
    "cancelled",
    "rejected",
    "completed",
    "noshow",
    "no_show",
  ];

  if (
    blockedStatuses.includes(status)
  ) {
    throw new Error(
        "This booking is no longer available for payment.",
    );
  }

  // ----------------------------------------------------------
  // ALWAYS calculate latest outstanding from Firestore
  // ----------------------------------------------------------

  const outstandingAmount =
    getOutstandingAmount(
        bookingData,
    );

  if (
    outstandingAmount <= 0
  ) {
    throw new Error(
        "There is no outstanding amount for this booking.",
    );
  }

  // ----------------------------------------------------------
  // Determine payment amount
  // ----------------------------------------------------------

  let paymentAmount;

  const hasRequestedAmount =
    requestedAmount !== null &&
    requestedAmount !== undefined &&
    String(requestedAmount).trim() !== "";

  if (hasRequestedAmount) {
    paymentAmount =
      validateRequestedPaymentAmount(
          requestedAmount,
          outstandingAmount,
      );
  } else {
    paymentAmount =
      outstandingAmount;
  }

  // ----------------------------------------------------------
  // Convert to paise
  // ----------------------------------------------------------

  const amountPaise =
    rupeesToPaise(
        paymentAmount,
    );

  // ----------------------------------------------------------
  // Create Razorpay client
  // ----------------------------------------------------------

  const {
    razorpay,
  } = await getTenantRazorpayClient(
      normalizedTenantId,
  );

  // ----------------------------------------------------------
  // Razorpay order receipt
  // ----------------------------------------------------------

  const receipt =
    `rentocar_${normalizedTenantId}_${bookingId}_${Date.now()}`
        .replace(
            /[^a-zA-Z0-9_-]/g,
            "_",
        )
        .substring(0, 40);

  // ----------------------------------------------------------
  // Create Razorpay order
  // ----------------------------------------------------------

  const order =
    await razorpay.orders.create({
      amount: amountPaise,
      currency: config.currency,
      receipt,
      notes: {
        tenantId: normalizedTenantId,
        bookingId: String(bookingId),
        customerId:
          String(
              bookingData.customerId || "",
          ),
        paymentType:
          hasRequestedAmount ?
            "partial" :
            "remaining",
        requestedAmount:
          String(paymentAmount),
        outstandingAtOrder:
          String(outstandingAmount),
      },
    });

  if (
    !order ||
    !order.id
  ) {
    throw new Error(
        "Razorpay did not return an order ID.",
    );
  }

  // ----------------------------------------------------------
  // Save payment attempt
  // ----------------------------------------------------------

  const paymentAttemptRef =
    booking.ref
        .collection("paymentAttempts")
        .doc();

  await paymentAttemptRef.set({
    tenantId:
      normalizedTenantId,

    bookingId:
      String(bookingId),

    customerId:
      bookingData.customerId ||
      null,

    amount:
      paymentAmount,

    amountPaise:
      amountPaise,

    outstandingAtOrder:
      outstandingAmount,

    currency:
      config.currency,

    gateway:
      "razorpay",

    gatewayMode:
      config.mode,

    paymentType:
      hasRequestedAmount ?
        "partial" :
        "remaining",

    razorpayOrderId:
      order.id,

    status:
      "created",

    createdAt:
      admin.firestore.FieldValue
          .serverTimestamp(),

    updatedAt:
      admin.firestore.FieldValue
          .serverTimestamp(),
  });

  // ----------------------------------------------------------
  // Return only public values to Flutter
  // ----------------------------------------------------------

  return {
    success: true,

    tenantId:
      normalizedTenantId,

    bookingId:
      String(bookingId),

    orderId:
      order.id,

    // PUBLIC Razorpay Key ID only.
    // Secret is NEVER returned.
    keyId:
      config.keyId,

    // Razorpay expects paise.
    amount:
      amountPaise,

    // Convenient for Flutter.
    amountRupees:
      paymentAmount,

    // Latest balance before creating order.
    outstandingAmount:
      outstandingAmount,

    currency:
      config.currency,

    paymentType:
      hasRequestedAmount ?
        "partial" :
        "remaining",

    paymentAttemptId:
      paymentAttemptRef.id,
  };
}

// ------------------------------------------------------------
// CREATE NEW CUSTOMER CHECKOUT ORDER
// ------------------------------------------------------------

/**
 * Creates a Razorpay order for a NEW customer booking.
 *
 * IMPORTANT:
 *
 * - The real booking does NOT exist yet.
 * - This function creates only a temporary checkout attempt.
 * - The final bookings/{bookingId} document is created only
 *   after successful payment verification.
 *
 * Input:
 *
 * {
 *   tenantId: "tenant_001",
 *   booking: {
 *     tenantId: "tenant_001",
 *     customerId: "CUSTOMER_UID",
 *     totalAmount: 5000,
 *     ...
 *   },
 *   requestedAmount: 5000
 * }
 *
 * The server determines the default amount from booking.totalAmount.
 *
 * If requestedAmount is supplied, it cannot exceed totalAmount.
 *
 * IMPORTANT:
 * For maximum production protection, the totalAmount should
 * eventually be recalculated on the backend from authoritative
 * vehicle/pricing/date/package data.
 */
async function createRazorpayCheckoutOrder({
  tenantId,
  booking,
  requestedAmount = null,
}) {
  const normalizedTenantId =
    normalizeTenantId(tenantId);

  if (
    !booking ||
    typeof booking !== "object"
  ) {
    throw new Error(
        "Booking data is required for checkout.",
    );
  }

  const bookingTenantId =
    String(
        booking.tenantId || "",
    ).trim();

  if (
    bookingTenantId &&
    bookingTenantId !== normalizedTenantId
  ) {
    throw new Error(
        "Booking does not belong to this tenant.",
    );
  }

  const customerId =
    String(
        booking.customerId ||
      booking.userId ||
      "",
    ).trim();

  if (!customerId) {
    throw new Error(
        "Customer ID is required for checkout.",
    );
  }

  const config =
    await getTenantRazorpayConfig(
        normalizedTenantId,
    );

  // ----------------------------------------------------------
  // Determine checkout amount
  // ----------------------------------------------------------

  const totalAmount =
    Number(
        booking.totalAmount || 0,
    );

  if (
    !Number.isFinite(totalAmount) ||
    totalAmount <= 0
  ) {
    throw new Error(
        "Invalid booking total amount.",
    );
  }

  let paymentAmount;

  const hasRequestedAmount =
    requestedAmount !== null &&
    requestedAmount !== undefined &&
    String(requestedAmount).trim() !== "";

  if (hasRequestedAmount) {
    paymentAmount =
      validateRequestedPaymentAmount(
          requestedAmount,
          totalAmount,
      );
  } else {
    paymentAmount =
      Number(
          totalAmount.toFixed(2),
      );
  }

  const amountPaise =
    rupeesToPaise(
        paymentAmount,
    );

  // ----------------------------------------------------------
  // Create Razorpay client
  // ----------------------------------------------------------

  const {
    razorpay,
  } = await getTenantRazorpayClient(
      normalizedTenantId,
  );

  // ----------------------------------------------------------
  // Create temporary checkout attempt
  // ----------------------------------------------------------
  //
  // IMPORTANT:
  //
  // This is NOT a booking.
  //
  // It is only used to correlate:
  //
  // checkout attempt
  //      ↓
  // Razorpay order
  //      ↓
  // Razorpay payment
  //
  // If customer backs out, there is no bookings document.
  // ----------------------------------------------------------

  const checkoutAttemptRef =
    db
        .collection("tenants")
        .doc(normalizedTenantId)
        .collection("checkoutAttempts")
        .doc();

  const checkoutAttemptId =
    checkoutAttemptRef.id;

  const receipt =
    `rentocar_${normalizedTenantId}_checkout_${checkoutAttemptId}`
        .replace(
            /[^a-zA-Z0-9_-]/g,
            "_",
        )
        .substring(0, 40);

  // ----------------------------------------------------------
  // Create Razorpay order
  // ----------------------------------------------------------

  const order =
    await razorpay.orders.create({
      amount: amountPaise,
      currency: config.currency,
      receipt,

      notes: {
        tenantId:
          normalizedTenantId,

        checkoutAttemptId:
          checkoutAttemptId,

        customerId:
          customerId,

        paymentType:
          hasRequestedAmount ?
            "partial" :
            "full",

        requestedAmount:
          String(paymentAmount),

        bookingTotalAmount:
          String(totalAmount),

        flow:
          "new_customer_booking",
      },
    });

  if (
    !order ||
    !order.id
  ) {
    throw new Error(
        "Razorpay did not return an order ID.",
    );
  }

  // ----------------------------------------------------------
  // Save ONLY temporary checkout attempt
  // ----------------------------------------------------------

  await checkoutAttemptRef.set({
    tenantId:
      normalizedTenantId,

    checkoutAttemptId:
      checkoutAttemptId,

    customerId:
      customerId,

    amount:
      paymentAmount,

    amountPaise:
      amountPaise,

    bookingTotalAmount:
      totalAmount,

    currency:
      config.currency,

    gateway:
      "razorpay",

    gatewayMode:
      config.mode,

    paymentType:
      hasRequestedAmount ?
        "partial" :
        "full",

    razorpayOrderId:
      order.id,

    status:
      "created",

    /**
     * Store the temporary booking payload
     * only for checkout correlation.
     *
     * This is NOT the bookings collection.
     */
    bookingData:
      booking,

    createdAt:
      admin.firestore.FieldValue
          .serverTimestamp(),

    updatedAt:
      admin.firestore.FieldValue
          .serverTimestamp(),
  });

  // ----------------------------------------------------------
  // Return public values to Flutter
  // ----------------------------------------------------------

  return {
    success: true,

    tenantId:
      normalizedTenantId,

    checkoutAttemptId:
      checkoutAttemptId,

    orderId:
      order.id,

    // PUBLIC Razorpay Key ID.
    keyId:
      config.keyId,

    // Razorpay amount in paise.
    amount:
      amountPaise,

    // Convenient rupee amount.
    amountRupees:
      paymentAmount,

    currency:
      config.currency,

    paymentType:
      hasRequestedAmount ?
        "partial" :
        "full",

    // Explicitly tell Flutter that no booking
    // has been created yet.
    bookingCreated:
      false,
  };
}

// ------------------------------------------------------------
// VERIFY PAYMENT SIGNATURE
// ------------------------------------------------------------

/**
 * Verifies:
 *
 * razorpay_order_id
 * razorpay_payment_id
 * razorpay_signature
 *
 * IMPORTANT:
 * This does not trust Flutter.
 */
async function verifyRazorpaySignature({
  tenantId,
  orderId,
  paymentId,
  signature,
}) {
  const normalizedTenantId =
    normalizeTenantId(tenantId);

  if (!orderId) {
    throw new Error(
        "Razorpay order ID is required.",
    );
  }

  if (!paymentId) {
    throw new Error(
        "Razorpay payment ID is required.",
    );
  }

  if (!signature) {
    throw new Error(
        "Razorpay signature is required.",
    );
  }

  const secret =
    await getTenantRazorpaySecret(
        normalizedTenantId,
    );

  const payload =
    `${orderId}|${paymentId}`;

  const expectedSignature =
    crypto
        .createHmac(
            "sha256",
            secret,
        )
        .update(payload)
        .digest("hex");

  const received =
    Buffer.from(
        String(signature),
        "utf8",
    );

  const expected =
    Buffer.from(
        expectedSignature,
        "utf8",
    );

  if (
    received.length !==
    expected.length
  ) {
    return false;
  }

  return crypto.timingSafeEqual(
      received,
      expected,
  );
}

// ------------------------------------------------------------
// EXPORTS
// ------------------------------------------------------------

module.exports = {
  getTenantRazorpayConfig,
  getTenantRazorpaySecret,
  getTenantRazorpayClient,

  // Existing payment flow for bookings
  // that already exist.
  createRazorpayOrder,

  // New customer payment-first flow.
  createRazorpayCheckoutOrder,

  // Razorpay signature verification.
  verifyRazorpaySignature,

  // Booking helpers.
  getTenantBooking,
  getOutstandingAmount,

  // Exported for server-side validation.
  validateRequestedPaymentAmount,
};
