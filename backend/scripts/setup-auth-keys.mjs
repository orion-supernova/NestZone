// One-shot: generate the RS256 keypair @convex-dev/auth needs and set JWT_PRIVATE_KEY
// + JWKS on the deployment. The self-hosted Convex backend was missing these, so token
// minting failed with "Missing environment variable JWT_PRIVATE_KEY".
//
// Run from the repo's backend/ folder. Credentials are read from backend/.env.local
// (CONVEX_SELF_HOSTED_URL + CONVEX_SELF_HOSTED_ADMIN_KEY), auto-loaded by the convex CLI:
//   cd backend && node scripts/setup-auth-keys.mjs
//
// Mirrors exactly what `npx @convex-dev/auth` does on Convex Cloud (RS256, extractable,
// PKCS#8 with newlines -> spaces, JWKS with use:"sig"). Safe to re-run (rotates keys;
// existing sessions will need to re-authenticate).

import { execFileSync } from "node:child_process";
import { generateKeyPair, exportPKCS8, exportJWK } from "jose";

const keys = await generateKeyPair("RS256", { extractable: true });
const privateKey = (await exportPKCS8(keys.privateKey)).trimEnd().replace(/\n/g, " ");
const publicKey = await exportJWK(keys.publicKey);
const jwks = JSON.stringify({ keys: [{ use: "sig", ...publicKey }] });

function setEnv(name, value) {
  // Use the local convex CLI; it reads creds from backend/.env.local.
  // The `--` is required: JWT_PRIVATE_KEY starts with "-----BEGIN", which the CLI
  // would otherwise parse as an option ("unknown option '-----BEGIN...'").
  execFileSync("npx", ["convex", "env", "set", "--", name, value], { stdio: "inherit" });
}

console.log("Setting JWT_PRIVATE_KEY ...");
setEnv("JWT_PRIVATE_KEY", privateKey);
console.log("Setting JWKS ...");
setEnv("JWKS", jwks);
console.log("\n✅ Auth signing keys configured. Try signing in again — no redeploy needed.");
