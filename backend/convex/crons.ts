// Scheduled work.
//
// Two jobs: the bill reminder sweep and the event reminder sweep.
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

// Events keep a different clock.
//
// A bill is due on a *day*, so a daily sweep is as exact as the data. An event
// is at 18:30, and "half an hour before" has to land near half an hour before
// or it is not a reminder — so this runs on a quarter-hour and the offsets the
// UI offers stop at ten minutes. Anything finer would promise a precision the
// sweep cannot keep.
//
// Idempotent in the same way `finance.sweepReminders` is: each nudge is
// recorded against `<occurrence_start>:<minutesBefore>` before it goes out, so
// a rerun sends nothing twice.
crons.interval(
  "event reminders",
  { minutes: 15 },
  internal.events.sweepReminders,
);

export default crons;
