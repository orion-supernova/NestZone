"use node";

// The house jar takes real money: StoreKit 2 top-ups, verified on the server.
//
// A phone's word that it paid is not a payment. Every top-up arrives as the
// StoreKit 2 `jwsRepresentation` and is checked here with Apple's own library
// (`SignedDataVerifier`: the x5c chain to Apple Root CA - G3, OCSP on each
// certificate, the signature, the bundle id, the environment) before
// convex/jarStore.ts credits a jar. Node, because the library is built on
// Node's crypto and X509Certificate; this file therefore exports actions only.
//
// Refunds come the other way, from App Store Server Notifications V2, through
// `POST /appstore/notifications` (convex/http.ts) into `notification` below.
// Docs/Companion/HANDOFF.md, step 4.
//
// `invalid` is said only of data that is not Apple's or not ours to credit.
// Anything Apple really signed that we cannot settle right now — OCSP down,
// `APPLE_APP_ID` missing, a Production product the table doesn't know — is
// thrown, so the phone keeps the transaction and asks again: the house paid.

import { v, Infer } from "convex/values";
import {
  Environment,
  NotificationTypeV2,
  SignedDataVerifier,
  Type,
  VerificationException,
  VerificationStatus,
} from "@apple/app-store-server-library";
import { action, internalAction } from "./_generated/server";
import { internal } from "./_generated/api";
import {
  APPLE_ROOT_CA_G3,
  BUNDLE_ID,
  JarEnvironment,
  asJarEnvironment,
  jarEnvironments,
  sparklesFor,
  topUpResult,
} from "./lib/jar";

/** A StoreKit JWS is a few kilobytes. Anything far larger is not one. */
const MAX_JWS_LENGTH = 32_000;

const ROOTS = [Buffer.from(APPLE_ROOT_CA_G3, "base64")];

/**
 * `APPLE_APP_ID`: the app's numeric Apple ID from App Store Connect (App
 * Information -> Apple ID). Apple signs it into Production data and the
 * verifier refuses Production without it. Sandbox and Xcode data carry none.
 */
function appAppleId(): number | undefined {
  const raw = (process.env.APPLE_APP_ID ?? "").trim();
  if (!/^\d+$/.test(raw)) return undefined;
  return Number(raw);
}

// Verifiers per environment, app id and mode, kept for the life of the
// isolate: each caches the leaf keys it has walked to the root, so a burst of
// top-ups does not repeat the chain and OCSP work.
const verifiers = new Map<string, SignedDataVerifier>();

/**
 * `online` checks every certificate's revocation with Apple (OCSP) and its
 * dates against now; offline checks the same chain and signature as of the
 * JWS's own signing date, with no network. Null for Production without an app
 * id, which the verifier cannot be built without.
 */
function verifierFor(environment: JarEnvironment, online: boolean): SignedDataVerifier | null {
  const appId = environment === "Production" ? appAppleId() : undefined;
  if (environment === "Production" && appId === undefined) return null;
  const cacheKey = `${environment}:${appId ?? ""}:${online ? "online" : "offline"}`;
  let verifier = verifiers.get(cacheKey);
  if (!verifier) {
    const env =
      environment === "Production"
        ? Environment.PRODUCTION
        : environment === "Sandbox"
          ? Environment.SANDBOX
          : Environment.XCODE;
    verifier = new SignedDataVerifier(ROOTS, online, env, BUNDLE_ID, appId);
    verifiers.set(cacheKey, verifier);
  }
  return verifier;
}

type Checked<T> =
  /** Verified online: Apple's, and not revoked. */
  | { kind: "verified"; value: T }
  /** Failed online and offline: not Apple's, or not for this app or environment. */
  | { kind: "rejected"; status: VerificationStatus | null; error: unknown }
  /** Failed online but passes offline: Apple's, and we could not finish checking. */
  | { kind: "unconfirmed"; error: unknown };

/**
 * Online first; if that fails for any reason, offline. Only the offline
 * verdict can make something `rejected`, so an OCSP outage, a slow responder
 * or a certificate check that needs the network is never mistaken for a
 * forgery and answered as one.
 */
async function check<T>(
  environment: JarEnvironment,
  run: (verifier: SignedDataVerifier) => Promise<T>,
): Promise<Checked<T>> {
  const online = verifierFor(environment, true)!;
  const offline = verifierFor(environment, false)!;
  try {
    return { kind: "verified", value: await run(online) };
  } catch (onlineError) {
    try {
      await run(offline);
      return { kind: "unconfirmed", error: onlineError };
    } catch (offlineError) {
      const status = offlineError instanceof VerificationException ? offlineError.status : null;
      return { kind: "rejected", status, error: offlineError };
    }
  }
}

