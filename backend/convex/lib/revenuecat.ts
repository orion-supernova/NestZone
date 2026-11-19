// RevenueCat's REST API (v1), spoken directly with the secret key.
//
// The RevenueCat app user id IS the Convex user id (`users._id`), set by the
// app at sign-in.
//
//   npx convex env set REVENUECAT_SECRET_KEY sk_...   (the v1 secret key)

const API = "https://api.revenuecat.com/v1/subscribers/";
const ENTITLEMENT = "pro";

export type Entitlement = {
  /** When access ends, ms. `null` is lifetime. Includes billing grace. */
  expiresAt: number | null;
  productId?: string;
  store?: string;
  isSandbox: boolean;
  willRenew: boolean;
};

export function revenueCatConfigured(): boolean {
  return Boolean(process.env.REVENUECAT_SECRET_KEY);
}

function secretKey(): string {
  const key = process.env.REVENUECAT_SECRET_KEY;
  if (!key) {
    throw new Error(
      "REVENUECAT_SECRET_KEY is not set on this deployment, so Pro cannot be checked. " +
        "See the header of convex/lib/revenuecat.ts.",
    );
  }
  return key;
}

function parseDate(value: unknown): number | null {
  if (typeof value !== "string") return null;
  const ms = Date.parse(value);
  return Number.isFinite(ms) ? ms : null;
}

/**
 * Asks RevenueCat about one person. `null`: no `pro` entitlement at all —
 * never had one, or it was transferred to another app user by a restore.
 *
 * An expired entitlement comes back with its past date rather than as null.
 * Billing grace counts as access: Apple keeps the subscriber's access through
 * it, and so does the house. Throws on any non-2xx answer, so an outage is
 * never written down as "not Pro".
 */
export async function fetchEntitlement(userId: string): Promise<Entitlement | null> {
  const response = await fetch(`${API}${encodeURIComponent(userId)}`, {
    headers: { Authorization: `Bearer ${secretKey()}`, Accept: "application/json" },
  });
  if (!response.ok) {
    throw new Error(`RevenueCat answered ${response.status} for a subscriber lookup`);
  }
  const body = (await response.json()) as { subscriber?: any };
  const subscriber = body.subscriber ?? {};
  const ent = subscriber.entitlements?.[ENTITLEMENT];
  if (!ent || typeof ent !== "object") return null;

  const productId: string | undefined =
    typeof ent.product_identifier === "string" ? ent.product_identifier : undefined;

  const lifetime = ent.expires_date === null || ent.expires_date === undefined;
  const expiresAt = lifetime
    ? null
    : Math.max(parseDate(ent.expires_date) ?? 0, parseDate(ent.grace_period_expires_date) ?? 0);

  const sub = productId ? subscriber.subscriptions?.[productId] : undefined;
  // A non-renewing (lifetime) purchase lives under `non_subscriptions`, as a
  // list of purchases of that product.
  const nonSubs: any[] | undefined =
    productId && Array.isArray(subscriber.non_subscriptions?.[productId])
      ? subscriber.non_subscriptions[productId]
      : undefined;
  const purchase = sub ?? nonSubs?.[nonSubs.length - 1];

  const store: string | undefined =
    typeof purchase?.store === "string" ? purchase.store : undefined;
  // No purchase record behind the entitlement is not proof of a real one:
  // counted as sandbox (so only while PRO_SANDBOX is on). A promotional grant
  // from RevenueCat's dashboard is ours, and always counts.
  const isSandbox = !purchase ? true : store === "promotional" ? false : purchase.is_sandbox === true;
  const willRenew = sub ? !sub.unsubscribe_detected_at && !sub.billing_issues_detected_at : false;

  return { expiresAt, productId, store, isSandbox, willRenew };
}

/**
 * Deletes a subscriber from RevenueCat (account deletion). Best effort:
 * returns whether RevenueCat confirmed it, never throws, logs failures.
 */
export async function deleteSubscriber(userId: string): Promise<boolean> {
  if (!revenueCatConfigured()) return false;
  try {
    const response = await fetch(`${API}${encodeURIComponent(userId)}`, {
      method: "DELETE",
      headers: { Authorization: `Bearer ${secretKey()}`, Accept: "application/json" },
    });
    // 404: RevenueCat never knew them, which is the same outcome.
    if (response.ok || response.status === 404) return true;
    console.error(`RevenueCat subscriber delete: ${response.status} ${await response.text()}`);
    return false;
  } catch (error) {
    console.error(`RevenueCat subscriber delete failed: ${String(error)}`);
    return false;
  }
}
