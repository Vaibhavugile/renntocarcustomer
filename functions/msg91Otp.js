"use strict";

const crypto = require("crypto");

const {
  onCall,
  HttpsError,
} = require("firebase-functions/https");

const {
  logger,
} = require("firebase-functions");

const {
  getFirestore,
  Timestamp,
} = require("firebase-admin/firestore");

const {
  getAuth,
} = require("firebase-admin/auth");

const db = getFirestore();
const auth = getAuth();

const OTP_EXPIRY_SECONDS_DEFAULT = 300;
const RESEND_COOLDOWN_SECONDS = 60;
const OTP_MAX_ATTEMPTS = 5;

/**
 * Normalize an Indian phone number.
 *
 * @param {string} phoneNumber Phone number.
 * @return {Object} Normalized phone number values.
 */
function normalizeIndianPhone(phoneNumber) {
  if (typeof phoneNumber !== "string") {
    throw new HttpsError(
        "invalid-argument",
        "Phone number is required.",
    );
  }

  let digits =
    phoneNumber.replace(/\D/g, "");

  if (
    digits.startsWith("91") &&
    digits.length === 12
  ) {
    digits =
      digits.substring(2);
  }

  if (digits.length !== 10) {
    throw new HttpsError(
        "invalid-argument",
        "Please enter a valid 10-digit Indian mobile number.",
    );
  }

  if (!/^[6-9]\d{9}$/.test(digits)) {
    throw new HttpsError(
        "invalid-argument",
        "Please enter a valid Indian mobile number.",
    );
  }

  return {
    local: digits,
    international: `91${digits}`,
    e164: `+91${digits}`,
  };
}

/**
 * Generate a cryptographically secure 6-digit OTP.
 *
 * @return {string} Six-digit OTP.
 */
function generateOtp() {
  const min = 100000;
  const max = 999999;

  return crypto
      .randomInt(min, max + 1)
      .toString();
}

/**
 * Hash an OTP before storing it.
 *
 * @param {string} otp OTP value.
 * @return {string} SHA-256 OTP hash.
 */
function hashOtp(otp) {
  return crypto
      .createHash("sha256")
      .update(otp)
      .digest("hex");
}

/**
 * Compare two hashes safely.
 *
 * @param {string} firstHash First hash.
 * @param {string} secondHash Second hash.
 * @return {boolean} Whether hashes match.
 */
function hashesMatch(
    firstHash,
    secondHash,
) {
  if (
    typeof firstHash !== "string" ||
    typeof secondHash !== "string"
  ) {
    return false;
  }

  const first =
    Buffer.from(firstHash, "hex");

  const second =
    Buffer.from(secondHash, "hex");

  if (first.length !== second.length) {
    return false;
  }

  return crypto.timingSafeEqual(
      first,
      second,
  );
}

/**
 * Build the MSG91 WhatsApp template request.
 *
 * @param {Object} options Request configuration.
 * @param {Object} options.msg91 MSG91 tenant configuration.
 * @param {string} options.phoneNumber WhatsApp number.
 * @param {string} options.otp OTP value.
 * @return {Object} MSG91 request payload.
 */
function buildMsg91Request({
  msg91,
  phoneNumber,
  otp,
}) {
  return {
    integrated_number:
      msg91.integratedNumber,

    content_type:
      "template",

    payload: {
      messaging_product:
        "whatsapp",

      type:
        "template",

      template: {
        name:
          msg91.templateName,

        language: {
          code:
            msg91.languageCode || "en",

          policy:
            "deterministic",
        },

        namespace:
          msg91.namespace,

        to_and_components: [
          {
            to: [
              phoneNumber,
            ],

            components: {
              body_1: {
                type:
                  "text",

                value:
                  otp,
              },

              button_1: {
                subtype:
                  "url",

                type:
                  "text",

                value:
                  otp,
              },
            },
          },
        ],
      },
    },
  };
}

