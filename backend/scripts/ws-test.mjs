// Isolation test: does the Convex realtime WebSocket stay connected from a *non-iOS*
// client? Subscribes to debug:ping and logs connection-state changes for ~15s.
// If this also flaps, the problem is server/Cloudflare side, not the iOS SDK.
import { ConvexClient } from "convex/browser";
import { api } from "../convex/_generated/api.js";

const url = process.env.CONVEX_SELF_HOSTED_URL || "https://nestzone-convex-api.walhallaa.com";
console.log("connecting to", url);
const client = new ConvexClient(url);

let updates = 0;
client.onUpdate(api.debug.ping, {}, (v) => { updates++; console.log(`[update #${updates}]`, JSON.stringify(v)); });

const started = Date.now();
const iv = setInterval(() => {
  const s = client.client.connectionState();
  console.log(`t+${((Date.now()-started)/1000).toFixed(1)}s  wsConnected=${s.isWebSocketConnected}  inflight=${s.inflightMutations ?? "?"}/${s.inflightActions ?? "?"}`);
}, 1000);

setTimeout(async () => {
  clearInterval(iv);
  console.log(`\nDONE. query updates received: ${updates}`);
  await client.close();
  process.exit(0);
}, 15000);
