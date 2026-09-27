const {onCall, HttpsError} = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

/**
 * Rentocar AI Customer Chat
 *
 * STEP 2
 *
 * Current capabilities:
 * - Firebase Auth verification
 * - Tenant verification
 * - Customer verification
 * - Conversation creation
 * - Conversation history
 * - Customer context
 * - Booking state persistence
 * - Basic booking information extraction
 * - Missing-information detection
 * - Safe response structure
 *
 * Next:
 * - Real AI provider
 * - Cars
 * - Availability
 * - Pricing
 * - Packages
 * - Booking creation
 * - FAQs
 * - Voice
 */

exports.aiCustomerChat = onCall(
    {
      region: "us-central1",
      timeoutSeconds: 60,
      memory: "512MiB",
      cors: true,
    },
    async (request) => {
      const startedAt = Date.now();

      console.log("==================================================");
      console.log("[AI_CHAT] 🚀 REQUEST STARTED");
      console.log("==================================================");

      try {
        // ============================================================
        // 1. AUTHENTICATION
        // ============================================================

        if (!request.auth) {
          console.error(
              "[AI_CHAT] ❌ User is not authenticated",
          );

          throw new HttpsError(
              "unauthenticated",
              "You must be logged in to use the AI assistant.",
          );
        }

        const uid = request.auth.uid;

        console.log(
            "[AI_CHAT] 🔐 Authenticated user:",
            uid,
        );

        // ============================================================
        // 2. REQUEST DATA
        // ============================================================

        const data = request.data || {};

        const tenantId =
          typeof data.tenantId === "string" ?
            data.tenantId.trim() :
            "";

        const message =
          typeof data.message === "string" ?
            data.message.trim() :
            "";

        const conversationId =
          typeof data.conversationId === "string" ?
            data.conversationId.trim() :
            null;

        console.log("[AI_CHAT] 📦 REQUEST DATA", {
          tenantId,
          uid,
          messageLength: message.length,
          conversationId,
        });

        // ============================================================
        // 3. VALIDATE TENANT ID
        // ============================================================

        if (!tenantId) {
          console.error(
              "[AI_CHAT] ❌ tenantId missing",
          );

          throw new HttpsError(
              "invalid-argument",
              "tenantId is required.",
          );
        }

        // ============================================================
        // 4. VALIDATE MESSAGE
        // ============================================================

        if (!message) {
          console.error(
              "[AI_CHAT] ❌ message missing",
          );

          throw new HttpsError(
              "invalid-argument",
              "message is required.",
          );
        }

        if (message.length > 4000) {
          console.error(
              "[AI_CHAT] ❌ message too long",
          );

          throw new HttpsError(
              "invalid-argument",
              "Message is too long.",
          );
        }

        // ============================================================
        // 5. TENANT REFERENCE
        // ============================================================

        const tenantRef = db
            .collection("tenants")
            .doc(tenantId);

        // ============================================================
        // 6. VERIFY TENANT
        // ============================================================

        const tenantSnap =
          await tenantRef.get();

        console.log(
            "[AI_CHAT] 🏢 Tenant exists:",
            tenantSnap.exists,
        );

        if (!tenantSnap.exists) {
          throw new HttpsError(
              "not-found",
              "Tenant was not found.",
          );
        }

        const tenantData =
          tenantSnap.data() || {};

        // ============================================================
        // 7. VERIFY CUSTOMER
        // ============================================================

        const customerRef = tenantRef
            .collection("customers")
            .doc(uid);

        const customerSnap =
          await customerRef.get();

        console.log(
            "[AI_CHAT] 👤 Customer exists:",
            customerSnap.exists,
        );

        if (!customerSnap.exists) {
          throw new HttpsError(
              "permission-denied",
              "Customer account was not found for this tenant.",
          );
        }

        const customerData =
          customerSnap.data() || {};

        console.log(
            "[AI_CHAT] ✅ CUSTOMER VERIFIED",
            {
              customerId: uid,
              tenantId,
            },
        );

        // ============================================================
        // 8. CUSTOMER CONTEXT
        // ============================================================

        const customerContext = {
          customerId: uid,
          tenantId,

          name:
            customerData.name ||
            customerData.fullName ||
            null,

          firstName:
            customerData.firstName ||
            null,

          lastName:
            customerData.lastName ||
            null,

          phone:
            customerData.phone ||
            customerData.phoneNumber ||
            null,

          email:
            customerData.email ||
            null,
        };

        // ============================================================
        // 9. CONVERSATION ID
        // ============================================================

        const finalConversationId =
          conversationId ||
          db
              .collection("_ai_conversations")
              .doc()
              .id;

        console.log(
            "[AI_CHAT] 💬 Conversation:",
            finalConversationId,
        );

        // ============================================================
        // 10. CUSTOMER CONVERSATION REFERENCE
        // ============================================================

        const conversationRef = tenantRef
            .collection("customers")
            .doc(uid)
            .collection("aiConversations")
            .doc(finalConversationId);

        // ============================================================
        // 11. LOAD EXISTING CONVERSATION
        // ============================================================

        const conversationSnap =
          await conversationRef.get();

        let existingConversation = {};

        if (conversationSnap.exists) {
          existingConversation =
            conversationSnap.data() || {};

          console.log(
              "[AI_CHAT] 📖 Existing conversation loaded",
          );
        } else {
          console.log(
              "[AI_CHAT] 🆕 New conversation",
          );
        }

        // ============================================================
        // 12. LOAD BOOKING STATE
        // ============================================================

        const existingBookingState =
          existingConversation.bookingState || {};

        console.log(
            "[AI_CHAT] 🧠 EXISTING BOOKING STATE",
            existingBookingState,
        );

        // ============================================================
        // 13. STORE / UPDATE CONVERSATION
        // ============================================================

        await conversationRef.set(
            {
              conversationId: finalConversationId,

              customerId: uid,

              tenantId,

              customerContext,

              updatedAt:
                admin.firestore.FieldValue
                    .serverTimestamp(),

              createdAt:
                existingConversation.createdAt ||
                admin.firestore.FieldValue
                    .serverTimestamp(),
            },
            {
              merge: true,
            },
        );

        // ============================================================
        // 14. STORE USER MESSAGE
        // ============================================================

        await conversationRef
            .collection("messages")
            .add({
              role: "user",

              content: message,

              createdAt:
                admin.firestore.FieldValue
                    .serverTimestamp(),
            });

        console.log(
            "[AI_CHAT] 💾 User message stored",
        );

        // ============================================================
        // 15. BASIC BOOKING INFORMATION EXTRACTION
        // ============================================================
        //
        // IMPORTANT:
        //
        // This is intentionally conservative.
        //
        // We are NOT pretending that normal JavaScript can reliably
        // understand every natural-language date.
        //
        // The real AI provider will eventually produce structured
        // booking data.
        //
        // For now we preserve existing state and detect common
        // booking-related intent.

        const lowerMessage =
          message.toLowerCase();

        const bookingIntent =
          detectBookingIntent(
              lowerMessage,
          );

        console.log(
            "[AI_CHAT] 🎯 BOOKING INTENT",
            bookingIntent,
        );

        // ============================================================
        // 16. UPDATE BOOKING STATE
        // ============================================================

        const updatedBookingState = {
          ...existingBookingState,

          intent:
            bookingIntent.intent,

          lastUserMessage:
            message,

          updatedAt:
            new Date().toISOString(),
        };

        // ============================================================
        // 17. SAVE BOOKING STATE
        // ============================================================

        await conversationRef.set(
            {
              bookingState:
                updatedBookingState,

              updatedAt:
                admin.firestore.FieldValue
                    .serverTimestamp(),
            },
            {
              merge: true,
            },
        );

        console.log(
            "[AI_CHAT] 💾 BOOKING STATE UPDATED",
            updatedBookingState,
        );

        // ============================================================
        // 18. LOAD RECENT CONVERSATION HISTORY
        // ============================================================

        const messagesSnap =
          await conversationRef
              .collection("messages")
              .orderBy(
                  "createdAt",
                  "desc",
              )
              .limit(20)
              .get();

        const history =
          messagesSnap.docs
              .reverse()
              .map((doc) => {
                const messageData =
                  doc.data() || {};

                return {
                  role:
                    messageData.role ||
                    "unknown",

                  content:
                    messageData.content ||
                    "",
                };
              });

        console.log(
            "[AI_CHAT] 📚 HISTORY COUNT:",
            history.length,
        );

        // ============================================================
        // 19. GENERATE CURRENT RESPONSE
        // ============================================================
        //
        // This is still the temporary local response.
        //
        // In the next step this section will be replaced with the
        // actual AI provider.
        //

        const responseResult =
          buildTemporaryAIResponse({
            customerContext,
            bookingState:
              updatedBookingState,
            bookingIntent,
            message,
          });

        const reply =
          responseResult.reply;

        // ============================================================
        // 20. STORE ASSISTANT MESSAGE
        // ============================================================

        await conversationRef
            .collection("messages")
            .add({
              role: "assistant",

              content: reply,

              createdAt:
                admin.firestore.FieldValue
                    .serverTimestamp(),

              metadata: {
                temporaryResponse: true,
                bookingIntent:
                  bookingIntent.intent,
              },
            });

        console.log(
            "[AI_CHAT] 💬 AI MESSAGE STORED",
        );

        // ============================================================
        // 21. EXECUTION TIME
        // ============================================================

        const executionTime =
          Date.now() - startedAt;

        console.log(
            "[AI_CHAT] ✅ REQUEST COMPLETED",
            {
              tenantId,
              customerId: uid,
              conversationId:
                finalConversationId,
              executionTimeMs:
                executionTime,
            },
        );

        console.log(
            "==================================================",
        );

        // ============================================================
        // 22. RESPONSE
        // ============================================================

        return {
          success: true,

          conversationId:
            finalConversationId,

          message: {
            role: "assistant",
            content: reply,
          },

          customer: {
            id: uid,

            name:
              customerContext.name,
          },

          bookingState:
            updatedBookingState,

          historyLength:
            history.length,

          metadata: {
            tenantId,

            executionTimeMs:
              executionTime,

            aiEnabled: false,

            provider:
              "temporary",

            version:
              "2.0.0",
          },
        };
      } catch (error) {
        console.error(
            "[AI_CHAT] ❌ ERROR",
            {
              code:
                error && error.code ?
                  error.code :
                  "",

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

        if (error instanceof HttpsError) {
          throw error;
        }

        throw new HttpsError(
            "internal",
            "Unable to process your AI request.",
        );
      }
    },
);


// ============================================================================
// BOOKING INTENT DETECTION
// ============================================================================

function detectBookingIntent(message) {
  const bookingWords = [
    "book",
    "booking",
    "rent",
    "rental",
    "car",
    "vehicle",
    "reserve",
    "reservation",
    "hire",
  ];

  const availabilityWords = [
    "available",
    "availability",
    "free",
    "vacant",
  ];

  const pricingWords = [
    "price",
    "pricing",
    "cost",
    "rate",
    "rent",
    "package",
    "km",
    "kilometer",
  ];

  const hasBookingWord =
    bookingWords.some((word) =>
      message.includes(word),
    );

  const hasAvailabilityWord =
    availabilityWords.some((word) =>
      message.includes(word),
    );

  const hasPricingWord =
    pricingWords.some((word) =>
      message.includes(word),
    );

  if (hasAvailabilityWord) {
    return {
      intent: "availability",
      confidence: 0.8,
    };
  }

  if (hasPricingWord) {
    return {
      intent: "pricing",
      confidence: 0.7,
    };
  }

  if (hasBookingWord) {
    return {
      intent: "booking",
      confidence: 0.7,
    };
  }

  return {
    intent: "general",
    confidence: 0.5,
  };
}


// ============================================================================
// TEMPORARY RESPONSE
// ============================================================================

function buildTemporaryAIResponse({
  customerContext,
  bookingState,
  bookingIntent,
  message,
}) {
  const firstName =
    customerContext.firstName ||
    customerContext.name ||
    "";

  // ============================================================
  // AVAILABILITY
  // ============================================================

  if (
    bookingIntent.intent ===
    "availability"
  ) {
    return {
      reply:
        `Sure${firstName ? ` ${firstName}` : ""}! 🚗 ` +
        "I can check the available cars for you. " +
        "Please tell me your pickup date and time, " +
        "return date and time, and your preferred branch.",
    };
  }

  // ============================================================
  // PRICING
  // ============================================================

  if (
    bookingIntent.intent ===
    "pricing"
  ) {
    return {
      reply:
        `Absolutely${firstName ? ` ${firstName}` : ""}! 💰 ` +
        "I can check the available cars, packages and pricing. " +
        "Tell me your pickup date, pickup time, return date " +
        "and return time.",
    };
  }

  // ============================================================
  // BOOKING
  // ============================================================

  if (
    bookingIntent.intent ===
    "booking"
  ) {
    return {
      reply:
        `Sure${firstName ? ` ${firstName}` : ""}! 🚘 ` +
        "Let's arrange your rental. " +
        "I'll need your pickup date and time, return date " +
        "and time, and preferably the branch or type of car " +
        "you want.",
    };
  }

  // ============================================================
  // GENERAL
  // ============================================================

  return {
    reply:
      `Hi${firstName ? ` ${firstName}` : ""}! 👋 ` +
      "I'm your Rentocar AI assistant. " +
      "I can help you find cars, check availability, " +
      "understand pricing and packages, and help with bookings. " +
      "What would you like to do?",
  };
}
