// The house jar's money: what a top-up is worth, and which App Store
// environments may put Sparkles in it.
//
// Pure rules, in the default runtime, so the internal mutations that credit
// and debit (convex/jarStore.ts) and the Node action that verifies Apple's
// signature (convex/jar.ts) read the same answers. Docs/Companion/HANDOFF.md,
// step 4, is the design.

import { v } from "convex/values";
import { Doc } from "../_generated/dataModel";
import { CATALOG } from "./companionData";
import { isAdminUser } from "./admin";

const coinsValue = v.object({ leaves: v.number(), sparkles: v.number() });

/** `jar:topUp`'s answer. The client is built against it; widen only. */
export const topUpResult = v.object({
  status: v.union(v.literal("credited"), v.literal("already"), v.literal("invalid"), v.literal("revoked")),
  sparkles: v.number(),
  jar: v.union(coinsValue, v.null()),
});

export const environmentValue = v.union(v.literal("Production"), v.literal("Sandbox"), v.literal("Xcode"));

/** The only app whose transactions credit a jar. Apple signs it into every JWS. */
export const BUNDLE_ID = "com.walhallaa.NestZone";

/**
 * productId -> Sparkles, the one table.
 *
 * Read from the catalog the app's own Swift exports (`SparklePack.shelf`, via
 * tools/catalog_export), so the pack the store sheet sold and the Sparkles the
 * server credits are the same number by construction. A productId not in it
 * credits nothing: a pack App Store Connect sells but no build knows about is a
 * configuration error, not a reason to guess.
 */
export const PACK_SPARKLES: ReadonlyMap<string, number> = new Map(
  CATALOG.sparklePacks.map((pack) => [pack.id, pack.sparkles]),
);

/**
 * How many of one pack a single transaction may carry. StoreKit can sell a
 * consumable in a quantity; the app buys one at a time, and a cap keeps a
 * malformed quantity from becoming an arbitrary number of Sparkles.
 */
export const MAX_QUANTITY = 10;

/** The Sparkles a verified transaction is worth, or null when it is worth nothing we sell. */
export function sparklesFor(productId: string, quantity: number | undefined): number | null {
  const each = PACK_SPARKLES.get(productId);
  if (each === undefined) return null;
  const count = quantity ?? 1;
  if (!Number.isInteger(count) || count < 1 || count > MAX_QUANTITY) return null;
  return each * count;
}

export type JarEnvironment = "Production" | "Sandbox" | "Xcode";

const KNOWN: readonly JarEnvironment[] = ["Production", "Sandbox", "Xcode"];

/**
 * The environments whose transactions this deployment credits.
 *
 *   npx convex env set JAR_ENVIRONMENTS "Production,Sandbox"
 *
 * Production is always in, whatever the variable says: an App Store purchase
 * is real money, and a typo here must not turn every buyer away. Sandbox is
 * Apple-signed but free to the buyer, so on this one deployment — which every
 * household uses — it mints Sparkles for anyone with a sandbox account. It is
 * on for a TestFlight round and **while a build is in App Review** (the
 * reviewer buys in Sandbox, and an `invalid` answer means their purchase never
 * delivers), and off after. `Xcode` is a locally signed chain nobody can
 * verify; it is accepted only for test accounts (`mayUseTestStore`) and exists
 * for development. `LocalTesting` is never accepted. A name it does not know is
 * logged and skipped.
 */
export function jarEnvironments(): Set<JarEnvironment> {
  const out = new Set<JarEnvironment>(["Production"]);
  for (const part of (process.env.JAR_ENVIRONMENTS ?? "").split(/[\s,]+/)) {
    const name = part.trim();
    if (!name) continue;
    const match = KNOWN.find((env) => env.toLowerCase() === name.toLowerCase());
    if (match) out.add(match);
    else console.error(`JAR_ENVIRONMENTS names an environment this server does not know: ${name}`);
  }
  return out;
}

/** A JWS's own claim about its environment, narrowed to the ones we know. */
export function asJarEnvironment(value: unknown): JarEnvironment | null {
  return KNOWN.find((env) => env === value) ?? null;
}

/**
 * Who may credit a jar from an Xcode StoreKit-testing transaction: the admins
 * (lib/admin.ts) and the ids in `JAR_TEST_USER_IDS`.
 *
 *   npx convex env set JAR_TEST_USER_IDS "jh7abc...,jh7def..."
 *
 * An Xcode transaction is signed by the developer's own Mac, so it proves
 * nothing: anybody on this list can mint Sparkles into a house they belong to.
 * That is the point — it is how a Debug build exercises the real top-up path —
 * and why the list is short and `Xcode` is off unless `JAR_ENVIRONMENTS` names
 * it.
 */
