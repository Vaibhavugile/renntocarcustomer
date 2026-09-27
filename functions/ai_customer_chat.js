const {onCall, HttpsError} = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

/**
 * Rentocar AI Customer Chat
 *
 * STEP 1:
 * - Firebase Auth verification
 * - Tenant verification
 * - Customer verification
 * - Basic conversation input
 * - Safe response structure
 *
 * Later:
 * - Cars
 * - Availability
 * - Pricing
 * - Packages
 * - Bookings
 * - Payments
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
      console.log("[AI_CHAT] REQUEST STARTED");
      console.log("==================================================");

      try {
      // ------------------------------------------------------------
      // 1. AUTHENTICATION
      // ------------------------------------------------------------

        if (!request.auth) {
          console.error("[AI_CHAT] ❌ User is not authenticated");

          throw new HttpsError(
              "unauthenticated",
              "You must be logged in to use the AI assistant.",
          );
        }

        const uid = request.auth.uid;

        console.log("[AI_CHAT] 🔐 Authenticated user:", uid);

        // ------------------------------------------------------------
        // 2. REQUEST DATA
        // ------------------------------------------------------------

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

        // ------------------------------------------------------------
        // 3. VALIDATE TENANT
        // ------------------------------------------------------------

        if (!tenantId) {
          console.error("[AI_CHAT] ❌ tenantId missing");

          throw new HttpsError(
              "invalid-argument",
              "tenantId is required.",
          );
        }

        // ------------------------------------------------------------
        // 4. VALIDATE MESSAGE
        // ------------------------------------------------------------

        if (!message) {
          console.error("[AI_CHAT] ❌ message missing");

          throw new HttpsError(
              "invalid-argument",
              "message is required.",
          );
        }

        if (message.length > 4000) {
          console.error("[AI_CHAT] ❌ message too long");

          throw new HttpsError(
              "invalid-argument",
              "Message is too long.",
          );
        }

        // ------------------------------------------------------------
        // 5. VERIFY TENANT
        // ------------------------------------------------------------

        const tenantRef = db
            .collection("tenants")
            .doc(tenantId);

        const tenantSnap = await tenantRef.get();

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

        // ------------------------------------------------------------
        // 6. VERIFY CUSTOMER
        // ------------------------------------------------------------

        const customerRef = tenantRef
            .collection("customers")
            .doc(uid);

        const customerSnap = await customerRef.get();

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

        const customerData = customerSnap.data() || {};

        console.log("[AI_CHAT] 👤 Customer verified", {
          customerId: uid,
          tenantId,
        });

        // ------------------------------------------------------------
        // 7. BASIC CUSTOMER CONTEXT
        // ------------------------------------------------------------

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

        // ------------------------------------------------------------
        // 8. CONVERSATION ID
        // ------------------------------------------------------------

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

        // ------------------------------------------------------------
        // 9. STORE USER MESSAGE
        // ------------------------------------------------------------

        const conversationRef = tenantRef
            .collection("customers")
            .doc(uid)
            .collection("aiConversations")
            .doc(finalConversationId);

        await conversationRef.set(
            {
              conversationId: finalConversationId,
              customerId: uid,
              tenantId,
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
              createdAt: admin.firestore.FieldValue.serverTimestamp(),
            },
            {
              merge: true,
            },
        );

        await conversationRef
            .collection("messages")
            .add({
              role: "user",
              content: message,
              createdAt:
            admin.firestore.FieldValue.serverTimestamp(),
            });

        console.log("[AI_CHAT] 💾 User message stored");

        // ------------------------------------------------------------
        // 10. STEP-1 RESPONSE
        // ------------------------------------------------------------
        //
        // IMPORTANT:
        // We intentionally don't call an AI provider yet.
        //
        // In the next step we'll connect the actual AI model and
        // provide tools for:
        //
        // - Cars
        // - Availability
        // - Pricing
        // - Packages
        // - Bookings
        // - Payments
        // - Branches
        // - FAQs
        //
        // ------------------------------------------------------------

        const reply =
        "Hi" +
        (customerContext.firstName ?
          ` ${customerContext.firstName}` :
          "") +
        "! 👋 I'm your Rentocar AI assistant. " +
        "I can help you with cars, availability, pricing, " +
        "bookings and more. What would you like to know?";

        // ------------------------------------------------------------
        // 11. STORE AI MESSAGE
        // ------------------------------------------------------------

        await conversationRef
            .collection("messages")
            .add({
              role: "assistant",
              content: reply,
              createdAt:
            admin.firestore.FieldValue.serverTimestamp(),
            });

        // ------------------------------------------------------------
        // 12. RESPONSE
        // ------------------------------------------------------------

        const executionTime =
        Date.now() - startedAt;

        console.log(
            "[AI_CHAT] ✅ REQUEST COMPLETED",
            {
              tenantId,
              customerId: uid,
              conversationId: finalConversationId,
              executionTimeMs: executionTime,
            },
        );

        console.log("==================================================");

        return {
          success: true,

          conversationId: finalConversationId,

          message: {
            role: "assistant",
            content: reply,
          },

          customer: {
            id: uid,
            name: customerContext.name,
          },

          metadata: {
            tenantId,
            executionTimeMs: executionTime,
            aiEnabled: false,
            version: "1.0.0",
          },
        };
      } catch (error) {
        console.error("[AI_CHAT] ❌ ERROR", {
          code: error && error.code ?
          error.code :
          "",

          message: error && error.message ?
          error.message :
          String(error),

          stack: error && error.stack ?
          error.stack :
          "",
        });

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