function describe(error: unknown): string {
  if (error instanceof VerificationException) return `${VerificationStatus[error.status]}${error.cause ? `: ${error.cause.message}` : ""}`;
  return error instanceof Error ? error.message : String(error);
}

/**
 * What a JWS says about itself, unverified. Only used to pick which verifier
 * to check it with — the verifier then refuses it if the claim is false — and
 * never trusted for anything else.
 */
function peekPayload(jws: string): Record<string, unknown> | null {
  const parts = jws.split(".");
  if (parts.length !== 3) return null;
  try {
    const decoded = JSON.parse(Buffer.from(parts[1], "base64url").toString("utf8"));
    return decoded && typeof decoded === "object" ? (decoded as Record<string, unknown>) : null;
  } catch {
    return null;
  }
}

/**
 * Puts a StoreKit 2 top-up into the house jar, once.
 *
 * - `signedTransaction` is `Transaction.jwsRepresentation` (or the
 *   `VerificationResult`'s), sent before `finish()`.
 * - `credited`: verified and in the jar now, `sparkles` of them. `already`:
 *   this transaction has been credited before — to this house, with the same
 *   `sparkles`; to another house, with 0 — and nothing moved. `revoked`: Apple
 *   refunded or revoked it, nothing moved now (a refund that arrives after the
 *   credit is debited by the notification). `invalid`: not a transaction this
 *   deployment credits for this caller — not Apple's, another app's, not a
 *   consumable, Sandbox while Sandbox is off, Xcode from an account that is
 *   not a test account, or bought by somebody else (`appAccountToken`).
 * - A thrown error is not an answer: not a member, or a real Apple
 *   transaction we could not settle yet (OCSP unreachable, `APPLE_APP_ID`
 *   unset, a Production product the table doesn't know). Keep it unfinished
 *   and send it again later.
 * - `jar` is the house's balances after the answer, or null when it has no
 *   jar yet or the answer is `invalid`.
 */
export const topUp = action({
  args: { homeId: v.id("homes"), signedTransaction: v.string() },
  returns: topUpResult,
  handler: async (ctx, args): Promise<Infer<typeof topUpResult>> => {
    const { mayTest } = await ctx.runQuery(internal.jarStore.caller, { homeId: args.homeId });
    const invalid = { status: "invalid" as const, sparkles: 0, jar: null };

    const jws = args.signedTransaction.trim();
    if (jws.length === 0 || jws.length > MAX_JWS_LENGTH) return invalid;
    const environment = asJarEnvironment(peekPayload(jws)?.environment);
    if (!environment || !jarEnvironments().has(environment)) return invalid;
    if (environment === "Xcode" && !mayTest) return invalid;
    if (environment === "Production" && appAppleId() === undefined) {
      console.error("jar:topUp: a Production transaction arrived and APPLE_APP_ID is not set");
      throw new Error("The App Store is not configured on the server yet; try again later");
    }

    const checked = await check(environment, (verifier) => verifier.verifyAndDecodeTransaction(jws));
    if (checked.kind === "rejected") {
      console.warn(`jar:topUp: a ${environment} transaction failed verification: ${describe(checked.error)}`);
      return invalid;
    }
    if (checked.kind === "unconfirmed") {
      console.error(`jar:topUp: a ${environment} transaction verifies offline but not online: ${describe(checked.error)}`);
      throw new Error("Apple could not be reached to verify this purchase; try again");
    }
    const transaction = checked.value;

    // The library has checked the bundle id and the environment; the rest is ours.
    if (transaction.bundleId !== BUNDLE_ID) return invalid;
    if (transaction.type !== Type.CONSUMABLE) return invalid;
    const { transactionId, productId, purchaseDate } = transaction;
    if (!transactionId || !productId || typeof purchaseDate !== "number") return invalid;
    const quantity = transaction.quantity ?? 1;
    if (sparklesFor(productId, quantity) === null) {
      if (environment === "Production") {
        console.error(`jar:topUp: Production ${transactionId} is for ${productId} x${quantity}, which the table doesn't know`);
        throw new Error("This pack is not on the server yet; try again later");
      }
      return invalid;
    }

    return await ctx.runMutation(internal.jarStore.credit, {
      homeId: args.homeId,
      transactionId,
      originalTransactionId: transaction.originalTransactionId ?? transactionId,
      productId,
      quantity,
      environment,
      purchasedAt: purchaseDate,
      revokedAt: typeof transaction.revocationDate === "number" ? transaction.revocationDate : null,
      appAccountToken: transaction.appAccountToken ?? null,
    });
  },
});

