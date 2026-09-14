const { initializeApp, cert } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");

const serviceAccount = require("../serviceAccountKey.json");

initializeApp({
  credential: cert(serviceAccount),
});

const db = getFirestore();

async function seedAdmin() {
  const tenantId = "tenant_001";
  const adminId = "vBIYnitBT7VwSBkskQdq90OynnA3";

  const adminRef = db
    .collection("tenants")
    .doc(tenantId)
    .collection("admins")
    .doc(adminId);

  const adminData = {
    adminId: adminId,
    tenantId: tenantId,

    name: "Rentocar Admin",
    phone: "+918446442206",
    email: "admin@rentocar.com",

    roleId: "owner",

    isActive: true,

    createdAt: new Date(),
    updatedAt: new Date(),
  };

  await adminRef.set(adminData, { merge: true });

  console.log("");
  console.log("========================================");
  console.log("       ADMIN CREATED SUCCESSFULLY");
  console.log("========================================");
  console.log("Tenant ID :", tenantId);
  console.log("Admin ID  :", adminId);
  console.log("Name      :", adminData.name);
  console.log("Phone     :", adminData.phone);
  console.log("Email     :", adminData.email);
  console.log("Role ID   :", adminData.roleId);
  console.log("Active    :", adminData.isActive);
  console.log("========================================");
  console.log("");
}

seedAdmin()
  .then(() => {
    console.log("Seed completed successfully.");
    process.exit(0);
  })
  .catch((error) => {
    console.error("");
    console.error("========================================");
    console.error("          ADMIN SEED FAILED");
    console.error("========================================");
    console.error(error);
    console.error("========================================");
    console.error("");

    process.exit(1);
  });