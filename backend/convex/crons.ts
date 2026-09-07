// Scheduled work.
//
// One job so far: the bill reminder sweep.
//
// Daily rather than hourly, and at a fixed UTC hour, because a `bills` row has
// no timezone on it — the household that owns it does, and the server does not
// know it. Whole days are the unit the reminders are expressed in ("two days
// before"), so the hour it lands at is the one thing that is genuinely
// approximate. 08:00 UTC puts it in the morning across Europe and the Middle
// East, which is where this household is.
//
// The sweep itself is idempotent (see `finance.sweepReminders`), so running it
// twice on a bad day costs nothing.

import { cronJobs } from "convex/server";
import { internal } from "./_generated/api";

const crons = cronJobs();

crons.daily(
  "bill reminders",
  { hourUTC: 8, minuteUTC: 0 },
  internal.finance.sweepReminders,
);

export default crons;
