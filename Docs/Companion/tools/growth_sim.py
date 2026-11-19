"""
NestZone companion growth simulation (v2: two tracks).

Daily growth = life growth + care growth.
  life growth = LIFE_CAP * (1 - exp(-life_raw / R_N)),  R_N = R0 * (N/2)^ALPHA
  care growth = flat, capped: first carer, each extra carer, a "together" bonus

Life is the saturating track, so the first things a household does in a day
count most and nobody can buy speed with volume. Care sits outside the curve
so a care-only household cannot ride the steep start of it.

Run: python3 growth_sim.py          (tables)
     python3 growth_sim.py --grid   (also sweeps the size exponent and threshold)
"""

import math
import random
import statistics
import sys

# ---------------------------------------------------------------- the economy

LIFE_CAP = 9.0            # most life growth one day can give
R0 = 7.0                  # saturation constant for a two-person household
SIZE_ALPHA = 0.35         # R_N = R0 * (N/2) ** SIZE_ALPHA
STAGE_FRACTIONS = [0.0, 0.05, 0.16, 0.33, 0.55, 0.78, 1.0]   # 7 stages
GRADUATE_AT = 160.0

# life raw weights
W_CHORE = 1.0
W_CHORE_MAINT = 1.5
QUICK_LOG_MULT = 0.5      # ticked <10 min after its own creator wrote it
DUP_TITLE_MULT = 0.25     # same title already credited today
CHORE_FULL_PER_PERSON = 4 # per person per day at full value, then halves
W_TRIP_BASE = 1.5
W_TRIP_ITEM = 0.25
TRIP_MAX = 3.0
TRIPS_PER_DAY = 2
W_DINNER = 2.0
W_EVENT_SOCIAL = 3.0
W_EVENT_OTHER = 1.0
EVENTS_PER_DAY = 2
W_FIX = {"cosmetic": 2.0, "minor": 3.0, "major": 5.0, "urgent": 6.0}
W_MOVIE = 3.0
W_BILL = 1.0
REST_PER_QUIET_DAY = 1.5  # banked per quiet day ...
REST_MAX = 6.0            # ... up to this, paid out on the next active day
QUIET_RAW = 1.0

# care track (growth points, not raw)
CARE_FIRST = 0.8
CARE_EACH_MORE = 0.4
CARE_TOGETHER = 0.5
CARE_CAP = 2.0

SLEEPY_AFTER = 3          # quiet days (no care, no signal) before "sleepy"


def r_for(n):
    return R0 * (max(n, 1) / 2) ** SIZE_ALPHA


def life_growth(raw, n):
    return LIFE_CAP * (1 - math.exp(-raw / r_for(n)))


def care_growth(carers):
    if not carers:
        return 0.0
    g = CARE_FIRST + CARE_EACH_MORE * (carers - 1)
    if carers >= 2:
        g += CARE_TOGETHER
    return min(CARE_CAP, g)


# ---------------------------------------------------------------- archetypes
#
# Weekly rates are household totals for things the app records. Care is a
# per-member daily probability. `quick_log` is the share of chores written down
# and ticked inside ten minutes by the same person.

BASE_COUPLE = dict(
    n=2, chores=10, maint_share=0.15, quick_log=0.25, dup_share=0.05,
    items=15, trips=2.5, dinners=4, events=1.5, social_share=0.6,
    fixes=0.25, movies=0.7, bills=1.0, care=[0.65, 0.55], busy_week=0.08,
)

