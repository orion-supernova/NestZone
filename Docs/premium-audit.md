# Premium tiering — audit and plan

Status: **analysis only.** Nothing in this document is implemented. Written
2026-09-10, against `refactor/tca-liquid-glass`.

The question this answers: if some features go behind a subscription, what
breaks, and what has to exist first so that deciding *which* features is a
one-line change rather than a refactor.

## 1. Where the codebase actually stands

Three findings that constrain every option below.

**There is no entitlement scaffolding at all.** No StoreKit, no server-side plan
state, no gating anywhere. Clean slate — which is good, because the wrong
primitive here is expensive to unpick.

**`homes.members` is a flat `v.array(v.id("users"))`. There is no owner and
there are no roles.** `homes:create` inserts the creator into `members` and
that is the whole model. Anything that needs "who pays" or "who may change the
plan" is building a concept the schema does not have yet.

**`convex/lib/auth.ts` has exactly four helpers** — `requireUser`,
`currentUserId`, `requireHomeMember`, `requireDocHome` — and every function
funnels through them. That is a single chokepoint for server-side enforcement,
and it is the reason this is tractable at all.

## 2. Who is the subscriber?

This is the decision everything else hangs off, and it has to be made first.

StoreKit subscriptions are per-Apple-ID. NestZone's data is per-household. The
two do not line up.

### Per-user entitlement — rejected

Ada pays, Ada opens Finance, Bea does not. Ada budgets Saturday's party; Bea
opens the same event and finds a hole where the budget is. Every cross-feature
link in §3 becomes a place where two people looking at the same document see
different things. Shared data with asymmetric visibility is worse than not
shipping the feature.

### Per-household, any active member unlocks — recommended

Entitlement lives on the `homes` document. Any member with a live receipt lifts
the whole house.

```ts
// homes: defineTable({ ... })
plan: v.optional(v.union(v.literal("free"), v.literal("premium"))),
plan_expires_at: v.optional(v.number()),
plan_source: v.optional(v.id("users")),   // whose receipt is carrying it
```

The cost is that one subscription covers a five-person house. For a shared
household app that is a feature and not a leak: it is how the other four people
come to care whether it renews. It is also the only model where §3 does not
produce half-visible documents.

### Per-seat — not now

Needs the owner/role concept the schema lacks, and it prices a household app
like a business tool.

## 3. The seams

Every place a would-be-premium feature's data already surfaces somewhere else.
This is the list a naive paywall breaks on.

### Finance ↔ Calendar

| Link | Where it shows |
|---|---|
| `events.budget`, `events.currency` | Money stored on a calendar document |
| `expenses.event_id` | Ledger rows pointing at an event |
| `finance:summary.events` | Event rollup on the Finance overview and Budgets page |
| Event detail budget card | Finance UI living inside Calendar |

### Finance ↔ House Problems

| Link | Where it shows |
|---|---|
| `issues.cost_estimate`, `issues.currency` | Money stored on a problem document |
| `expenses.issue_id` | Ledger rows pointing at a problem |
| `finance:summary.repairs` | Repair rollup on the Finance overview and Budgets page |
| `issues:byHome` → `spent`, `spent_currency` | Finance data inside the Issues board |
| `issues:detail` → linked expenses | Finance data inside a problem's detail |

### House Problems ↔ everything else

`tasks.issue_id`, `shopping_items.issue_id`, `issues.event_id`. Locking House
Problems orphans rows in three features that are not locked.

### Calendar ↔ Shopping and Recipes

`shopping_items.event_id`, `events.recipe_ids`.

### The aggregation surfaces

- `stats:forHome` counts `openTasks`, `shoppingItems`, `notes`, `openIssues`,
  `urgentIssues`, messages — across locked and unlocked features alike.
- The Hub's six module tiles.
- The Home tab: upcoming events, dinner (meals → recipes).

### Push — the one that generates support email

Notification sites by domain: **issues 7, events 6, finance 5**, plus tasks,
shopping, recipes, movies, meals, polls, notes, homes. Three crons:
`finance:sweepReminders` (08:00 UTC), `issues:sweepStale` (09:00), and an
interval sweep for events.