/** Genuinely Apple's, but addressed to another app or environment: our configuration, not a forgery. */
function isMisaddressed(status: VerificationStatus | null): boolean {
  return status === VerificationStatus.INVALID_APP_IDENTIFIER || status === VerificationStatus.INVALID_ENVIRONMENT;
}

/**
 * One App Store Server Notification V2, from `POST /appstore/notifications`.
 *
 * The answer is the HTTP status the route sends. Apple retries anything but a
 * 200 for a few days, so:
 * - 200 for everything handled or deliberately ignored (a TEST, a type we
 *   don't act on, a transaction that isn't a pack);
 * - 400 for a payload that is not Apple's (retrying won't make it so);
 * - 500 when trying again could work or someone has to look: Apple
 *   unreachable for OCSP, Production arriving before `APPLE_APP_ID` is set, or
 *   a genuine payload for another app id or environment — which means this
 *   deployment's configuration is wrong, and a refund would be lost if we said
 *   200.
 *
 * Sandbox and Production are both verified here whatever `JAR_ENVIRONMENTS`
 * says: that list says what may be credited from now on, and a refund of a
 * Sandbox top-up credited while Sandbox was on must still come back out.
 */
export const notification = internalAction({
  args: { signedPayload: v.string() },
  returns: v.union(v.literal(200), v.literal(400), v.literal(500)),
  handler: async (ctx, args): Promise<200 | 400 | 500> => {
    const payload = args.signedPayload.trim();
    if (payload.length === 0 || payload.length > MAX_JWS_LENGTH * 4) return 400;
    const data = peekPayload(payload)?.data as Record<string, unknown> | undefined;
    const environment = asJarEnvironment(data?.environment);
    if (environment !== "Production" && environment !== "Sandbox") {
      console.warn(`appstore/notifications: a payload for environment ${String(data?.environment)}; ignored`);
      return 200;
    }
    if (environment === "Production" && appAppleId() === undefined) {
      console.error("appstore/notifications: a Production notification arrived and APPLE_APP_ID is not set");
      return 500;
    }

    const notice = await check(environment, (verifier) => verifier.verifyAndDecodeNotification(payload));
    if (notice.kind !== "verified") return failure("notification", environment, notice);
    const type = notice.value.notificationType;
    const subtype = notice.value.subtype ? `/${notice.value.subtype}` : "";
    // Every verified notification is logged before anything decides to ignore
    // it, so "did Apple's test arrive" and "what did we skip" are both in the logs.
    console.log(`appstore/notifications: ${type}${subtype} (${environment}) ${notice.value.notificationUUID ?? ""}`);
    if (type !== NotificationTypeV2.REFUND && type !== NotificationTypeV2.REVOKE) return 200;
    const signedTransaction = notice.value.data?.signedTransactionInfo;
    if (!signedTransaction) return 200;

    const checked = await check(environment, (verifier) => verifier.verifyAndDecodeTransaction(signedTransaction));
    if (checked.kind !== "verified") return failure("transaction", environment, checked);
    const transaction = checked.value;
    const { transactionId, productId } = transaction;
    if (!transactionId || !productId) return 200;

    // A failed write throws, so the route answers 500 and Apple sends the
    // refund again, rather than a 400 that would drop it.
    const outcome = await ctx.runMutation(internal.jarStore.refund, {
      transactionId,
      originalTransactionId: transaction.originalTransactionId ?? transactionId,
      productId,
      quantity: transaction.quantity ?? 1,
      environment,
      purchasedAt: typeof transaction.purchaseDate === "number" ? transaction.purchaseDate : Date.now(),
      revokedAt:
        typeof transaction.revocationDate === "number"
          ? transaction.revocationDate
          : (notice.value.signedDate ?? Date.now()),
    });
    console.log(`appstore/notifications: ${type} ${environment} ${transactionId}: ${outcome}`);
    return 200;
  },
});

function failure(
  what: string,
  environment: JarEnvironment,
  checked: Exclude<Checked<unknown>, { kind: "verified" }>,
): 400 | 500 {
  if (checked.kind === "unconfirmed") {
    console.error(`appstore/notifications: a ${environment} ${what} verifies offline but not online: ${describe(checked.error)}`);
    return 500;
  }
  if (isMisaddressed(checked.status)) {
    console.error(
      `appstore/notifications: a genuine ${environment} ${what} for another app or environment (${describe(checked.error)}); check BUNDLE_ID and APPLE_APP_ID`,
    );
    return 500;
  }
  console.warn(`appstore/notifications: a ${environment} ${what} failed verification: ${describe(checked.error)}`);
  return 400;
}
