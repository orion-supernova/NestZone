// Loads the exported JSONL and calls the importAll mutation on your
// (self-hosted) Convex deployment.
//
// Usage:
//   CONVEX_URL=https://nestzone-convex-api.walhallaa.com \
//   MIGRATION_SECRET=some-long-random-string \
//   node scripts/run-migration.mjs            # add: --wipe  to clear & reimport
//
// Requires: npm i convex   (in this folder or your convex project)

import { ConvexHttpClient } from "convex/browser";
import { readFileSync, readdirSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const __dir = dirname(fileURLToPath(import.meta.url));
const dataDir = join(__dir, "..", "data");

const url = process.env.CONVEX_URL;
const secret = process.env.MIGRATION_SECRET;
if (!url || !secret) {
  console.error("Set CONVEX_URL and MIGRATION_SECRET env vars.");
  process.exit(1);
}
const wipe = process.argv.includes("--wipe");

const data = {};
let total = 0;
for (const file of readdirSync(dataDir)) {
  if (!file.endsWith(".jsonl")) continue;
  const table = file.replace(/\.jsonl$/, "");
  const rows = readFileSync(join(dataDir, file), "utf8")
    .split("\n")
    .filter((l) => l.trim())
    .map((l) => JSON.parse(l));
  data[table] = rows;
  total += rows.length;
  console.log(`  loaded ${rows.length.toString().padStart(4)}  ${table}`);
}
console.log(`Total ${total} records. Calling importAll (wipe=${wipe})...`);

const client = new ConvexHttpClient(url);
// api.migrate.importAll referenced by string path so we don't need codegen here.
const res = await client.mutation("migrate:importAll", { secret, data, wipe });
console.log("Done:", JSON.stringify(res, null, 2));