/**
 * Send WhatsApp OTP through MSG91.
 *
 * @param {Object} options Request configuration.
 * @param {Object} options.msg91 MSG91 tenant configuration.
 * @param {string} options.phoneNumber WhatsApp number.
 * @param {string} options.otp OTP value.
 * @return {Promise<Object>} MSG91 response.
 */
async function sendWhatsAppOtp({
  msg91,
  phoneNumber,
  otp,
}) {
  const payload =
    buildMsg91Request({
      msg91,
      phoneNumber,
      otp,
    });

  const response =
    await fetch(
        "https://api.msg91.com/api/v5/whatsapp/" +
      "whatsapp-outbound-message/bulk/",
        {
          method: "POST",

          headers: {
            "Content-Type":
            "application/json",

            "authkey":
            msg91.authKey,
          },

          body:
          JSON.stringify(payload),
        },
    );

  const responseText =
    await response.text();

  let responseData;

  try {
    responseData =
      JSON.parse(responseText);
  } catch (error) {
    responseData = {
      raw:
        responseText,
    };
  }

  if (!response.ok) {
    logger.error(
        "MSG91 WhatsApp request failed",
        {
          status:
          response.status,

          response:
          responseData,
        },
    );

    throw new HttpsError(
        "failed-precondition",
        "Unable to send WhatsApp OTP right now. " +
      "Please try again.",
    );
  }

  logger.info(
      "MSG91 WhatsApp OTP request accepted",
      {
        status:
        response.status,
      },
  );

  return responseData;
}

/**
 * Send a new MSG91 WhatsApp OTP.
 */
exports.sendMsg91Otp = onCall(
    {
      region:
      "asia-south1",
    },

    async (request) => {
      const data =
      request.data || {};

      const tenantId =
      typeof data.tenantId === "string" ?
        data.tenantId.trim() :
        "";

      if (!tenantId) {
        throw new HttpsError(
            "invalid-argument",
            "tenantId is required.",
        );
      }

      const phone =
      normalizeIndianPhone(
          data.phoneNumber,
      );

      const tenantRef =
      db
          .collection("tenants")
          .doc(tenantId);

      const tenantSnap =
      await tenantRef.get();

      if (!tenantSnap.exists) {
        throw new HttpsError(
            "not-found",
            "Tenant not found.",
        );
      }

      const tenantData =
      tenantSnap.data() || {};

      const msg91 =
      tenantData.msg91 || {};

      if (msg91.enabled !== true) {
        throw new HttpsError(
            "failed-precondition",
            "WhatsApp OTP is not enabled for this tenant.",
        );
      }

      if (
        msg91.channel !==
      "whatsapp"
      ) {
        throw new HttpsError(
            "failed-precondition",
            "WhatsApp OTP is not configured for this tenant.",
        );
      }

      const requiredFields = [
        "authKey",
        "integratedNumber",
        "templateName",
        "namespace",
      ];

      for (
        const field of requiredFields
      ) {
        if (
          typeof msg91[field] !== "string" ||
        !msg91[field].trim()
        ) {
          logger.error(
              "Missing MSG91 configuration field",
              {
                tenantId,
                field,
              },
          );

          throw new HttpsError(
              "failed-precondition",
              "MSG91 WhatsApp configuration is incomplete.",
          );
        }
      }

      const otpRef =
      tenantRef
          .collection(
              "otpVerifications",
          )
          .doc(
              phone.local,
          );

      const existingOtpSnap =
      await otpRef.get();

      const now =
      Date.now();

      if (
        existingOtpSnap.exists
      ) {
        const existingData =
        existingOtpSnap.data() || {};

        let lastSentAt = 0;

        if (
          existingData.lastSentAt &&
        typeof existingData.lastSentAt
            .toMillis === "function"
        ) {
          lastSentAt =
          existingData.lastSentAt
              .toMillis();
        }

        const secondsSinceLastSend =
        (now - lastSentAt) /
        1000;

        if (
          secondsSinceLastSend <
        RESEND_COOLDOWN_SECONDS
        ) {
          const remainingSeconds =
          Math.ceil(
              RESEND_COOLDOWN_SECONDS -
            secondsSinceLastSend,
          );

          throw new HttpsError(
              "resource-exhausted",
              "Please wait " +
          `${remainingSeconds} seconds ` +
          "before requesting another OTP.",
          );
        }
      }

      const otp =
      generateOtp();

      const otpHash =
      hashOtp(otp);

      const expirySeconds =
      Number(
          msg91.otpExpirySeconds,
      ) ||
      OTP_EXPIRY_SECONDS_DEFAULT;

      const expiresAt =
      Timestamp.fromMillis(
          now +
        expirySeconds * 1000,
      );

      await otpRef.set(
          {
            phoneNumber:
          phone.e164,

            otpHash:
          otpHash,

            expiresAt:
          expiresAt,

            attempts:
          0,

            createdAt:
          Timestamp.now(),

            lastSentAt:
          Timestamp.now(),
          },
          {
            merge:
          false,
          },
      );

      try {
        await sendWhatsAppOtp({
          msg91:
          msg91,

          phoneNumber:
          phone.international,

          otp:
          otp,
        });

        logger.info(
            "WhatsApp OTP sent",
            {
              tenantId,

              phoneNumber:
            phone.e164,

              expiresInSeconds:
            expirySeconds,
            },
        );

        return {
          success:
          true,

          phoneNumber:
          phone.e164,

          expiresInSeconds:
          expirySeconds,

          resendAfterSeconds:
          RESEND_COOLDOWN_SECONDS,

          msg91Accepted:
          true,
        };
      } catch (error) {
        try {
          await otpRef.delete();
        } catch (deleteError) {
          logger.error(
              "Failed to clean up OTP after MSG91 error",
              deleteError,
          );
        }

        if (
          error instanceof HttpsError
        ) {
          throw error;
        }

        logger.error(
            "Unexpected MSG91 OTP error",
            error,
        );

        throw new HttpsError(
            "internal",
            "Unable to send WhatsApp OTP. " +
        "Please try again.",
        );
      }
    },
);