**A notification for a screen the household cannot open is the worst possible
paywall.** Every cron and every `notifyHome` in a gated domain has to check the
plan before it sends.

## 4. The rule that makes it tractable

> **A paywall gates the feature, never the household's own data.**

Three degradation modes, chosen per surface rather than globally:

- **Hidden** — the tile or tab is not there. For features never used.
- **Teased** — visible, showing a real aggregate, tap opens the paywall.
- **Read-only** — existing data readable, writes refused.

Recommended policy: **teased when never subscribed, read-only on lapse.** Three
months of ledger must not vanish because a card expired.

For *embedded* surfaces — the budget card inside an event detail, `spent` on an
issue row — the answer is: **show the number, gate the interaction.** The
party's budget is 200 EUR whether or not anyone pays. What premium buys is the
Finance screen, the rollups, and the settle-up plan.

Client gating is decorative on its own. `requirePlan(ctx, homeId)` goes next to
`requireDocHome` in `lib/auth.ts` and is called from every mutation in a gated
domain. Queries are subtler: gate the expensive aggregates (`finance:summary`),
leave open the ones that feed embedded surfaces, or the rule above breaks.

## 5. Which features should be premium

The test: which features does a household only come to value after weeks, and
which would make them delete the app on day one?

| Feature | Call | Why |
|---|---|---|
| Tasks, Shopping, Notes, Messages | **Free** | The "why we installed it" features. Shopping is the daily-habit hook; paywalling it kills acquisition. |
| **Finance** | **Premium** | Strongest candidate. Highest server cost — `finance:summary` collects every expense, settlement, bill and budget on *every* push. Highest perceived value. Splitting money is a commitment. |
| **House Problems** | **Premium** | Photo storage is a real cost. Vendor, warranty and timeline tracking is homeowner value a renter will not miss. |
| **Calendar** | **Free — gate the plan instead** | It is the connective tissue: `events.recipe_ids`, `shopping_items.event_id`, `issues.event_id`, meal plans, the Home tab's "upcoming". Locking it fragments more surfaces than anything else. Gate the *event plan* — budget, menu, shopping list — which paywalls exactly the depth and leaves the tissue intact. |
| Recipes | **Free** | A discovery surface with bundled samples that feeds Dinner and shopping. Low marginal cost. |
| Movies / MovieNight | **Free**, or gate only the swipe game | A fun hook, not a commitment feature. TMDb proxy costs API calls; if anything is gated here it should be the multi-device swipe game, not the lists. |

## 6. What to build before deciding any of it

The point of building the system first is that the table in §5 stops being
load-bearing. In dependency order:

1. **A feature registry.** One `enum PremiumFeature { case finance,
   houseProblems, eventPlans, … }` with a single mapping to entitlement level.
   Every gate in the app asks the registry; nothing hardcodes a check. Changing
   what is premium — or A/B testing it — becomes one line. **This is the piece
   that makes the rest decision-independent, and it should be built first.**
2. `homes.plan` / `plan_expires_at` / `plan_source` on the schema.
3. `requirePlan()` in `convex/lib/auth.ts`, called from gated mutations.
4. A plan check in `convex/crons.ts` and in the `notifyHome` calls of gated
   domains.
5. Client: `@Dependency(\.entitlements)` plus a `@Shared` entitlement value in
   `Design/AppSettings.swift`, so a gate is readable from any feature without
   any feature reaching into another.
6. `PremiumGate` in `Design/Components/`, with the three modes from §4.
7. One `PaywallFeature` taking a `PremiumFeature` as context, so every entry
   point can say what was being reached for rather than showing a generic
   pitch.

Steps 1–3 are worth doing regardless of what ends up premium. Steps 5–7 can
wait until the tier list is settled.

## 7. Open questions

- **Trial shape.** Time-limited, or usage-limited (three budgets, five
  problems)? Usage limits interact badly with §4's read-only rule.
- **Who may change the plan** when there is no owner concept? Any member, until
  roles exist.
- **What happens on the last subscriber leaving the household** — the home
  keeps `plan_source` pointing at somebody who is gone.
- **Receipt validation.** App Store Server Notifications need an HTTP endpoint;
  `convex/http.ts` already exists.
