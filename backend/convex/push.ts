// Apple Push Notification service, spoken directly.
//
// No third-party SDK: APNs is an HTTP/2 JSON API with a signed JWT for auth, and
// `jose` (already here for Apple sign-in) does the signing. Convex's default
// runtime negotiates HTTP/2, which is the only reason this can live in a normal
// action — APNs has no HTTP/1.1 endpoint, so an HTTP/1.1-only fetch would fail
// at the protocol level rather than with a useful error.
//
// Configure the deployment once:
//   npx convex env set APNS_KEY_ID      <10-char key id from the .p8 filename>
//   npx convex env set APNS_TEAM_ID     <10-char Apple Developer team id>
//   npx convex env set APNS_BUNDLE_ID   com.walhallaa.NestZone
//   npx convex env set APNS_KEY_P8    "$(cat AuthKey_XXXXXXXXXX.p8)"
//
// The .p8 is an ES256 (P-256) key. Apple issues it once and never again, so
// keep it out of the repo — it lives only in the deployment environment.

import { v } from "convex/values";
import { SignJWT, importPKCS8 } from "jose";
import {
  action,
  internalAction,
  internalMutation,
  internalQuery,
  mutation,
} from "./_generated/server";
import { internal } from "./_generated/api";
import { Doc, Id } from "./_generated/dataModel";
import { requireUser, requireHomeMember } from "./lib/auth";

/// Apple rejects a provider that mints tokens more often than once per 20
/// minutes, and accepts one for up to an hour. Refreshing at 40 keeps us clear
/// of both edges.
const TOKEN_TTL_MS = 40 * 60 * 1000;

const environment = v.union(v.literal("sandbox"), v.literal("production"));

function gateway(env: "sandbox" | "production"): string {
  return env === "production"
    ? "https://api.push.apple.com"
    : "https://api.sandbox.push.apple.com";
}

function requireEnv(name: string): string {
  const value = process.env[name];
  if (!value) {
    throw new Error(
      `${name} is not set on this deployment. See the header of convex/push.ts.`,
    );
  }
  return value;
}

/// Whether this deployment has APNs credentials at all.
///
/// Until the keys are set, every note and shopping item would otherwise throw
/// inside its scheduled push — one logged error per write, for a feature that is
/// simply not configured yet. Sending is skipped quietly instead.
function isConfigured(): boolean {
  return Boolean(
    process.env.APNS_KEY_ID &&
      process.env.APNS_TEAM_ID &&
      process.env.APNS_BUNDLE_ID &&
      process.env.APNS_KEY_P8,
  );
}

// MARK: - Device registration

/**
 * Records this device's APNs token against the signed-in user.
 *
 * Keyed on the token, not the user: a device handed to someone else must move
 * with them rather than keep receiving the previous owner's notifications.
 */
export const registerDevice = mutation({
  args: { token: v.string(), environment },
  handler: async (ctx, { token, environment }) => {
    const user = await requireUser(ctx);
    const now = Date.now();

    const existing = await ctx.db
      .query("push_tokens")
      .withIndex("by_token", (q) => q.eq("token", token))
      .unique();

    if (existing) {
      await ctx.db.patch(existing._id, {
        user_id: user._id,
        environment,
        updated: now,
      });
      return;
    }

    await ctx.db.insert("push_tokens", {
      user_id: user._id,
      token,
      environment,
      created: now,
      updated: now,
    });
  },
});

/** Called on sign-out so a shared device stops receiving the old user's pushes. */
export const unregisterDevice = mutation({
  args: { token: v.string() },
  handler: async (ctx, { token }) => {
    await requireUser(ctx);
    const existing = await ctx.db
      .query("push_tokens")
      .withIndex("by_token", (q) => q.eq("token", token))
      .unique();
    if (existing) await ctx.db.delete(existing._id);
  },
});

// MARK: - Internals used by the sender

export const tokensForHome = internalQuery({
  args: { homeId: v.id("homes"), exclude: v.optional(v.id("users")) },
  handler: async (ctx, { homeId, exclude }) => {
    const home = await ctx.db.get(homeId);
    if (!home) return [];
    const recipients = (home.members ?? []).filter((m) => m !== exclude);

    const rows: Doc<"push_tokens">[] = [];
    for (const userId of recipients) {
      const forUser = await ctx.db
        .query("push_tokens")
        .withIndex("by_user", (q) => q.eq("user_id", userId))
        .collect();
      rows.push(...forUser);
    }
    return rows.map((r) => ({
      id: r._id,
      token: r.token,
      environment: r.environment,
    }));
  },
});

