const { initializeApp, cert } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");

const serviceAccount = require("../serviceAccountKey.json");

initializeApp({
  credential: cert(serviceAccount),
});

const db = getFirestore();

const TENANT_ID = "tenant_001";

const branches = [
  {
    id: "branch_001",
    name: "Rentocar Wakad",
    city: "Pune",
    state: "Maharashtra",
    address: "Wakad, Pune",
    phone: "+91 98765 43210",
    email: "wakad@rentocar.com",
    latitude: 18.5995,
    longitude: 73.7898,
    isActive: true,
    isPickupAvailable: true,
    isReturnAvailable: true,
  },

  {
    id: "branch_002",
    name: "Rentocar Hinjewadi",
    city: "Pune",
    state: "Maharashtra",
    address: "Hinjewadi Phase 1, Pune",
    phone: "+91 98765 43210",
    email: "hinjewadi@rentocar.com",
    latitude: 18.5912,
    longitude: 73.7389,
    isActive: true,
    isPickupAvailable: true,
    isReturnAvailable: true,
  },

  {
    id: "branch_003",
    name: "Rentocar Baner",
    city: "Pune",
    state: "Maharashtra",
    address: "Baner, Pune",
    phone: "+91 98765 43210",
    email: "baner@rentocar.com",
    latitude: 18.5590,
    longitude: 73.7868,
    isActive: true,
    isPickupAvailable: true,
    isReturnAvailable: true,
  },
];

async function seedBranches() {
  console.log("");
  console.log("======================================");
  console.log("   RENTOCAR BRANCH SETUP");
  console.log("======================================");
  console.log("");

  // Check tenant
  const tenantRef = db
      .collection("tenants")
      .doc(TENANT_ID);

  const tenantDoc = await tenantRef.get();

  if (!tenantDoc.exists) {
    console.error(
      `❌ Tenant ${TENANT_ID} does not exist.`
    );

    console.log(
      "Please run seed_firebase.js first."
    );

    process.exit(1);
  }

  console.log(`✅ Tenant found: ${TENANT_ID}`);
  console.log("");

  // Create branches
  for (const branch of branches) {
    const branchRef = tenantRef
        .collection("branches")
        .doc(branch.id);

    await branchRef.set({
      branchId: branch.id,
      name: branch.name,
      city: branch.city,
      state: branch.state,
      address: branch.address,
      phone: branch.phone,
      email: branch.email,

      location: {
        latitude: branch.latitude,
        longitude: branch.longitude,
      },

      isActive: branch.isActive,

      isPickupAvailable:
          branch.isPickupAvailable,

      isReturnAvailable:
          branch.isReturnAvailable,

      createdAt: new Date(),
      updatedAt: new Date(),
    });

    console.log(
      `✅ Created: ${branch.name}`
    );
  }

  console.log("");
  console.log("======================================");
  console.log("   BRANCH SETUP COMPLETED");
  console.log("======================================");
  console.log("");
  console.log(`Tenant: ${TENANT_ID}`);
  console.log(`Branches created: ${branches.length}`);
  console.log("");
  console.log("Firebase structure:");
  console.log("");
  console.log("tenants");
  console.log("└── tenant_001");
  console.log("    └── branches");
  console.log("        ├── branch_001");
  console.log("        ├── branch_002");
  console.log("        └── branch_003");
  console.log("");
}

seedBranches()
  .then(() => {
    console.log("Done.");
    process.exit(0);
  })
  .catch((error) => {
    console.error("");
    console.error("❌ Branch setup failed:");
    console.error(error);
    process.exit(1);
  });