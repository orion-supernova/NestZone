import { httpRouter } from "convex/server";
import { httpAction } from "./_generated/server";
import { internal } from "./_generated/api";
import { auth } from "./auth";

const http = httpRouter();
auth.addHttpRoutes(http);

/**
 * App Store Server Notifications V2: refunds and revocations of Sparkle
 * top-ups (convex/jar.ts, `notification`). Set as the Production and Sandbox
 * server URL in App Store Connect.
 *
 * Unauthenticated by nature — Apple calls it — so nothing here is trusted
 * until the signed payload has been verified to Apple's root. Every answer is
 * a status code only, and anything that is not a refund of a known pack is a
 * 200, so Apple never retries what we chose to ignore.
 *
 * Reachable only once the tunnel sends `/appstore/*` to the HTTP-actions
 * origin (:3211), as it does `/.well-known/*`
 * (Docs/Convex-Migration/Backend-Deploy-Runbook.md, the tunnel section).
 */
http.route({
  path: "/appstore/notifications",
  method: "POST",
  handler: httpAction(async (ctx, request) => {
    const body = await request.text();
    // A notification is one signed payload of a few kilobytes.
    if (body.length > 256_000) return new Response(null, { status: 400 });
    let signedPayload: unknown;
    try {
      signedPayload = (JSON.parse(body) as { signedPayload?: unknown }).signedPayload;
    } catch {
      return new Response(null, { status: 400 });
    }
    if (typeof signedPayload !== "string") return new Response(null, { status: 400 });
    const status = await ctx.runAction(internal.jar.notification, { signedPayload });
    return new Response(null, { status });
  }),
});

export default http;
