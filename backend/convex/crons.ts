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

// House problems keep the bills' clock, not the calendar's.
//
// Nothing here happens at a time. A repair is overdue by *days* and a problem
// has been ignored for *days*, so a daily pass is as exact as the data — and an
// hourly one would only mean the same household hearing about the same leak
// twenty-four times in the window where it is still true. An hour after the
// bills, so a morning cannot open with two notifications at once.
//
// Idempotent in the same way both sweeps above are: each nudge is recorded
// against the thing that caused it — `<due_by>:overdue`, `<last_activity>:stale`
// — before it goes out, and any activity at all retires the stale key. See
// `sweepStale` in convex/issues.ts.
crons.daily(
  "house problem nudges",
  { hourUTC: 9, minuteUTC: 0 },
  internal.issues.sweepStale,
);

export default crons;