/** APNs told us a token is dead; stop sending to it. */
export const dropToken = internalMutation({
  args: { id: v.id("push_tokens") },
  handler: async (ctx, { id }) => {
    await ctx.db.delete(id);
  },
});

export const cachedJWT = internalQuery({
  args: {},
  handler: async (ctx) => {
    const row = await ctx.db.query("apns_credentials").first();
    if (!row) return null;
    if (Date.now() - row.issued > TOKEN_TTL_MS) return null;
    return row.jwt;
  },
});

export const storeJWT = internalMutation({
  args: { jwt: v.string() },
  handler: async (ctx, { jwt }) => {
    const existing = await ctx.db.query("apns_credentials").first();
    const now = Date.now();
    if (existing) {
      await ctx.db.patch(existing._id, { jwt, issued: now });
      return;
    }
    await ctx.db.insert("apns_credentials", { jwt, issued: now });
  },
});

// MARK: - Sending

type Device = {
  id: Id<"push_tokens">;
  token: string;
  environment: "sandbox" | "production";
};

async function providerToken(ctx: {
  runQuery: (ref: any, args: any) => Promise<any>;
  runMutation: (ref: any, args: any) => Promise<any>;
}): Promise<string> {
  const cached: string | null = await ctx.runQuery(internal.push.cachedJWT, {});
  if (cached) return cached;

  const key = await importPKCS8(requireEnv("APNS_KEY_P8"), "ES256");
  const jwt = await new SignJWT({})
    .setProtectedHeader({ alg: "ES256", kid: requireEnv("APNS_KEY_ID") })
    .setIssuer(requireEnv("APNS_TEAM_ID"))
    .setIssuedAt()
    .sign(key);

  await ctx.runMutation(internal.push.storeJWT, { jwt });
  return jwt;
}

type Alert = {
  title: string;
  body: string;
  /// Routes the tap. The app reads this to open the right tab.
  category?: string;
  /// Groups related alerts on the lock screen. Defaults to the home, so a
  /// household's activity stacks together.
  threadId?: string;
  /// Set only to deliberately REPLACE an earlier notification.
  collapseId?: string;
};

/// The shape every notifying action takes, so a caller writes the same thing
/// whether it is addressing a home or a handful of people.
const alertArgs = {
  title: v.string(),
  body: v.string(),
  category: v.optional(v.string()),
  threadId: v.optional(v.string()),
  collapseId: v.optional(v.string()),
};

/**
 * Posts one alert to one device.
 *
 * Per-device because APNs has no multi-device endpoint, and per-device errors
 * because one dead token must not stop the rest of the household hearing about
 * it.
 */
async function deliver(
  ctx: { runMutation: (ref: any, args: any) => Promise<any> },
  device: Device,
  jwt: string,
  topic: string,
  body: unknown,
  extraHeaders: Record<string, string>,
): Promise<"sent" | "dropped" | "failed"> {
  try {
    const response = await fetch(
      `${gateway(device.environment)}/3/device/${device.token}`,
      {
        method: "POST",
        headers: {
          authorization: `bearer ${jwt}`,
          "apns-topic": topic,
          "apns-push-type": "alert",
          "apns-priority": "10",
          ...extraHeaders,
        },
        body: JSON.stringify(body),
      },
    );

    if (response.status === 200) return "sent";

    const text = await response.text();
    // 410 Unregistered / 400 BadDeviceToken mean the device is gone for good.
    // Anything else is transient and worth keeping the token for.
    if (
      response.status === 410 ||
      (response.status === 400 && text.includes("BadDeviceToken"))
    ) {
      await ctx.runMutation(internal.push.dropToken, { id: device.id });
      return "dropped";
    }
    console.error(`APNs ${response.status} for device: ${text}`);
    return "failed";
  } catch (error) {
    console.error(`APNs request failed: ${String(error)}`);
    return "failed";
  }
}