/**
 * Verify a MSG91 WhatsApp OTP.
 */
exports.verifyMsg91Otp = onCall(
    {
      region:
      "asia-south1",
    },

    async (request) => {
      const data =
      request.data || {};

      const tenantId =
      typeof data.tenantId === "string" ?
        data.tenantId.trim() :
        "";

      if (!tenantId) {
        throw new HttpsError(
            "invalid-argument",
            "tenantId is required.",
        );
      }

      const phone =
      normalizeIndianPhone(
          data.phoneNumber,
      );

      const otp =
      typeof data.otp === "string" ?
        data.otp.trim() :
        "";

      if (!/^\d{6}$/.test(otp)) {
        throw new HttpsError(
            "invalid-argument",
            "Please enter a valid 6-digit OTP.",
        );
      }

      const tenantRef =
      db
          .collection("tenants")
          .doc(tenantId);

      const tenantSnap =
      await tenantRef.get();

      if (!tenantSnap.exists) {
        throw new HttpsError(
            "not-found",
            "Tenant not found.",
        );
      }

      const tenantData =
      tenantSnap.data() || {};

      const msg91 =
      tenantData.msg91 || {};

      if (msg91.enabled !== true) {
        throw new HttpsError(
            "failed-precondition",
            "WhatsApp OTP is not enabled for this tenant.",
        );
      }

      const otpRef =
      tenantRef
          .collection(
              "otpVerifications",
          )
          .doc(
              phone.local,
          );

      const otpSnap =
      await otpRef.get();

      if (!otpSnap.exists) {
        throw new HttpsError(
            "not-found",
            "OTP not found. Please request a new OTP.",
        );
      }

      const otpData =
      otpSnap.data() || {};

      // ----------------------------------------------------------
      // EXPIRY CHECK
      // ----------------------------------------------------------

      const expiresAt =
      otpData.expiresAt;

      if (
        !expiresAt ||
      typeof expiresAt.toMillis !==
        "function"
      ) {
        await otpRef.delete();

        throw new HttpsError(
            "failed-precondition",
            "OTP has expired. Please request a new OTP.",
        );
      }

      if (
        expiresAt.toMillis() <=
      Date.now()
      ) {
        await otpRef.delete();

        throw new HttpsError(
            "deadline-exceeded",
            "OTP has expired. Please request a new OTP.",
        );
      }

      // ----------------------------------------------------------
      // ATTEMPT LIMIT
      // ----------------------------------------------------------

      const attempts =
      Number(
          otpData.attempts,
      ) || 0;

      if (
        attempts >=
      OTP_MAX_ATTEMPTS
      ) {
        await otpRef.delete();

        throw new HttpsError(
            "resource-exhausted",
            "Too many incorrect attempts. " +
        "Please request a new OTP.",
        );
      }

      // ----------------------------------------------------------
      // HASH OTP
      // ----------------------------------------------------------

      const submittedHash =
      hashOtp(otp);

      const storedHash =
      typeof otpData.otpHash === "string" ?
        otpData.otpHash :
        "";

      const isValid =
      hashesMatch(
          submittedHash,
          storedHash,
      );

      // ----------------------------------------------------------
      // INVALID OTP
      // ----------------------------------------------------------

      if (!isValid) {
        const nextAttempts =
        attempts + 1;

        if (
          nextAttempts >=
        OTP_MAX_ATTEMPTS
        ) {
          await otpRef.delete();

          throw new HttpsError(
              "resource-exhausted",
              "Too many incorrect attempts. " +
          "Please request a new OTP.",
          );
        }

        await otpRef.update({
          attempts:
          nextAttempts,
        });

        const remainingAttempts =
        OTP_MAX_ATTEMPTS -
        nextAttempts;

        throw new HttpsError(
            "invalid-argument",
            "Invalid OTP. " +
        `${remainingAttempts} attempt` +
        `${remainingAttempts === 1 ? "" : "s"} remaining.`,
        );
      }

      // ----------------------------------------------------------
      // OTP IS VALID
      // ----------------------------------------------------------

      await otpRef.delete();

      // ----------------------------------------------------------
      // FIND EXISTING FIREBASE USER
      // ----------------------------------------------------------
      //
      // IMPORTANT:
      // We deliberately use getUserByPhoneNumber().
      //
      // This preserves existing Firebase UIDs for current
      // admin/customer accounts instead of creating a new UID
      // every time the authentication provider changes.
      //
      // ----------------------------------------------------------

      let firebaseUser;

      try {
        firebaseUser =
        await auth.getUserByPhoneNumber(
            phone.e164,
        );

        logger.info(
            "Existing Firebase user found for verified phone",
            {
              tenantId,
              uid:
            firebaseUser.uid,
            },
        );
      } catch (error) {
        if (
          error &&
        error.code ===
          "auth/user-not-found"
        ) {
          firebaseUser =
          await auth.createUser({
            phoneNumber:
              phone.e164,
          });

          logger.info(
              "Created Firebase user for verified phone",
              {
                tenantId,
                uid:
              firebaseUser.uid,
              },
          );
        } else {
          logger.error(
              "Firebase user lookup failed",
              error,
          );

          throw new HttpsError(
              "internal",
              "Unable to create your authenticated account. " +
          "Please try again.",
          );
        }
      }

      // ----------------------------------------------------------
      // CREATE CUSTOM TOKEN
      // ----------------------------------------------------------
      //
      // tenantId is included as a custom claim so the authenticated
      // session knows which tenant initiated this login.
      //
      // ----------------------------------------------------------

      const customToken =
      await auth.createCustomToken(
          firebaseUser.uid,
          {
            tenantId:
            tenantId,

            authProvider:
            "msg91_whatsapp",
          },
      );

      logger.info(
          "MSG91 OTP verification successful",
          {
            tenantId,

            uid:
          firebaseUser.uid,

            phoneNumber:
          phone.e164,
          },
      );

      return {
        success:
        true,

        uid:
        firebaseUser.uid,

        phoneNumber:
        phone.e164,

        customToken:
        customToken,
      };
    },
);