ARCHETYPES = {
    "Couple": dict(BASE_COUPLE),
    "4 flatmates": dict(
        n=4, chores=14, maint_share=0.15, quick_log=0.2, dup_share=0.05,
        items=20, trips=4, dinners=2, events=1.0, social_share=0.6,
        fixes=0.5, movies=0.5, bills=1.0, care=[0.7, 0.5, 0.3, 0.15],
        busy_week=0.10,
    ),
    "Family of 4 (2 kids)": dict(
        n=4, chores=20, maint_share=0.1, quick_log=0.35, dup_share=0.15,
        items=25, trips=3, dinners=5, events=2.0, social_share=0.5,
        fixes=0.3, movies=1.0, bills=1.5, care=[0.4, 0.3, 0.9, 0.85],
        busy_week=0.08,
    ),
    "Low-activity couple": dict(
        n=2, chores=3, maint_share=0.1, quick_log=0.3, dup_share=0.0,
        items=6, trips=1.5, dinners=1, events=0.5, social_share=0.5,
        fixes=0.1, movies=0.2, bills=0.5, care=[0.25, 0.15],
        busy_week=0.15,
    ),
    "6 flatmates": dict(
        n=6, chores=18, maint_share=0.15, quick_log=0.2, dup_share=0.05,
        items=28, trips=5, dinners=2, events=1.2, social_share=0.6,
        fixes=0.6, movies=0.6, bills=1.0, care=[0.7, 0.5, 0.4, 0.3, 0.2, 0.1],
        busy_week=0.10,
    ),
    "Solo (1 member)": dict(
        n=1, chores=6, maint_share=0.15, quick_log=0.3, dup_share=0.05,
        items=10, trips=2, dinners=3, events=0.8, social_share=0.5,
        fixes=0.15, movies=0.3, bills=0.7, care=[0.6], busy_week=0.08,
    ),
    # --- stress cases -----------------------------------------------------
    "Couple, one never cares": dict(BASE_COUPLE, care=[0.65, 0.0]),
    "Couple + 30 fake chores/day": dict(
        BASE_COUPLE, chores=10 + 210, quick_log=0.95, dup_share=0.6,
        maint_share=0.0, one_person_chores=True,
    ),
    "Max-effort couple (all daily)": dict(
        BASE_COUPLE, chores=60, items=70, trips=14, dinners=7, events=7,
        movies=7, care=[1.0, 1.0], busy_week=0.0,
    ),
    "Care-only couple": dict(
        n=2, chores=0, maint_share=0, quick_log=0, dup_share=0, items=0,
        trips=0, dinners=0, events=0, social_share=0, fixes=0, movies=0,
        bills=0, care=[1.0, 1.0], busy_week=0.0,
    ),
}

WEEKDAY_MULT = [0.85, 0.85, 0.9, 0.9, 1.0, 1.35, 1.35]   # Mon..Sun
EVENT_WEEKDAY = [0.6, 0.6, 0.7, 0.8, 1.3, 1.6, 1.4]


def poisson(lam, rng):
    if lam <= 0:
        return 0
    l, k, p = math.exp(-lam), 0, 1.0
    while True:
        p *= rng.random()
        if p <= l:
            return k
        k += 1


def day(a, dow, busy, rng):
    """(life_raw, any_signal, carers) for one household-day, rules applied."""
    n = a["n"]
    m = 0.3 if busy else 1.0
    raw, signal = 0.0, False

    count = poisson(a["chores"] / 7 * WEEKDAY_MULT[dow] * m, rng)
    per_person = [0] * n
    for _ in range(count):
        who = 0 if a.get("one_person_chores") else rng.randrange(n)
        per_person[who] += 1
        w = W_CHORE_MAINT if rng.random() < a["maint_share"] else W_CHORE
        if rng.random() < a["quick_log"]:
            w *= QUICK_LOG_MULT
        if rng.random() < a["dup_share"]:
            w *= DUP_TITLE_MULT
        k = per_person[who]
        if k > CHORE_FULL_PER_PERSON:
            w *= 0.5 ** (k - CHORE_FULL_PER_PERSON)
        raw += w
        signal = True

    trips = min(poisson(a["trips"] / 7 * WEEKDAY_MULT[dow] * m, rng), TRIPS_PER_DAY)
    if trips:
        items = poisson(a["items"] / 7 * WEEKDAY_MULT[dow] * m, rng)
        for _ in range(trips):
            raw += min(TRIP_MAX, W_TRIP_BASE + W_TRIP_ITEM * items / trips)
        signal = True

    if rng.random() < min(1.0, a["dinners"] / 7 * m):
        raw += W_DINNER
        signal = True

    for _ in range(min(poisson(a["events"] / 7 * EVENT_WEEKDAY[dow] * m, rng), EVENTS_PER_DAY)):
        raw += W_EVENT_SOCIAL if rng.random() < a["social_share"] else W_EVENT_OTHER
        signal = True

    for _ in range(poisson(a["fixes"] / 7, rng)):
        raw += W_FIX[rng.choices(list(W_FIX), weights=[3, 4, 2, 1])[0]]
        signal = True

    if rng.random() < min(1.0, a["movies"] / 7 * EVENT_WEEKDAY[dow] * m):
        raw += W_MOVIE
        signal = True

    for _ in range(poisson(a["bills"] / 7, rng)):
        raw += W_BILL
        signal = True

    carers = sum(1 for p in a["care"] if rng.random() < p * (0.6 if busy else 1.0))
    return raw, signal, carers


