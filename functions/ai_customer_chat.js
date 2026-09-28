const {onCall, HttpsError} = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

/**
 * Rentocar AI Customer Chat.
 *
 * This function is the secure entry point for the customer AI assistant.
 *
 * Current responsibilities:
 * - Firebase Authentication
 * - Tenant validation
 * - Customer validation
 * - Conversation creation
 * - Conversation history
 * - Booking state
 * - Basic intent detection
 * - Booking information extraction
 * - AI response persistence
 *
 * Future responsibilities:
 * - AI provider
 * - Car lookup
 * - Availability lookup
 * - Pricing lookup
 * - Package lookup
 * - Booking creation
 * - FAQ/support
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

        console.log(
            "[AI_CHAT] 📦 REQUEST DATA",
            {
              tenantId,
              uid,
              messageLength: message.length,
              conversationId,
            },
        );

        // ============================================================
        // 3. VALIDATE TENANT
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
        // 5. TENANT VALIDATION
        // ============================================================

        const tenantRef = db
            .collection("tenants")
            .doc(tenantId);

        const tenantSnap =
          await tenantRef.get();

        console.log(
            "[AI_CHAT] 🏢 TENANT",
            {
              tenantId,
              exists: tenantSnap.exists,
            },
        );

        if (!tenantSnap.exists) {
          throw new HttpsError(
              "not-found",
              "Tenant was not found.",
          );
        }

        // ============================================================
        // 6. CUSTOMER VALIDATION
        // ============================================================

        const customerRef = tenantRef
            .collection("customers")
            .doc(uid);

        const customerSnap =
          await customerRef.get();

        console.log(
            "[AI_CHAT] 👤 CUSTOMER",
            {
              customerId: uid,
              exists: customerSnap.exists,
            },
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
        // 7. CUSTOMER CONTEXT
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

        console.log(
            "[AI_CHAT] 👤 CUSTOMER CONTEXT",
            {
              customerId:
                customerContext.customerId,

              name:
                customerContext.name,

              phone:
                customerContext.phone ?
                  "***" :
                  null,

              email:
                customerContext.email ?
                  "***" :
                  null,
            },
        );

        // ============================================================
        // 8. CONVERSATION ID
        // ============================================================

        const finalConversationId =
          conversationId ||
          db
              .collection("_ai_conversations")
              .doc()
              .id;

        console.log(
            "[AI_CHAT] 💬 CONVERSATION",
            {
              conversationId:
                finalConversationId,

              isNew:
                !conversationId,
            },
        );

        // ============================================================
        // 9. CONVERSATION REFERENCE
        // ============================================================

        const conversationRef = tenantRef
            .collection("customers")
            .doc(uid)
            .collection("aiConversations")
            .doc(finalConversationId);

        // ============================================================
        // 10. LOAD EXISTING CONVERSATION
        // ============================================================

        const conversationSnap =
          await conversationRef.get();

        let existingConversation = {};

        if (conversationSnap.exists) {
          existingConversation =
            conversationSnap.data() || {};

          console.log(
              "[AI_CHAT] 📖 EXISTING CONVERSATION LOADED",
          );
        } else {
          console.log(
              "[AI_CHAT] 🆕 NEW CONVERSATION",
          );
        }

        // ============================================================
        // 11. EXISTING BOOKING STATE
        // ============================================================

        const existingBookingState =
          existingConversation.bookingState || {};

        console.log(
            "[AI_CHAT] 🧠 EXISTING BOOKING STATE",
            existingBookingState,
        );

        // ============================================================
        // 12. CREATE / UPDATE CONVERSATION
        // ============================================================

        const conversationPayload = {
          conversationId:
            finalConversationId,

          customerId:
            uid,

          tenantId,

          customerContext,

          updatedAt:
            admin.firestore.FieldValue
                .serverTimestamp(),
        };

        if (!conversationSnap.exists) {
          conversationPayload.createdAt =
            admin.firestore.FieldValue
                .serverTimestamp();
        }

        await conversationRef.set(
            conversationPayload,
            {
              merge: true,
            },
        );

        console.log(
            "[AI_CHAT] 💾 CONVERSATION SAVED",
        );

        // ============================================================
        // 13. STORE USER MESSAGE
        // ============================================================

        await conversationRef
            .collection("messages")
            .add({
              role: "user",

              content:
                message,

              createdAt:
                admin.firestore.FieldValue
                    .serverTimestamp(),
            });

        console.log(
            "[AI_CHAT] 💾 USER MESSAGE STORED",
        );

        // ============================================================
        // 14. LOAD RECENT MESSAGE HISTORY
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
            "[AI_CHAT] 📚 MESSAGE HISTORY",
            {
              count:
                history.length,
            },
        );

        // ============================================================
        // 15. DETECT INTENT
        // ============================================================

        const bookingIntent =
          detectBookingIntent(
              message,
          );

        console.log(
            "[AI_CHAT] 🎯 DETECTED INTENT",
            bookingIntent,
        );

        // ============================================================
        // 16. EXTRACT BOOKING INFORMATION
        // ============================================================

        const extractedBookingData =
          extractBookingInformation(
              message,
              existingBookingState,
          );

        console.log(
            "[AI_CHAT] 🔎 EXTRACTED BOOKING DATA",
            extractedBookingData,
        );

        // ============================================================
        // 17. UPDATE BOOKING STATE
        // ============================================================

        const updatedBookingState = {
          ...existingBookingState,

          intent:
            bookingIntent.intent,

          confidence:
            bookingIntent.confidence,

          pickupDate:
            extractedBookingData.pickupDate !== null ?
              extractedBookingData.pickupDate :
              existingBookingState.pickupDate ||
              null,

          pickupTime:
            extractedBookingData.pickupTime !== null ?
              extractedBookingData.pickupTime :
              existingBookingState.pickupTime ||
              null,

          returnDate:
            extractedBookingData.returnDate !== null ?
              extractedBookingData.returnDate :
              existingBookingState.returnDate ||
              null,

          returnTime:
            extractedBookingData.returnTime !== null ?
              extractedBookingData.returnTime :
              existingBookingState.returnTime ||
              null,

          branchId:
            extractedBookingData.branchId !== null ?
              extractedBookingData.branchId :
              existingBookingState.branchId ||
              null,

          carId:
            extractedBookingData.carId !== null ?
              extractedBookingData.carId :
              existingBookingState.carId ||
              null,

          carType:
            extractedBookingData.carType !== null ?
              extractedBookingData.carType :
              existingBookingState.carType ||
              null,

          lastUserMessage:
            message,

          updatedAt:
            new Date().toISOString(),
        };

        // ============================================================
        // 18. SAVE BOOKING STATE
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
        // 19. DETERMINE MISSING BOOKING INFORMATION
        // ============================================================

        const missingFields =
          getMissingBookingFields(
              updatedBookingState,
          );

        console.log(
            "[AI_CHAT] 📝 MISSING BOOKING FIELDS",
            missingFields,
        );

        // ============================================================
        // 20. TEMPORARY AI RESPONSE
        // ============================================================
        //
        // IMPORTANT:
        //
        // This is still the local response layer.
        //
        // The next stage will connect the actual AI provider.
        //
        // The state structure is already prepared for:
        //
        // pickupDate
        // pickupTime
        // returnDate
        // returnTime
        // branchId
        // carId
        // carType
        // availability
        // pricing
        // package
        // booking
        //
        // ============================================================

        const responseResult =
          buildTemporaryAIResponse({
            customerContext,
            bookingState:
              updatedBookingState,
            bookingIntent,
            missingFields,
            message,
          });

        const reply =
          responseResult.reply;

        // ============================================================
        // 21. STORE ASSISTANT MESSAGE
        // ============================================================

        await conversationRef
            .collection("messages")
            .add({
              role: "assistant",

              content:
                reply,

              createdAt:
                admin.firestore.FieldValue
                    .serverTimestamp(),

              metadata: {
                temporaryResponse:
                  true,

                intent:
                  bookingIntent.intent,

                missingFields,
              },
            });

        console.log(
            "[AI_CHAT] 💬 ASSISTANT MESSAGE STORED",
        );

        // ============================================================
        // 22. EXECUTION TIME
        // ============================================================

        const executionTime =
          Date.now() - startedAt;

        console.log(
            "[AI_CHAT] 🏁 REQUEST COMPLETED",
            {
              tenantId,

              customerId:
                uid,

              conversationId:
                finalConversationId,

              intent:
                bookingIntent.intent,

              historyCount:
                history.length,

              missingFields,

              executionTimeMs:
                executionTime,
            },
        );

        console.log(
            "==================================================",
        );

        // ============================================================
        // 23. RESPONSE
        // ============================================================

        return {
          success: true,

          conversationId:
            finalConversationId,

          message: {
            role: "assistant",

            content:
              reply,
          },

          customer: {
            id:
              uid,

            name:
              customerContext.name,
          },

          bookingState:
            updatedBookingState,

          missingFields,

          metadata: {
            tenantId,

            executionTimeMs:
              executionTime,

            aiEnabled:
              false,

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


/**
 * Detects the customer's current AI intent.
 *
 * @param {string} message Customer message.
 * @return {{intent: string, confidence: number}} Detected intent.
 */
