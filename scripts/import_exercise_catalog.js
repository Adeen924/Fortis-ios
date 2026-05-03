const fs = require("fs");
const path = require("path");
const { createHash } = require("crypto");

const inputPath = process.argv[2];
const dryRun = process.argv.includes("--dry-run");

if (!inputPath) {
  console.error("Usage: node scripts/import_exercise_catalog.js <exercises.json> [--dry-run]");
  process.exit(1);
}

const serviceAccountPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
if (!dryRun && !serviceAccountPath) {
  console.error("Set GOOGLE_APPLICATION_CREDENTIALS to your Firebase service account JSON path.");
  process.exit(1);
}

const requiredFields = [
  "name",
  "category",
  "equipmentType",
  "primaryMuscles",
  "secondaryMuscles",
  "instructions",
  "isCustom",
];

function readExercises(filePath) {
  const absolutePath = path.resolve(filePath);
  const data = JSON.parse(fs.readFileSync(absolutePath, "utf8"));
  if (!Array.isArray(data)) {
    throw new Error("Expected the input file to contain a JSON array.");
  }
  return data;
}

function deterministicId(raw, index) {
  if (typeof raw.id === "string" && raw.id.trim()) {
    return raw.id.trim();
  }

  const seed = [
    index,
    raw.name,
    raw.category,
    raw.equipmentType,
    Array.isArray(raw.primaryMuscles) ? raw.primaryMuscles.join(",") : "",
  ].join("|");
  const hash = createHash("sha1").update(seed).digest("hex").slice(0, 32);
  return [
    hash.slice(0, 8),
    hash.slice(8, 12),
    hash.slice(12, 16),
    hash.slice(16, 20),
    hash.slice(20, 32),
  ].join("-");
}

function normalizedExercise(raw, index) {
  for (const field of requiredFields) {
    if (raw[field] === undefined || raw[field] === null) {
      throw new Error(`Exercise ${index} is missing required field: ${field}`);
    }
  }

  if (!Array.isArray(raw.primaryMuscles) || raw.primaryMuscles.length === 0) {
    throw new Error(`Exercise ${index} must have at least one primary muscle.`);
  }

  if (!Array.isArray(raw.secondaryMuscles)) {
    throw new Error(`Exercise ${index} secondaryMuscles must be an array.`);
  }

  const id = deterministicId(raw, index);

  return {
    id,
    name: String(raw.name).trim(),
    category: String(raw.category).trim(),
    equipmentType: String(raw.equipmentType).trim(),
    primaryMuscles: raw.primaryMuscles.map(String),
    secondaryMuscles: raw.secondaryMuscles.map(String),
    instructions: String(raw.instructions).trim(),
    isCustom: Boolean(raw.isCustom),
    ...(raw.mediaImageName ? { mediaImageName: String(raw.mediaImageName) } : {}),
    ...(raw.mediaVideoName ? { mediaVideoName: String(raw.mediaVideoName) } : {}),
  };
}

async function main() {
  const exercises = readExercises(inputPath).map(normalizedExercise);
  const duplicates = new Map();

  for (const exercise of exercises) {
    const key = exercise.name.toLowerCase();
    duplicates.set(key, (duplicates.get(key) || 0) + 1);
  }

  const duplicateNames = [...duplicates.entries()].filter(([, count]) => count > 1);
  console.log(`Loaded ${exercises.length} exercises.`);
  console.log(`Duplicate name groups: ${duplicateNames.length}`);

  if (dryRun) {
    console.log("Dry run only. No Firestore writes performed.");
    console.log(JSON.stringify(exercises[0], null, 2));
    return;
  }

  const admin = require("firebase-admin");

  admin.initializeApp({
    credential: admin.credential.cert(require(path.resolve(serviceAccountPath))),
  });

  const db = admin.firestore();
  const collection = db.collection("exercise_catalog");
  const batchSize = 450;

  for (let i = 0; i < exercises.length; i += batchSize) {
    const batch = db.batch();
    const chunk = exercises.slice(i, i + batchSize);

    for (const exercise of chunk) {
      batch.set(collection.doc(exercise.id), exercise, { merge: true });
    }

    await batch.commit();
    console.log(`Uploaded ${Math.min(i + batchSize, exercises.length)} / ${exercises.length}`);
  }

  console.log("Exercise catalog import complete.");
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