export function mayUseTestStore(user: Doc<"users">): boolean {
  if (isAdminUser(user)) return true;
  const listed = (process.env.JAR_TEST_USER_IDS ?? "").split(/[\s,]+/).filter(Boolean);
  return listed.includes(user._id);
}

/**
 * The `appAccountToken` the app signs into every purchase it makes for this
 * user (`SparkleAccount.token`, NestZone/Features/Companion/SparkleSettlement.swift),
 * byte for byte: SHA-256 of `nestzone.user:<users._id>` as UTF-8, the first 16
 * bytes, the version nibble set to 5 and the variant to RFC 4122, written as a
 * lowercase UUID. A purchase whose token is not the caller's was bought by
 * somebody else, and only that somebody may put it in a jar.
 *
 * Test vector, computed with the Swift (CryptoKit) and checked here with Node
 * on 24 October 2026; both sides must keep producing it:
 *   "jh7abc123def456ghi789jkl0mn1pq2r" -> "d04f2213-14a2-506a-8069-fc02089326a9"
 */
export async function accountToken(userId: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(`nestzone.user:${userId}`));
  const bytes = new Uint8Array(digest).slice(0, 16);
  bytes[6] = (bytes[6] & 0x0f) | 0x50;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  const hex = Array.from(bytes, (b) => b.toString(16).padStart(2, "0")).join("");
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`;
}

export const ACCOUNT_TOKEN_VECTOR = {
  userId: "jh7abc123def456ghi789jkl0mn1pq2r",
  token: "d04f2213-14a2-506a-8069-fc02089326a9",
} as const;

/**
 * The ledger key for a top-up or its refund.
 *
 * Production keeps the plain `topup:<transactionId>`. Other environments carry
 * their name, because Xcode numbers its transactions from 0 on every Mac and
 * a Sandbox id is not promised to stay out of Production's range.
 */
export function ledgerKey(kind: "topup" | "refund", environment: JarEnvironment, transactionId: string): string {
  return environment === "Production"
    ? `${kind}:${transactionId}`
    : `${kind}:${environment}:${transactionId}`;
}

/**
 * Apple Root CA - G3, DER, base64. Every App Store JWS chains to it.
 *
 * Pinned here rather than fetched: a root fetched at run time is only as
 * trustworthy as the fetch. From https://www.apple.com/certificateauthority/,
 * SHA-256 63:34:3A:BF:B8:9A:6A:03:EB:B5:7E:9B:3F:5F:A7:BE:7C:4F:5C:75:6F:30:
 * 17:B3:A8:C4:88:C3:65:3E:91:79, valid until 30 April 2039.
 */
export const APPLE_ROOT_CA_G3 =
  "MIICQzCCAcmgAwIBAgIILcX8iNLFS5UwCgYIKoZIzj0EAwMwZzEbMBkGA1UEAwwSQXBwbGUgUm9v" +
  "dCBDQSAtIEczMSYwJAYDVQQLDB1BcHBsZSBDZXJ0aWZpY2F0aW9uIEF1dGhvcml0eTETMBEGA1UE" +
  "CgwKQXBwbGUgSW5jLjELMAkGA1UEBhMCVVMwHhcNMTQwNDMwMTgxOTA2WhcNMzkwNDMwMTgxOTA2" +
  "WjBnMRswGQYDVQQDDBJBcHBsZSBSb290IENBIC0gRzMxJjAkBgNVBAsMHUFwcGxlIENlcnRpZmlj" +
  "YXRpb24gQXV0aG9yaXR5MRMwEQYDVQQKDApBcHBsZSBJbmMuMQswCQYDVQQGEwJVUzB2MBAGByqG" +
  "SM49AgEGBSuBBAAiA2IABJjpLz1AcqTtkyJygRMc3RCV8cWjTnHcFBbZDuWmBSp3ZHtfTjjTuxxE" +
  "tX/1H7YyYl3J6YRbTzBPEVoA/VhYDKX1DyxNB0cTddqXl5dvMVztK517IDvYuVTZXpmkOlEKMaNC" +
  "MEAwHQYDVR0OBBYEFLuw3qFYM4iapIqZ3r6966/ayySrMA8GA1UdEwEB/wQFMAMBAf8wDgYDVR0P" +
  "AQH/BAQDAgEGMAoGCCqGSM49BAMDA2gAMGUCMQCD6cHEFl4aXTQY2e3v9GwOAEZLuN+yRhHFD/3m" +
  "eoyhpmvOwgPUnPWTxnS4at+qIxUCMG1mihDK1A3UT82NQz60imOlM27jbdoXt2QfyFMm+YhidDkL" +
  "F1vLUagM6BgD56KyKA==";