def run(a, rng, max_days=240):
    total, bank, quiet, sleepy, care_total = 0.0, 0.0, 0, 0, 0.0
    stage_days = [0] + [None] * (len(STAGE_FRACTIONS) - 1)
    busy = False
    for d in range(1, max_days + 1):
        dow = (d - 1) % 7
        if dow == 0:
            busy = rng.random() < a["busy_week"]
        raw, signal, carers = day(a, dow, busy, rng)
        if raw < QUIET_RAW:
            bank = min(REST_MAX, bank + REST_PER_QUIET_DAY)
        elif raw >= 2 and bank:
            raw += bank
            bank = 0.0
        quiet = 0 if (signal or carers) else quiet + 1
        sleepy += quiet >= SLEEPY_AFTER
        cg = care_growth(carers)
        care_total += cg
        total += life_growth(raw, a["n"]) + cg
        for i, f in enumerate(STAGE_FRACTIONS):
            if stage_days[i] is None and total >= f * GRADUATE_AT:
                stage_days[i] = d
        if total >= GRADUATE_AT:
            return d, stage_days, sleepy / d, care_total / total
    return None, stage_days, sleepy / max_days, care_total / max(total, 1e-9)


def summarise(a, runs=2000, seed=7):
    rng = random.Random(seed)
    grads, stages, sleepy, care, never = [], [[] for _ in STAGE_FRACTIONS], [], [], 0
    for _ in range(runs):
        d, sd, sl, cs = run(a, rng)
        if d is None:
            never += 1
            continue
        grads.append(d)
        sleepy.append(sl)
        care.append(cs)
        for i, x in enumerate(sd):
            stages[i].append(x)
    grads.sort()
    q = lambda p: grads[min(len(grads) - 1, int(p * len(grads)))]
    return dict(
        p10=q(0.10), med=statistics.median(grads), p90=q(0.90),
        stages=[statistics.median(s) for s in stages],
        sleepy=100 * statistics.mean(sleepy), care=100 * statistics.mean(care),
        never=never,
    )


def table():
    print(f"LIFE_CAP={LIFE_CAP} CARE_CAP={CARE_CAP} R0={R0} alpha={SIZE_ALPHA} GRADUATE_AT={GRADUATE_AT}")
    print(f"floor (both caps every day): {math.ceil(GRADUATE_AT / (LIFE_CAP + CARE_CAP))} days\n")
    hdr = (f"{'household':31}{'N':>2}{'p10':>5}{'med':>5}{'p90':>5}   "
           f"{'st1':>4}{'st2':>4}{'st3':>4}{'st4':>4}{'st5':>4}{'grad':>5}  {'care%':>6}{'sleepy%':>8}")
    print(hdr)
    print("-" * len(hdr))
    for name, a in ARCHETYPES.items():
        s = summarise(a)
        st = "".join(f"{x:>4.0f}" for x in s["stages"][1:-1])
        print(f"{name:31}{a['n']:>2}{s['p10']:>5}{s['med']:>5.0f}{s['p90']:>5}   "
              f"{st}{s['stages'][-1]:>5.0f}  {s['care']:>6.1f}{s['sleepy']:>8.1f}")


def grid():
    global SIZE_ALPHA
    names = ["Couple", "4 flatmates", "Family of 4 (2 kids)", "6 flatmates", "Solo (1 member)"]
    print("\nsize exponent sweep (median days)")
    print(f"{'alpha':>6}" + "".join(f"{n[:12]:>14}" for n in names))
    for alpha in [0.0, 0.25, 0.35, 0.5, 0.75]:
        SIZE_ALPHA = alpha
        meds = [summarise(ARCHETYPES[n], runs=600)["med"] for n in names]
        print(f"{alpha:>6}" + "".join(f"{m:>14.0f}" for m in meds))
    SIZE_ALPHA = 0.35


if __name__ == "__main__":
    table()
    if "--grid" in sys.argv:
        grid()
