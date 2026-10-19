# If Problems, Calendar and Money become subscription features, a free household
# loses fixes, events and on-time bills as growth signals. How much slower does
# it grow, and does a small bump to the free signals restore the pace?
import growth_sim as sim
sim.GRADUATE_AT, sim.LIFE_CAP, sim.CARE_CAP = 64, 9.0, 2.0
names = ["Couple", "4 flatmates", "Family of 4 (2 kids)", "Solo (1 member)", "Low-activity couple"]
def free(a): return dict(a, events=0, fixes=0, bills=0)
def med(a): return sim.summarise(a, runs=1500)["med"]
print("household             all-features  free-only  free-only+boost")
base = (sim.W_CHORE, sim.W_DINNER, sim.W_MOVIE)
for n in names:
    a = sim.ARCHETYPES[n]
    full = med(a); fr = med(free(a))
    sim.W_CHORE, sim.W_DINNER, sim.W_MOVIE = 1.25, 2.5, 4.0
    boosted = med(free(a))
    sim.W_CHORE, sim.W_DINNER, sim.W_MOVIE = base
    print(f"{n:22}{full:>10.0f}{fr:>12.0f}{boosted:>14.0f}")
