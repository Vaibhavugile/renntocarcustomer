'use strict';

const admin = require('firebase-admin');
const { SecretManagerServiceClient } = require('@google-cloud/secret-manager');
const Razorpay = require('razorpay');
const crypto = require('crypto');

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
  const value = String(tenantId || '').trim();

  if (!value) {
    throw new Error('Tenant ID is required.');
  }

  // Only allow safe characters for Secret Manager secret names.
  if (!/^[a-zA-Z0-9_-]+$/.test(value)) {
    throw new Error('Invalid tenant ID.');
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
      'Firebase project ID is not available.'
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
      version.payload?.data?.toString('utf8')?.trim();

    if (!secret) {
      throw new Error(
        `Razorpay secret is empty for tenant ${tenantId}.`
      );
    }

    return secret;
  } catch (error) {
    console.error(
      'Unable to load Razorpay secret.',
      {
        tenantId,
        secretName,
        error: error.message,
      }
    );

    throw new Error(
      `Razorpay credentials are not configured for tenant ${tenantId}.`
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
    .collection('tenants')
    .doc(normalizedTenantId);

  const snapshot = await tenantRef.get();

  if (!snapshot.exists) {
    throw new Error(
      'Tenant configuration was not found.'
    );
  }

  const tenant = snapshot.data() || {};

  const razorpay =
    tenant.razorpay || {};

  if (razorpay.enabled !== true) {
    throw new Error(
      'Razorpay is disabled for this tenant.'
    );
  }

  if (razorpay.configured !== true) {
    throw new Error(
      'Razorpay is not configured for this tenant.'
    );
  }

  const keyId =
    String(razorpay.keyId || '').trim();

  if (!keyId) {
    throw new Error(
      'Razorpay Key ID is missing.'
    );
  }

  const mode =
    String(razorpay.mode || 'test')
      .trim()
      .toLowerCase();

  if (mode !== 'test' && mode !== 'live') {
    throw new Error(
      'Invalid Razorpay mode.'
    );
  }

  const currency =
    String(
      razorpay.currency ||
        tenant.currency ||
        'INR'
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
    String(bookingId || '').trim();

  if (!normalizedBookingId) {
    throw new Error(
      'Booking ID is required.'
    );
  }

  const bookingRef = db
    .collection('tenants')
    .doc(normalizedTenantId)
    .collection('bookings')
    .doc(normalizedBookingId);

  const snapshot =
    await bookingRef.get();

  if (!snapshot.exists) {
    throw new Error(
      'Booking not found.'
    );
  }

  const booking =
    snapshot.data() || {};

  if (
    String(booking.tenantId || '').trim() !==
    normalizedTenantId
  ) {
    throw new Error(
      'Booking does not belong to this tenant.'
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
    Number(outstanding.toFixed(2))
  );
}

/**
 * Razorpay expects amount in paise.
 *
 * ₹1000.50
 * ↓
 * 100050
 */
function rupeesToPaise(amount) {
  if (!Number.isFinite(amount) || amount <= 0) {
    throw new Error(
      'Invalid payment amount.'
    );
  }

  return Math.round(
    amount * 100
  );
}

// ------------------------------------------------------------
// CREATE ORDER
// ------------------------------------------------------------

/**
 * Creates a Razorpay order for a tenant booking.
 *
 * Input:
 *
 * {
 *   tenantId: "tenant_001",
 *   bookingId: "BOOKING_ID"
 * }
 *
 * Returns:
 *
 * {
 *   success: true,
 *   orderId: "...",
 *   keyId: "...",
 *   amount: 500000,
 *   amountRupees: 5000,
 *   currency: "INR"
 * }
 */
async function createRazorpayOrder({
  tenantId,
  bookingId,
  userId = null,
}) {
  const config =
    await getTenantRazorpayConfig(
      tenantId
    );

  const booking =
    await getTenantBooking({
      tenantId,
      bookingId,
    });

  const bookingData =
    booking.data;

  // ----------------------------------------------------------
  // Customer ownership check
  // ----------------------------------------------------------

  if (
    userId &&
    String(bookingData.customerId || '').trim() !==
      String(userId).trim()
  ) {
    throw new Error(
      'You are not authorized to pay for this booking.'
    );
  }

  // ----------------------------------------------------------
  // Booking status protection
  // ----------------------------------------------------------

  const status =
    String(
      bookingData.status || ''
    ).trim().toLowerCase();

  const blockedStatuses = [
    'cancelled',
    'rejected',
    'completed',
    'noshow',
    'no_show',
  ];

  if (
    blockedStatuses.includes(status)
  ) {
    throw new Error(
      'This booking is no longer available for payment.'
    );
  }

  // ----------------------------------------------------------
  // Calculate amount from Firestore
  // ----------------------------------------------------------

  const outstandingAmount =
    getOutstandingAmount(
      bookingData
    );

  if (outstandingAmount <= 0) {
    throw new Error(
      'There is no outstanding amount for this booking.'
    );
  }

  const amountPaise =
    rupeesToPaise(
      outstandingAmount
    );

  // ----------------------------------------------------------
  // Create Razorpay client
  // ----------------------------------------------------------

  const {
    razorpay,
  } = await getTenantRazorpayClient(
    tenantId
  );

  // ----------------------------------------------------------
  // Razorpay order
  // ----------------------------------------------------------

  const receipt =
    `rentocar_${tenantId}_${bookingId}_${Date.now()}`
      .replace(/[^a-zA-Z0-9_-]/g, '_')
      .substring(0, 40);

  const order =
    await razorpay.orders.create({
      amount: amountPaise,
      currency: config.currency,
      receipt,
      notes: {
        tenantId,
        bookingId,
        customerId:
          String(
            bookingData.customerId || ''
          ),
      },
    });

  if (!order || !order.id) {
    throw new Error(
      'Razorpay did not return an order ID.'
    );
  }

  // ----------------------------------------------------------
  // Save payment attempt
  // ----------------------------------------------------------

  const paymentAttemptRef =
    booking.ref
      .collection('paymentAttempts')
      .doc();

  await paymentAttemptRef.set({
    tenantId,
    bookingId,
    customerId:
      bookingData.customerId || null,

    amount:
      outstandingAmount,

    amountPaise,

    currency:
      config.currency,

    gateway:
      'razorpay',

    gatewayMode:
      config.mode,

    razorpayOrderId:
      order.id,

    status:
      'created',

    createdAt:
      admin.firestore.FieldValue.serverTimestamp(),

    updatedAt:
      admin.firestore.FieldValue.serverTimestamp(),
  });

  return {
    success: true,

    tenantId,

    bookingId,

    orderId:
      order.id,

    keyId:
      config.keyId,

    amount:
      amountPaise,

    amountRupees:
      outstandingAmount,

    currency:
      config.currency,

    paymentAttemptId:
      paymentAttemptRef.id,
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
  if (!tenantId) {
    throw new Error(
      'Tenant ID is required.'
    );
  }

  if (!orderId) {
    throw new Error(
      'Razorpay order ID is required.'
    );
  }

  if (!paymentId) {
    throw new Error(
      'Razorpay payment ID is required.'
    );
  }

  if (!signature) {
    throw new Error(
      'Razorpay signature is required.'
    );
  }

  const secret =
    await getTenantRazorpaySecret(
      tenantId
    );

  const payload =
    `${orderId}|${paymentId}`;

  const expectedSignature =
    crypto
      .createHmac(
        'sha256',
        secret
      )
      .update(payload)
      .digest('hex');

  const received =
    Buffer.from(
      String(signature),
      'utf8'
    );

  const expected =
    Buffer.from(
      expectedSignature,
      'utf8'
    );

  if (
    received.length !==
    expected.length
  ) {
    return false;
  }

  return crypto.timingSafeEqual(
    received,
    expected
  );
}

// ------------------------------------------------------------
// EXPORTS
// ------------------------------------------------------------

module.exports = {
  getTenantRazorpayConfig,
  getTenantRazorpaySecret,
  getTenantRazorpayClient,
  createRazorpayOrder,
  verifyRazorpaySignature,
  getTenantBooking,
  getOutstandingAmount,
};
