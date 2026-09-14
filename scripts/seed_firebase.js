const { initializeApp, cert } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");

const serviceAccount = require("../serviceAccountKey.json");

initializeApp({
  credential: cert(serviceAccount),
});

const db = getFirestore();

async function seed() {
  console.log("Starting Rentocar Firebase setup...");

  await db.collection("tenants").doc("tenant_001").set({
    tenantId: "tenant_001",

    appName: "Rentocar",

    businessName: "Rentocar",

    logoUrl: "",

    splashImageUrl: "",

    primaryColor: "#0B0F19",

    secondaryColor: "#D4AF37",

    currency: "INR",

    phone: "+91 98765 43210",

    email: "support@rentocar.com",

    supportNumber: "+91 98765 43210",

    isActive: true,

    features: {
      branches: true,
      booking: true,
      payments: true,
      kmPackages: true,
      coupons: true,
      extensions: true,
      notifications: true,
    },

    createdAt: new Date(),
    updatedAt: new Date(),
  });

  console.log("================================");
  console.log("✅ Rentocar tenant created!");
  console.log("Tenant ID: tenant_001");
  console.log("App Name: Rentocar");
  console.log("Business: Rentocar");
  console.log("================================");
}

seed()
  .then(() => {
    console.log("Done.");
    process.exit(0);
  })
  .catch((error) => {
    console.error("❌ Firebase setup failed:");
    console.error(error);
    process.exit(1);
  });