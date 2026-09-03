// Does an AUTHENTICATED websocket stay connected from a JS client?
// 1) sign up a throwaway account via auth:signIn → get a JWT
// 2) set it on a ConvexClient, subscribe to users:me, watch WS stability ~12s
// 3) delete the throwaway account
// If this flaps like iOS → the JWT is being rejected on the WS (server auth config).
// If it stays connected → the flap is convex-swift-specific.
import { ConvexClient, ConvexHttpClient } from "convex/browser";
import { api } from "../convex/_generated/api.js";

const url = "https://nestzone-convex-api.walhallaa.com";
const email = "wstest@example.com";
const password = "wstest-password-123";

const http = new ConvexHttpClient(url);
console.log("signing up throwaway", email);
const res = await http.action(api.auth.signIn, {
  provider: "password",
  params: { email, password, flow: "signUp" },
});
const token = res?.tokens?.token;
console.log("got token:", token ? "yes" : "NO", "| tokens obj keys:", Object.keys(res ?? {}));
if (!token) { console.log("no token, aborting:", JSON.stringify(res)); process.exit(1); }

const c = new ConvexClient(url);
c.setAuth(async () => token);
let updates = 0;
c.onUpdate(api.users.me, {}, (u) => { updates++; console.log("[users:me]", u ? u.email : "null"); });

const t0 = Date.now();
let changes = 0, last = null;
const iv = setInterval(() => {
  const s = c.client.connectionState().isWebSocketConnected;
  if (last !== null && s !== last) changes++;
  last = s;
  console.log(`t+${((Date.now()-t0)/1000).toFixed(0)}s  wsConnected=${s}`);
}, 1000);

setTimeout(async () => {
  clearInterval(iv);
  console.log(`\nWS state changes: ${changes} | users:me updates: ${updates}`);
  await c.close();
  // cleanup throwaway
  try {
    const del = await http.mutation(api.debug.deleteUserByEmail, { email });
    console.log("cleanup:", JSON.stringify(del));
  } catch (e) { console.log("cleanup error:", String(e)); }
  process.exit(0);
}, 12000);