/** Sends one alert to a list of devices, in parallel. */
async function fanOut(
  ctx: {
    runQuery: (ref: any, args: any) => Promise<any>;
    runMutation: (ref: any, args: any) => Promise<any>;
  },
  devices: Device[],
  alert: Alert,
): Promise<{ sent: number; dropped: number }> {
  if (devices.length === 0) return { sent: 0, dropped: 0 };

  const jwt = await providerToken(ctx);
  const topic = requireEnv("APNS_BUNDLE_ID");

  const payload = {
    aps: {
      alert: { title: alert.title, body: alert.body },
      sound: "default",
      ...(alert.threadId ? { "thread-id": alert.threadId } : {}),
    },
    category: alert.category ?? "activity",
  };

  // A collapse id REPLACES whatever is already showing under the same id, so
  // only a caller that genuinely means to supersede an earlier alert may set
  // one. This used to be the category on every send, which meant the evening's
  // second shopping item silently erased the first and the household saw one
  // notification no matter how many things were added.
  const headers: Record<string, string> = alert.collapseId
    ? { "apns-collapse-id": alert.collapseId.slice(0, 64) }
    : {};

  const results = await Promise.all(
    devices.map((device) => deliver(ctx, device, jwt, topic, payload, headers)),
  );

  return {
    sent: results.filter((r) => r === "sent").length,
    dropped: results.filter((r) => r === "dropped").length,
  };
}

/**
 * Fans a notification out to every device in a home except the one that caused
 * it.
 */
export const notifyHome = internalAction({
  args: {
    homeId: v.id("homes"),
    actor: v.optional(v.id("users")),
    ...alertArgs,
  },
  handler: async (ctx, args) => {
    if (!isConfigured()) return { sent: 0, dropped: 0 };

    const devices: Device[] = await ctx.runQuery(internal.push.tokensForHome, {
      homeId: args.homeId,
      exclude: args.actor,
    });
    return await fanOut(ctx, devices, {
      ...args,
      threadId: args.threadId ?? args.homeId,
    });
  },
});

/**
 * Fans out to a named set of people rather than to a whole home.
 *
 * Conversations are the case that needs it: the participants are a subset of
 * the household, and notifying everyone would tell the rest that the chat
 * exists.
 */
export const notifyUsers = internalAction({
  args: {
    userIds: v.array(v.id("users")),
    actor: v.optional(v.id("users")),
    ...alertArgs,
  },
  handler: async (ctx, args) => {
    if (!isConfigured()) return { sent: 0, dropped: 0 };

    const recipients = args.userIds.filter((id) => id !== args.actor);
    const devices: Device[] = [];
    for (const userId of recipients) {
      const forUser: Device[] = await ctx.runQuery(internal.push.tokensForUser, {
        userId,
      });
      devices.push(...forUser);
    }
    return await fanOut(ctx, devices, args);
  },
});

/**
 * Sends a notification to the caller's own devices.
 *
 * Used to verify the whole chain end to end after configuring the keys, without
 * bothering anyone else in the home.
 */
export const sendTestToSelf = action({
  args: {},
  handler: async (ctx): Promise<{ sent: number; dropped: number }> => {
    const userId: Id<"users"> | null = await ctx.runQuery(
      internal.push.currentUserId,
      {},
    );
    if (!userId) throw new Error("Not authenticated");
    if (!isConfigured()) {
      throw new Error(
        "APNs is not configured on this deployment. Set APNS_KEY_ID, " +
          "APNS_TEAM_ID, APNS_BUNDLE_ID and APNS_KEY_P8.",
      );
    }
    return await ctx.runAction(internal.push.notifyToUser, {
      userId,
      title: "NestZone",
      body: "Push notifications are working.",
    });
  },
});

export const currentUserId = internalQuery({
  args: {},
  handler: async (ctx) => {
    const user = await requireUser(ctx);
    return user._id;
  },
});

export const tokensForUser = internalQuery({
  args: { userId: v.id("users") },
  handler: async (ctx, { userId }) => {
    const rows = await ctx.db
      .query("push_tokens")
      .withIndex("by_user", (q) => q.eq("user_id", userId))
      .collect();
    return rows.map((r) => ({
      id: r._id,
      token: r.token,
      environment: r.environment,
    }));
  },
});

export const notifyToUser = internalAction({
  args: { userId: v.id("users"), title: v.string(), body: v.string() },
  handler: async (ctx, args) => {
    const devices: Device[] = await ctx.runQuery(internal.push.tokensForUser, {
      userId: args.userId,
    });
    return await fanOut(ctx, devices, { title: args.title, body: args.body, category: "test" });
  },
});