function detectBookingIntent(message) {
  const normalizedMessage =
    message.toLowerCase();

  const bookingWords = [
    "book",
    "booking",
    "rent",
    "rental",
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
    "package",
    "km",
    "kilometer",
    "kilometers",
  ];

  const hasBookingWord =
    bookingWords.some(
        (word) =>
          normalizedMessage.includes(word),
    );

  const hasAvailabilityWord =
    availabilityWords.some(
        (word) =>
          normalizedMessage.includes(word),
    );

  const hasPricingWord =
    pricingWords.some(
        (word) =>
          normalizedMessage.includes(word),
    );

  if (hasAvailabilityWord) {
    return {
      intent: "availability",
      confidence: 0.85,
    };
  }

  if (hasPricingWord) {
    return {
      intent: "pricing",
      confidence: 0.80,
    };
  }

  if (hasBookingWord) {
    return {
      intent: "booking",
      confidence: 0.75,
    };
  }

  return {
    intent: "general",
    confidence: 0.50,
  };
}


/**
 * Extracts simple booking fields from the customer's message.
 *
 * This intentionally performs conservative extraction. Natural-language
 * date interpretation will be handled by the real AI layer later.
 *
 * @param {string} message Customer message.
 * @param {Object} existingBookingState Existing booking state.
 * @return {Object} Extracted booking information.
 */
