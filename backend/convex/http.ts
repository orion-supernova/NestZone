import { httpRouter } from "convex/server";
import { httpAction } from "./_generated/server";
import { internal } from "./_generated/api";
import { auth } from "./auth";
import { TOKEN_RE, inviteUrl } from "./lib/invites";

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

// House invites (invites.ts). Both routes live under `/.well-known/` because
// that is the only path the tunnel forwards to the HTTP-actions origin
// (:3211) on nestzone-convex-api.walhallaa.com — the same host the invite
// links name, so the app's associated domain and the link agree.

/** The App Store id, for the store link and the Smart App Banner. */
const APP_STORE_ID = "6749852085";
const BUNDLE_ID = "com.walhallaa.NestZone";
const JOIN_PREFIX = "/.well-known/join/";

/**
 * Universal links: the app opens `/.well-known/join/*` itself when it is
 * installed. Served directly with a 200 (Apple follows no redirect here).
 * The team id is `APNS_TEAM_ID`, already set for push; without it there is
 * no app to name, and the file is a 404 rather than a wrong one.
 */
http.route({
  path: "/.well-known/apple-app-site-association",
  method: "GET",
  handler: httpAction(async () => {
    const team = process.env.APNS_TEAM_ID?.trim();
    if (!team) return new Response("Not found", { status: 404 });
    const body = {
      applinks: {
        details: [
          {
            appIDs: [`${team}.${BUNDLE_ID}`],
            components: [{ "/": `${JOIN_PREFIX}*` }],
          },
        ],
      },
    };
    return new Response(JSON.stringify(body), {
      status: 200,
      headers: {
        "Content-Type": "application/json",
        "Cache-Control": "public, max-age=3600",
      },
    });
  }),
});

function escapeHtml(text: string): string {
  return text
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

/**
 * The page an invite link shows where the app is not installed (or the link
 * was opened somewhere that does not hand it to the app). No database read
 * and no house name: nobody is signed in here, and the token is checked by
 * `invites:preview` inside the app.
 */
function invitePage(token: string | null): string {
  const appStore = `https://apps.apple.com/app/id${APP_STORE_ID}`;
  const link = token ? escapeHtml(inviteUrl(token)) : null;
  const open = token ? escapeHtml(`nestzone://join/${token}`) : null;
  const banner = link
    ? `<meta name="apple-itunes-app" content="app-id=${APP_STORE_ID}, app-argument=${link}">`
    : `<meta name="apple-itunes-app" content="app-id=${APP_STORE_ID}">`;
  const title = token ? "You're invited to a home on NestZone" : "This invite link doesn't work";
  const lead = token
    ? "Someone wants you in their home on NestZone: chores, shopping, plans and the rest, shared."
    : "Check the link, or ask for a new one from someone in the home.";
  const openButton = open
    ? `<a class="button primary" href="${open}">Open in NestZone</a>`
    : "";
  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<meta name="robots" content="noindex">
<meta name="color-scheme" content="light dark">
${banner}
<title>NestZone invite</title>
<style>
:root{--bg:#f6f4f0;--card:#ffffff;--text:#1c1b1a;--muted:#5f5b55;--accent:#3a6df0;--on-accent:#ffffff;--line:#d9d4cc}
@media (prefers-color-scheme: dark){:root{--bg:#121212;--card:#1e1e1f;--text:#f2f0ec;--muted:#b3aea6;--accent:#6f95ff;--on-accent:#0b1020;--line:#3a3836}}
*{box-sizing:border-box}
body{margin:0;min-height:100vh;display:flex;align-items:center;justify-content:center;padding:24px 16px;background:var(--bg);color:var(--text);font:17px/1.45 -apple-system,BlinkMacSystemFont,"SF Pro Text","Helvetica Neue",Arial,sans-serif}
main{width:100%;max-width:420px;background:var(--card);border:1px solid var(--line);border-radius:24px;padding:32px 24px;text-align:center}
.mark{width:64px;height:64px;margin:0 auto 20px;border-radius:18px;background:var(--accent);display:flex;align-items:center;justify-content:center}
.mark svg{width:34px;height:34px}
h1{font-size:24px;line-height:1.25;margin:0 0 12px;font-weight:700}
p{margin:0 0 28px;color:var(--muted)}
.button{display:block;width:100%;padding:15px 18px;border-radius:14px;text-decoration:none;font-weight:600;margin-top:12px}
.primary{background:var(--accent);color:var(--on-accent)}
.secondary{border:1px solid var(--line);color:var(--text)}
small{display:block;margin-top:20px;color:var(--muted);font-size:14px}
</style>
</head>
<body>
<main>
<div class="mark" aria-hidden="true"><svg viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 11.5 12 4l9 7.5"/><path d="M5.5 10v9.5h13V10"/><path d="M10 19.5v-5h4v5"/></svg></div>
<h1>${title}</h1>
<p>${lead}</p>
${openButton}
<a class="button ${openButton ? "secondary" : "primary"}" href="${appStore}">Get NestZone on the App Store</a>
${token ? "<small>Already have the app? Tap Open in NestZone.</small>" : ""}
</main>
</body>
</html>`;
}

http.route({
  pathPrefix: JOIN_PREFIX,
  method: "GET",
  handler: httpAction(async (_ctx, request) => {
    const rest = new URL(request.url).pathname.slice(JOIN_PREFIX.length);
    let token: string | null = null;
    try {
      token = decodeURIComponent(rest).replace(/\/+$/, "");
    } catch {
      token = null;
    }
    const valid = token !== null && TOKEN_RE.test(token);
    return new Response(invitePage(valid ? token : null), {
      status: valid ? 200 : 404,
      headers: {
        "Content-Type": "text/html; charset=utf-8",
        "Cache-Control": "no-store",
        "Referrer-Policy": "no-referrer",
        "X-Content-Type-Options": "nosniff",
        "Content-Security-Policy": "default-src 'none'; style-src 'unsafe-inline'; img-src data:",
      },
    });
  }),
});

export default http;