function extractBookingInformation(
    message,
    existingBookingState,
) {
  const normalizedMessage =
    message.toLowerCase();

  let carType =
    existingBookingState.carType ||
    null;

  const carTypes = [
    "suv",
    "sedan",
    "hatchback",
    "muv",
    "luxury",
    "compact",
    "premium",
  ];

  for (const type of carTypes) {
    if (normalizedMessage.includes(type)) {
      carType = type;
      break;
    }
  }

  return {
    pickupDate:
      null,

    pickupTime:
      null,

    returnDate:
      null,

    returnTime:
      null,

    branchId:
      null,

    carId:
      null,

    carType,
  };
}


/**
 * Determines which booking fields are still missing.
 *
 * @param {Object} bookingState Current booking state.
 * @return {string[]} Missing booking field names.
 */
function getMissingBookingFields(
    bookingState,
) {
  const missingFields = [];

  if (!bookingState.pickupDate) {
    missingFields.push(
        "pickupDate",
    );
  }

  if (!bookingState.pickupTime) {
    missingFields.push(
        "pickupTime",
    );
  }

  if (!bookingState.returnDate) {
    missingFields.push(
        "returnDate",
    );
  }

  if (!bookingState.returnTime) {
    missingFields.push(
        "returnTime",
    );
  }

  if (!bookingState.branchId) {
    missingFields.push(
        "branchId",
    );
  }

  return missingFields;
}


/**
 * Builds the temporary AI response.
 *
 * This response layer will later be replaced by the real AI provider
 * and connected to the car, availability, pricing and booking tools.
 *
 * @param {Object} params Response parameters.
 * @param {Object} params.customerContext Customer context.
 * @param {Object} params.bookingState Current booking state.
 * @param {Object} params.bookingIntent Detected intent.
 * @param {string[]} params.missingFields Missing booking fields.
 * @param {string} params.message Customer message.
 * @return {{reply: string}} Assistant response.
 */
function buildTemporaryAIResponse({
  customerContext,
  bookingState,
  bookingIntent,
  missingFields,
  message,
}) {
  const firstName =
    customerContext.firstName ||
    customerContext.name ||
    "";

  // ============================================================
  // GENERAL
  // ============================================================

  if (
    bookingIntent.intent ===
    "general"
  ) {
    return {
      reply:
        `Hi${firstName ? ` ${firstName}` : ""}! 👋 ` +
        "I'm your Rentocar AI assistant. 🚗 " +
        "I can help you find cars, check availability, " +
        "understand pricing and packages, and arrange your booking. " +
        "What would you like to do?",
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
        "I can check the available cars and pricing for you. " +
        "First, tell me your pickup date and time, " +
        "return date and time, and preferred branch.",
    };
  }

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
        "I can check availability for you. " +
        "Please provide your pickup date and time, " +
        "return date and time, and preferred branch.",
    };
  }

  // ============================================================
  // BOOKING
  // ============================================================

  if (
    bookingIntent.intent ===
    "booking"
  ) {
    if (
      missingFields.includes(
          "pickupDate",
      )
    ) {
      return {
        reply:
          `Sure${firstName ? ` ${firstName}` : ""}! 🚘 ` +
          "Let's arrange your rental. " +
          "What date would you like to pick up the car?",
      };
    }

    if (
      missingFields.includes(
          "pickupTime",
      )
    ) {
      return {
        reply:
          "Great! 👍 What time would you like to pick up the car?",
      };
    }

    if (
      missingFields.includes(
          "returnDate",
      )
    ) {
      return {
        reply:
          "Perfect. 📅 What date would you like to return the car?",
      };
    }

    if (
      missingFields.includes(
          "returnTime",
      )
    ) {
      return {
        reply:
          "And what time would you like to return the car?",
      };
    }

    if (
      missingFields.includes(
          "branchId",
      )
    ) {
      return {
        reply:
          "Which pickup branch would you like to use?",
      };
    }

    return {
      reply:
        "Perfect! I have the basic booking details. " +
        "I'll now check the available cars and pricing.",
    };
  }

  // ============================================================
  // FALLBACK
  // ============================================================

  return {
    reply:
      "I can help you with your car rental. 🚗 " +
      "Tell me what you'd like to book or check.",
  };
}
