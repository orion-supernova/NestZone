// App Store screenshot households.
//
// Two made-up homes — "Bizim Ev" in Turkish and "Our Place" in English — each
// with the owner plus three made-up members, filled so every screen looks
// lived in: chores and who did them, the shopping list, notes, recipes and
// this week's dinners, the calendar, the film lists and an open movie round,
// the money, the house problems, the group chat and Nestie.
//
// Internal only: nothing here is reachable from a phone. Run from the CLI:
//
//   npx convex run demo:seedScreenshotHomes '{"ownerUserId":"<id>"}'
//   npx convex run demo:listScreenshotHomes '{}'
//   npx convex run demo:purgeScreenshotHome '{"homeId":"<id>"}'
//
// The rows are written in exactly the shape the app's own mutations write
// them (snake_case fields, money in minor units, completions in
// `task_completions`, Nestie's growth through its own ledger), but directly:
// no push goes to anybody, and Plus is not checked. A house is Plus through
// its members, so put ONE of the returned `memberIds` into
// `PRO_COMP_USER_IDS` and only the demo houses become Plus.
//
// Every date is relative to the moment of seeding, in the house's offset
// (`tzOffset`, minutes east of UTC; Istanbul's 180 by default, which is the
// device the screenshots are taken on). Reminders are configured but already
// marked sent, so the daily sweeps never nudge the owner about a made-up bill.

import { v, Infer } from "convex/values";
import { ActionCtx, internalAction, internalMutation, internalQuery } from "./_generated/server";
import { internal } from "./_generated/api";
import { Doc, Id } from "./_generated/dataModel";
import { cascadeDeleteHome } from "./lib/relations";
import {
  availableDecor,
  checkout,
  cleanLayout,
  dayOf,
  dayStart,
  ensureHouse,
  isUsable,
  itemPrice,
  moveJar,
  shopContext,
  standingOfDecor,
  standingOfSpecies,
  stageFor,
  W_DINNER,
  W_FIX,
} from "./lib/companion";
import { CATALOG } from "./lib/companionData";
import { __growth, GrowthEntry } from "./companion";
import { DEMO_RECIPES_EN, DEMO_RECIPES_TR, DemoRecipe } from "./lib/demoRecipes";

const MINUTE = 60_000;
const HOUR = 60 * MINUTE;
const DAY = 24 * HOUR;

const lang = v.union(v.literal("tr"), v.literal("en"));
type Lang = Infer<typeof lang>;

const film = v.object({
  id: v.string(),
  title: v.string(),
  year: v.optional(v.number()),
  poster: v.optional(v.string()),
  genres: v.array(v.string()),
});
type Film = Infer<typeof film>;

const seedResult = v.object({
  homeId: v.id("homes"),
  lang,
  name: v.string(),
  /** The made-up members. Put ONE in PRO_COMP_USER_IDS to make the demo houses Plus. */
  memberIds: v.array(v.id("users")),
});

function seedName(l: Lang): string {
  return `screenshots-${l}`;
}

// ---------------------------------------------------------------------------
// The films. TMDb ids are public; the posters are fetched live through the
// same API key `catalog.ts` uses, so they are the paths TMDb serves today.
// The paths below are only the fallback when TMDb can't be reached.

const FILMS: Record<string, Film> = {
  "27205": { id: "27205", title: "Inception", year: 2010, poster: "/oYuLEt3zVCKq57qu2F8dT7NIa6f.jpg", genres: ["action", "science fiction", "adventure"] },
  "155": { id: "155", title: "The Dark Knight", year: 2008, poster: "/qJ2tW6WMUDux911r6m7haRef0WH.jpg", genres: ["drama", "action", "crime", "thriller"] },
  "129": { id: "129", title: "Spirited Away", year: 2001, poster: "/39wmItIWsg5sZMyRUHLkWBcuVCM.jpg", genres: ["animation", "family", "fantasy"] },
  "496243": { id: "496243", title: "Parasite", year: 2019, poster: "/7IiTTgloJzvGI1TAYymCfbfl3vT.jpg", genres: ["comedy", "thriller", "drama"] },
  "13": { id: "13", title: "Forrest Gump", year: 1994, poster: "/arw2vcBveWOVZr6pxd9XTd1TdQa.jpg", genres: ["comedy", "drama", "romance"] },
  "157336": { id: "157336", title: "Interstellar", year: 2014, poster: "/gEU2QniE6E77NI6lCU6MxlNBvIx.jpg", genres: ["adventure", "drama", "science fiction"] },
  "120467": { id: "120467", title: "The Grand Budapest Hotel", year: 2014, poster: "/eWdyYQreja6JGCzqHWXpWHDrrPo.jpg", genres: ["comedy", "drama"] },
  "313369": { id: "313369", title: "La La Land", year: 2016, poster: "/uDO8zWDhfWwoFdKS4fzkUJt0Rf0.jpg", genres: ["comedy", "drama", "romance", "music"] },
  "105": { id: "105", title: "Back to the Future", year: 1985, poster: "/fNOH9f1aA7XRTzl1sAOx9iF553Q.jpg", genres: ["adventure", "comedy", "science fiction"] },
  "603": { id: "603", title: "The Matrix", year: 1999, poster: "/f89U3ADr1oiB1s9GkdPOEpXUk5H.jpg", genres: ["action", "science fiction"] },
  "862": { id: "862", title: "Toy Story", year: 1995, poster: "/uXDfjJbdP4ijW5hWSBrPrlKpxab.jpg", genres: ["animation", "adventure", "family", "comedy"] },
  "194": { id: "194", title: "Amélie", year: 2001, poster: "/nSxDa3M9aMvGVLoItzWTepQ5h5d.jpg", genres: ["comedy", "romance"] },
  "4935": { id: "4935", title: "Howl's Moving Castle", year: 2004, poster: "/13kOl2v0nD2OLbVSHnHk8GUFEhO.jpg", genres: ["fantasy", "animation", "adventure"] },
  "8587": { id: "8587", title: "The Lion King", year: 1994, poster: "/sKCr78MXSLixwmZ8DyJLrpMsd15.jpg", genres: ["family", "animation", "drama"] },
  "324857": { id: "324857", title: "Spider-Man: Into the Spider-Verse", year: 2018, poster: "/iiZZdoQBEYBv6id8su7ImL0oCbD.jpg", genres: ["animation", "action", "adventure"] },
  "354912": { id: "354912", title: "Coco", year: 2017, poster: "/gGEsBPAijhVUFoiNpgZXqRVWJt2.jpg", genres: ["family", "animation", "fantasy", "music"] },
  "10681": { id: "10681", title: "WALL·E", year: 2008, poster: "/hbhFnRzzg6ZDmm8YAmxBnQpQIPh.jpg", genres: ["animation", "family", "science fiction"] },
  "2062": { id: "2062", title: "Ratatouille", year: 2007, poster: "/t3vaWRPSf6WjDSamIkKDs1iQWna.jpg", genres: ["animation", "comedy", "family"] },
  "14160": { id: "14160", title: "Up", year: 2009, poster: "/vpbaStTMt8qqXaEgnOR2EE4DNJk.jpg", genres: ["animation", "comedy", "family", "adventure"] },
};

const WISHLIST = ["27205", "155", "129", "496243", "13"];
const WATCHED = ["157336", "120467", "313369"];
const FRIDAY = ["105", "603", "862", "194"];
const ROUND = ["129", "4935", "8587", "324857", "354912", "10681", "2062", "14160", "862"];

/** The same TMDb shape → `Movie` mapping as `catalog.ts`'s `toMovie`. */
async function fetchFilm(id: string, key: string): Promise<Film | null> {
  try {
    const response = await fetch(`https://api.themoviedb.org/3/movie/${id}?api_key=${encodeURIComponent(key)}`);
    if (!response.ok) return null;
    const raw = (await response.json()) as {
      title?: string;
      release_date?: string;
      poster_path?: string | null;
      genres?: { name: string }[];
    };
    const year = raw.release_date ? Number(raw.release_date.slice(0, 4)) : undefined;
    if (!raw.title || !raw.poster_path) return null;
    return {
      id,
      title: raw.title,
      year: year !== undefined && Number.isFinite(year) ? year : undefined,
      poster: raw.poster_path,
      genres: (raw.genres ?? []).map((g) => g.name.toLowerCase()),
    };
  } catch {
    return null;
  }
}

/** Every film, from TMDb where it answered; `live` is how many did. */
async function resolveFilms(): Promise<{ films: Film[]; live: number }> {
  const key = process.env.TMDB_API_KEY;
  const ids = Object.keys(FILMS);
  if (!key) return { films: ids.map((id) => FILMS[id]), live: 0 };
  const fetched = await Promise.all(ids.map((id) => fetchFilm(id, key)));
  return {
    films: ids.map((id, i) => fetched[i] ?? FILMS[id]),
    live: fetched.filter((f) => f !== null).length,
  };
}

// ---------------------------------------------------------------------------
// The words, in each language. Members are referred to by slot:
// 0 = the owner, 1..3 = the made-up members.

type Copy = {
  home: string;
  region: string;
  currency: string;
  members: [string, string, string];
  /** Open chores: title, type, assignee slot, due in days (0 today, -1 overdue), hour, priority. */
  open: { title: string; type: Doc<"tasks">["type"]; who: number | null; due: number; hour: number; priority: Doc<"tasks">["priority"]; issue?: boolean }[];
  /** Finished chores, newest first: title, type, who did it, days ago. */
  done: { title: string; type: Doc<"tasks">["type"]; who: number; ago: number }[];
  /** Shopping: name, category, quantity, bought? */
  shopping: { name: string; category: NonNullable<Doc<"shopping_items">["category"]>; quantity?: number; bought?: boolean; by: number }[];
  eventItem: string;
  issueItem: string;
  notes: { text: string; by: number; ago: number }[];
  /** Recipe keys: tonight's, the party's menu, the rest of the week's cooking. */
  tonight: string;
  partyMenu: string[];
  week: ({ kind: "cook"; recipe: string } | { kind: "order" | "out"; cuisine: string; place: string })[];
  party: { title: string; notes: string; location: string; budget: number };
  birthday: { title: string; who: number };
  movieNight: string;
  /**
   * The rest of the calendar: one-offs around today. `day` is days from today,
   * or "sunday" for the coming Sunday; an all-day event ignores the hours.
   */
  calendar: {
    title: string;
    kind: NonNullable<Doc<"events">["kind"]>;
    day: number | "sunday";
    hour: number;
    minute?: number;
    hours: number;
    allDay?: boolean;
    by: number;
    location?: string;
  }[];
  plumber: { title: string; vendor: string; phone: string; location: string };
  issues: {
    tap: { title: string; details: string; estimate: number; comments: [string, string, string]; booked: string };
    light: { title: string; details: string; resolution: string };
    door: { title: string; details: string };
  };
  /** Expenses: title, category, payer slot, amount (minor units), fraction of the month so far. */
  expenses: { title: string; category: NonNullable<Doc<"expenses">["category"]>; by: number; amount: number; at: number; link?: "tap" | "light" | "internet" }[];
  settlement: { amount: number; note: string };
  /**
   * The five months before this one, oldest first: how much of this month's
   * everyday spending (not the one-off repairs) each of them came to. Each
   * month is squared up at its end, so history never moves today's balances.
   */
  history: [number, number, number, number, number];
  squareUp: string;
  bills: { internet: { title: string; amount: number }; rent: { title: string; amount: number } };
  budgets: { groceries: number; dining: number };
  wishlist: string;
  watched: string;
  friday: string;
  round: string;
  chat: { title: string; lines: { by: number; text: string; ago: number }[] };
  activity: { by: number; category: string; title: string; body: string; ago: number }[];
};

const TR: Copy = {
  home: "Bizim Ev",
  region: "TR",
  currency: "TRY",
  members: ["Ayşe", "Mert", "Deniz"],
  open: [
    { title: "Banyoyu temizle", type: "cleaning", who: 1, due: 0, hour: 20, priority: "medium" },
    { title: "Çöpleri çıkar", type: "cleaning", who: 2, due: 0, hour: 21, priority: "high" },
    { title: "Çamaşırları as", type: "general", who: 0, due: -1, hour: 19, priority: "medium" },
    { title: "Çiçekleri sula", type: "general", who: 3, due: 1, hour: 10, priority: "low" },
    { title: "Kargoyu teslim al", type: "general", who: 1, due: 1, hour: 18, priority: "medium" },
    { title: "Musluk contasını tak", type: "maintenance", who: 3, due: 2, hour: 12, priority: "high", issue: true },
    { title: "Buzdolabını temizle", type: "cleaning", who: null, due: 3, hour: 12, priority: "low" },
    { title: "Kombinin filtresine bak", type: "maintenance", who: 2, due: 5, hour: 12, priority: "medium" },
  ],
  done: [
    { title: "Bulaşık makinesini boşalt", type: "cleaning", who: 1, ago: 0 },
    { title: "Çarşafları değiştir", type: "cleaning", who: 0, ago: 0 },
    { title: "Salonu süpür", type: "cleaning", who: 3, ago: 1 },
    { title: "Mutfak tezgahını sil", type: "cleaning", who: 2, ago: 1 },
    { title: "Market alışverişi", type: "shopping", who: 0, ago: 2 },
    { title: "Çamaşır makinesini çalıştır", type: "general", who: 1, ago: 2 },
    { title: "Balkonu süpür", type: "cleaning", who: 3, ago: 3 },
    { title: "Banyo aynasını sil", type: "cleaning", who: 2, ago: 3 },
    { title: "Geri dönüşümü at", type: "general", who: 0, ago: 4 },
    { title: "Koridor ampulünü değiştir", type: "maintenance", who: 2, ago: 5 },
    { title: "Fırını temizle", type: "cleaning", who: 1, ago: 5 },
    { title: "Halıları silkele", type: "cleaning", who: 3, ago: 6 },
    { title: "Pazar alışverişi", type: "shopping", who: 1, ago: 7 },
    { title: "Bulaşıkları yıka", type: "cleaning", who: 0, ago: 7 },
    { title: "Toz al", type: "cleaning", who: 3, ago: 8 },
    { title: "Lavabo giderini aç", type: "maintenance", who: 2, ago: 9 },
    { title: "Çöpleri çıkar", type: "cleaning", who: 1, ago: 10 },
    { title: "Paspas yap", type: "cleaning", who: 0, ago: 11 },
  ],
  shopping: [
    { name: "Süt", category: "groceries", quantity: 2, by: 1 },
    { name: "Yumurta (15'li)", category: "groceries", by: 0 },
    { name: "Domates", category: "groceries", quantity: 1, by: 3 },
    { name: "Beyaz peynir", category: "groceries", by: 2 },
    { name: "Türk kahvesi", category: "groceries", by: 1 },
    { name: "Ekmek", category: "groceries", quantity: 2, bought: true, by: 3 },
    { name: "Çöp poşeti", category: "household", by: 0 },
    { name: "Kağıt havlu", category: "household", bought: true, by: 2 },
    { name: "Bulaşık deterjanı", category: "cleaning", by: 1 },
    { name: "Çamaşır suyu", category: "cleaning", by: 2 },
  ],
  eventItem: "Parmesan",
  issueItem: "Musluk contası",
  notes: [
    { text: "Wi-Fi: BizimEv_5G\nŞifre: kirmizi-kedi-42 🔑", by: 2, ago: 20 },
    { text: "Ev sahibi Selim Bey: 0500 000 00 00\nKira her ayın 5'inde, aidat 10'unda.", by: 0, ago: 14 },
    { text: "Kuru fasulyeyi akşamdan ıslatın, bir tutam karbonat atınca çok daha çabuk pişiyor 👌", by: 1, ago: 3 },
  ],
  tonight: "turkish_kuru_fasulye",
  partyMenu: ["authentic_carbonara", "greek_salad", "classic_brownies"],
  week: [
    { kind: "cook", recipe: "shakshuka" },
    { kind: "order", cuisine: "turkish", place: "Köşedeki pideci" },
    { kind: "cook", recipe: "thai_green_curry" },
    { kind: "out", cuisine: "seafood", place: "Sahildeki balıkçı" },
    { kind: "order", cuisine: "italian", place: "Mahalle pizzacısı" },
    { kind: "cook", recipe: "greek_salad" },
    { kind: "cook", recipe: "shakshuka" },
  ],
  party: {
    title: "Akşam yemeği daveti 🍝",
    notes: "Herkes bir şişe şarap getirsin 🍷 Saat 19:30'da sofradayız.",
    location: "Ev",
    budget: 150_000,
  },
  birthday: { title: "Deniz'in doğum günü 🎂", who: 3 },
  movieNight: "Film gecesi 🍿",
  calendar: [
    { title: "Konser 🎶", kind: "concert", day: -11, hour: 21, hours: 3, by: 2, location: "Zorlu PSM" },
    { title: "Ev toplantısı", kind: "general", day: -6, hour: 20, hours: 1, by: 1, location: "Ev" },
    { title: "Pilates 🧘", kind: "sports", day: 0, hour: 19, hours: 1, by: 0 },
    { title: "Annemler geliyor", kind: "visit", day: 2, hour: 13, hours: 4, by: 0 },
    { title: "Pazar kahvaltısı 🥐", kind: "dining", day: "sunday", hour: 10, minute: 30, hours: 2, by: 1 },
    { title: "Diş hekimi — Mert", kind: "appointment", day: 5, hour: 15, minute: 30, hours: 1, by: 2 },
    { title: "Pilates 🧘", kind: "sports", day: 7, hour: 19, hours: 1, by: 0 },
    { title: "Halı yıkama", kind: "chore", day: 9, hour: 10, hours: 2, by: 3 },
    { title: "Sinemaya gidiyoruz 🎬", kind: "cinema", day: 12, hour: 20, minute: 30, hours: 3, by: 3 },
    { title: "Kira günü", kind: "deadline", day: 16, hour: 0, hours: 24, allDay: true, by: 0 },
  ],
  plumber: { title: "Tesisatçı — mutfak musluğu", vendor: "Usta Hakan", phone: "0500 000 00 01", location: "Mutfak" },
  issues: {
    tap: {
      title: "Mutfak musluğu damlatıyor",
      details: "Kapatınca da damlıyor, gece tık tık ses yapıyor. Conta gitmiş olabilir.",
      estimate: 150_000,
      comments: ["Gece boyunca tık tık, uyuyamadım 😩", "Contayı ben alırım, yarın hallederiz", "Usta yarın 10'da geliyor"],
      booked: "Ziyaret ayarlandı",
    },
    light: {
      title: "Koridor lambası yanmıyor",
      details: "Düğmeye basınca hiç yanmıyor.",
      resolution: "Ampul değişti, LED taktık 💡",
    },
    door: {
      title: "Balkon kapısı gıcırdıyor",
      details: "Açarken bayağı ses yapıyor, biraz yağ lazım.",
    },
  },
  expenses: [
    { title: "Market alışverişi", category: "groceries", by: 0, amount: 71_000, at: 0.15 },
    { title: "Elektrik faturası", category: "utilities", by: 1, amount: 122_500, at: 0.25 },
    { title: "İnternet", category: "utilities", by: 2, amount: 64_990, at: 0.3, link: "internet" },
    { title: "Pazar alışverişi", category: "groceries", by: 2, amount: 100_000, at: 0.45 },
    { title: "Temizlik malzemeleri", category: "household", by: 1, amount: 42_500, at: 0.55 },
    { title: "Ampul", category: "household", by: 0, amount: 18_990, at: 0.6, link: "light" },
    { title: "Pizza gecesi", category: "dining", by: 3, amount: 62_000, at: 0.7 },
    { title: "Dizi aboneliği", category: "subscriptions", by: 3, amount: 22_999, at: 0.8 },
    { title: "Tesisatçı keşif ücreti", category: "household", by: 1, amount: 75_000, at: 0.95, link: "tap" },
  ],
  settlement: { amount: 30_000, note: "Market payı" },
  history: [1.12, 1.4, 1.65, 1.25, 1.5],
  squareUp: "Ay sonu hesaplaşma",
  bills: { internet: { title: "İnternet", amount: 64_990 }, rent: { title: "Kira", amount: 2_500_000 } },
  budgets: { groceries: 800_000, dining: 300_000 },
  wishlist: "İzlenecekler",
  watched: "İzlediklerimiz",
  friday: "Cuma gecesi",
  round: "Animasyon",
  chat: {
    title: "Ev 🏡",
    lines: [
      { by: 1, text: "Akşama kim evde? 🍲", ago: 190 },
      { by: 2, text: "Ben 7 gibi gelirim", ago: 182 },
      { by: 0, text: "Ben buradayım, kuru fasulye yapıyoruz 😋", ago: 175 },
      { by: 3, text: "Süper! Ekmek alayım mı?", ago: 160 },
      { by: 1, text: "Al lütfen, bir de süt bitmiş", ago: 151 },
      { by: 2, text: "Cumartesi için şarabı ben hallederim 🍷", ago: 95 },
      { by: 3, text: "Bu arada tesisatçı yarın 10'da geliyor", ago: 40 },
      { by: 1, text: "Oh be, sonunda o damla sesinden kurtuluyoruz 🙌", ago: 12 },
    ],
  },
  activity: [
    { by: 1, category: "tasks", title: "Ayşe görevi bitirdi", body: "Bulaşık makinesini boşalt", ago: 70 },
    { by: 3, category: "shopping", title: "Deniz ekledi", body: "Domates", ago: 130 },
    { by: 2, category: "finance", title: "Mert harcama ekledi", body: "Pazar alışverişi", ago: 300 },
    { by: 3, category: "issues", title: "Tamir ziyareti ayarlandı", body: "Tesisatçı — mutfak musluğu", ago: 420 },
    { by: 1, category: "calendar", title: "Ayşe etkinlik ekledi", body: "Akşam yemeği daveti 🍝", ago: 1500 },
    { by: 2, category: "movies", title: "Mert film ekledi", body: "Parasite — İzlenecekler", ago: 2900 },
  ],
};

const EN: Copy = {
  home: "Our Place",
  region: "US",
  currency: "USD",
  members: ["Maya", "Leo", "Sam"],
  open: [
    { title: "Clean the bathroom", type: "cleaning", who: 1, due: 0, hour: 20, priority: "medium" },
    { title: "Take out the bins", type: "cleaning", who: 2, due: 0, hour: 21, priority: "high" },
    { title: "Hang up the laundry", type: "general", who: 0, due: -1, hour: 19, priority: "medium" },
    { title: "Water the plants", type: "general", who: 3, due: 1, hour: 10, priority: "low" },
    { title: "Pick up the parcel", type: "general", who: 1, due: 1, hour: 18, priority: "medium" },
    { title: "Fit the new tap washer", type: "maintenance", who: 3, due: 2, hour: 12, priority: "high", issue: true },
    { title: "Clean out the fridge", type: "cleaning", who: null, due: 3, hour: 12, priority: "low" },
    { title: "Check the heating filter", type: "maintenance", who: 2, due: 5, hour: 12, priority: "medium" },
  ],
  done: [
    { title: "Empty the dishwasher", type: "cleaning", who: 1, ago: 0 },
    { title: "Change the bed sheets", type: "cleaning", who: 0, ago: 0 },
    { title: "Vacuum the living room", type: "cleaning", who: 3, ago: 1 },
    { title: "Wipe down the kitchen", type: "cleaning", who: 2, ago: 1 },
    { title: "Grocery run", type: "shopping", who: 0, ago: 2 },
    { title: "Run the washing machine", type: "general", who: 1, ago: 2 },
    { title: "Sweep the balcony", type: "cleaning", who: 3, ago: 3 },
    { title: "Clean the bathroom mirror", type: "cleaning", who: 2, ago: 3 },
    { title: "Take out the recycling", type: "general", who: 0, ago: 4 },
    { title: "Replace the hallway bulb", type: "maintenance", who: 2, ago: 5 },
    { title: "Clean the oven", type: "cleaning", who: 1, ago: 5 },
    { title: "Shake out the rugs", type: "cleaning", who: 3, ago: 6 },
    { title: "Farmers market", type: "shopping", who: 1, ago: 7 },
    { title: "Do the dishes", type: "cleaning", who: 0, ago: 7 },
    { title: "Dust the shelves", type: "cleaning", who: 3, ago: 8 },
    { title: "Unclog the sink", type: "maintenance", who: 2, ago: 9 },
    { title: "Take out the bins", type: "cleaning", who: 1, ago: 10 },
    { title: "Mop the floors", type: "cleaning", who: 0, ago: 11 },
  ],
  shopping: [
    { name: "Milk", category: "groceries", quantity: 2, by: 1 },
    { name: "Eggs (dozen)", category: "groceries", by: 0 },
    { name: "Tomatoes", category: "groceries", quantity: 6, by: 3 },
    { name: "Feta", category: "groceries", by: 2 },
    { name: "Coffee beans", category: "groceries", by: 1 },
    { name: "Sourdough", category: "groceries", bought: true, by: 3 },
    { name: "Bin bags", category: "household", by: 0 },
    { name: "Paper towels", category: "household", bought: true, by: 2 },
    { name: "Dish soap", category: "cleaning", by: 1 },
    { name: "Laundry detergent", category: "cleaning", by: 2 },
  ],
  eventItem: "Parmesan",
  issueItem: "Tap washer",
  notes: [
    { text: "Wi-Fi: OurPlace_5G\nPassword: red-cat-42 🔑", by: 2, ago: 20 },
    { text: "Landlord (Mr. Ellis): (555) 010-0000\nRent is due on the 1st.", by: 0, ago: 14 },
    { text: "Soak the beans the night before — a pinch of baking soda makes them cook way faster 👌", by: 1, ago: 3 },
  ],
  tonight: "thai_green_curry",
  partyMenu: ["authentic_carbonara", "greek_salad", "classic_brownies"],
  week: [
    { kind: "cook", recipe: "shakshuka" },
    { kind: "order", cuisine: "mexican", place: "The taco place" },
    { kind: "cook", recipe: "turkish_kuru_fasulye" },
    { kind: "out", cuisine: "japanese", place: "Sushi down the street" },
    { kind: "order", cuisine: "italian", place: "The corner pizzeria" },
    { kind: "cook", recipe: "greek_salad" },
    { kind: "cook", recipe: "shakshuka" },
  ],
  party: {
    title: "Dinner party 🍝",
    notes: "Everyone bring a bottle 🍷 Food's on the table at 7:30.",
    location: "Home",
    budget: 12_000,
  },
  birthday: { title: "Sam's birthday 🎂", who: 3 },
  movieNight: "Movie night 🍿",
  calendar: [
    { title: "Concert 🎶", kind: "concert", day: -11, hour: 21, hours: 3, by: 2, location: "The Fillmore" },
    { title: "House meeting", kind: "general", day: -6, hour: 20, hours: 1, by: 1, location: "Home" },
    { title: "Yoga 🧘", kind: "sports", day: 0, hour: 19, hours: 1, by: 0 },
    { title: "Mum's visiting", kind: "visit", day: 2, hour: 13, hours: 4, by: 0 },
    { title: "Sunday brunch 🥐", kind: "dining", day: "sunday", hour: 10, minute: 30, hours: 2, by: 1 },
    { title: "Dentist — Leo", kind: "appointment", day: 5, hour: 15, minute: 30, hours: 1, by: 2 },
    { title: "Yoga 🧘", kind: "sports", day: 7, hour: 19, hours: 1, by: 0 },
    { title: "Carpet cleaning", kind: "chore", day: 9, hour: 10, hours: 2, by: 3 },
    { title: "Cinema trip 🎬", kind: "cinema", day: 12, hour: 20, minute: 30, hours: 3, by: 3 },
    { title: "Rent day", kind: "deadline", day: 16, hour: 0, hours: 24, allDay: true, by: 0 },
  ],
  plumber: { title: "Plumber — kitchen tap", vendor: "Dave's Plumbing", phone: "(555) 010-0001", location: "Kitchen" },
  issues: {
    tap: {
      title: "Kitchen tap is dripping",
      details: "Drips even when it's off, and you can hear it all night. Probably the washer.",
      estimate: 12_000,
      comments: ["Drip, drip, drip all night 😩", "I'll grab a washer tomorrow", "Plumber's coming tomorrow at 10"],
      booked: "Booked a visit",
    },
    light: {
      title: "Hallway light is out",
      details: "Nothing happens when you flip the switch.",
      resolution: "New bulb, went with LED 💡",
    },
    door: {
      title: "Balcony door squeaks",
      details: "Really loud when you open it — needs a bit of oil.",
    },
  },
  expenses: [
    { title: "Groceries", category: "groceries", by: 0, amount: 10_270, at: 0.15 },
    { title: "Electricity", category: "utilities", by: 1, amount: 8_640, at: 0.25 },
    { title: "Internet", category: "utilities", by: 2, amount: 5_999, at: 0.3, link: "internet" },
    { title: "Farmers market", category: "groceries", by: 2, amount: 8_220, at: 0.45 },
    { title: "Cleaning supplies", category: "household", by: 1, amount: 2_780, at: 0.55 },
    { title: "Light bulbs", category: "household", by: 0, amount: 1_249, at: 0.6, link: "light" },
    { title: "Pizza night", category: "dining", by: 3, amount: 7_670, at: 0.7 },
    { title: "Streaming", category: "subscriptions", by: 3, amount: 1_549, at: 0.8 },
    { title: "Plumber call-out", category: "household", by: 1, amount: 6_500, at: 0.95, link: "tap" },
  ],
  settlement: { amount: 2_500, note: "Groceries" },
  history: [0.6, 0.75, 0.9, 0.7, 0.8],
  squareUp: "End-of-month square-up",
  bills: { internet: { title: "Internet", amount: 5_999 }, rent: { title: "Rent", amount: 240_000 } },
  budgets: { groceries: 60_000, dining: 20_000 },
  wishlist: "Wishlist",
  watched: "Watched",
  friday: "Friday night",
  round: "Animation",
  chat: {
    title: "The house 🏡",
    lines: [
      { by: 1, text: "Who's home for dinner tonight? 🍲", ago: 190 },
      { by: 2, text: "I'll be back around 7", ago: 182 },
      { by: 0, text: "I'm here — making green curry 😋", ago: 175 },
      { by: 3, text: "Nice! Want me to grab bread?", ago: 160 },
      { by: 1, text: "Yes please, and we're out of milk", ago: 151 },
      { by: 2, text: "I've got the wine for Saturday 🍷", ago: 95 },
      { by: 3, text: "Btw the plumber's coming tomorrow at 10", ago: 40 },
      { by: 1, text: "Finally, no more drip drip drip 🙌", ago: 12 },
    ],
  },
  activity: [
    { by: 1, category: "tasks", title: "Maya finished a task", body: "Empty the dishwasher", ago: 70 },
    { by: 3, category: "shopping", title: "Sam added", body: "Tomatoes", ago: 130 },
    { by: 2, category: "finance", title: "Leo added an expense", body: "Farmers market", ago: 300 },
    { by: 3, category: "issues", title: "A repair visit is booked", body: "Plumber — kitchen tap", ago: 420 },
    { by: 1, category: "calendar", title: "Maya added an event", body: "Dinner party 🍝", ago: 1500 },
    { by: 2, category: "movies", title: "Leo added a film", body: "Parasite — Wishlist", ago: 2900 },
  ],
};

const COPY: Record<Lang, Copy> = { tr: TR, en: EN };
const RECIPES: Record<Lang, DemoRecipe[]> = { tr: DEMO_RECIPES_TR, en: DEMO_RECIPES_EN };

// ---------------------------------------------------------------------------
// The house's clock: days and hours in its own offset, as the phone counts them.

type Clock = { now: number; tz: number; y: number; m: number; d: number; dow: number };

function clockFor(now: number, tz: number): Clock {
  const t = new Date(now + tz * MINUTE);
  return { now, tz, y: t.getUTCFullYear(), m: t.getUTCMonth(), d: t.getUTCDate(), dow: t.getUTCDay() };
}

/** `days` from today at `hour:minute`, house time, as epoch-ms. */
function at(c: Clock, days: number, hour: number, minute = 0): number {
  return Date.UTC(c.y, c.m, c.d + days, hour, minute) - c.tz * MINUTE;
}

/** `days` from today as `YYYY-MM-DD`, house time. */
function dateOf(c: Clock, days: number): string {
  return new Date(Date.UTC(c.y, c.m, c.d + days)).toISOString().slice(0, 10);
}

/** Never in the future: a "today" thing seeded early in the morning lands a little before now. */
function past(c: Clock, t: number, slack = 5 * MINUTE): number {
  return Math.min(t, c.now - slack);
}

// ---------------------------------------------------------------------------
// The household.

export const seedHousehold = internalMutation({
  args: {
    ownerUserId: v.id("users"),
    lang,
    tzOffset: v.number(),
    films: v.array(film),
  },
  returns: seedResult,
  handler: async (ctx, { ownerUserId, lang: l, tzOffset, films }) => {
    const owner = await ctx.db.get(ownerUserId);
    if (!owner) throw new Error("No such owner");
    if (!Number.isFinite(tzOffset) || Math.abs(tzOffset) > 14 * 60) throw new Error("A bad offset");
    const seed = seedName(l);
    for (const id of owner.home_id ?? []) {
      const existing = await ctx.db.get(id);
      if (existing?.demo_seed === seed) {
        throw new Error(`Already seeded: ${seed} is home ${id}. Purge it first (demo:purgeScreenshotHome).`);
      }
    }

    const text = COPY[l];
    const c = clockFor(Date.now(), tzOffset);
    const now = c.now;
    const film = new Map(films.map((f) => [f.id, f]));
    const filmOf = (id: string): Film => film.get(id) ?? FILMS[id];

    // --- The home and its people ------------------------------------------
    const homeId = await ctx.db.insert("homes", {
      name: text.home,
      members: [ownerUserId],
      invite_code: crypto.randomUUID().toUpperCase(),
      demo_seed: seed,
      created: now - 120 * DAY,
      updated: now,
    });
    const fakes: Id<"users">[] = [];
    for (const name of text.members) {
      fakes.push(
        await ctx.db.insert("users", {
          name,
          home_id: [homeId],
          demo_seed: seed,
          created: now - 120 * DAY,
          updated: now,
        }),
      );
    }
    const people: Id<"users">[] = [ownerUserId, ...fakes];
    const who = (slot: number): Id<"users"> => people[slot];
    await ctx.db.patch(homeId, { members: people });
    await ctx.db.patch(ownerUserId, { home_id: [...new Set([...(owner.home_id ?? []), homeId])] });

    // --- Recipes -------------------------------------------------------------
    const recipeIds = new Map<string, Id<"recipes">>();
    for (const [i, r] of RECIPES[l].entries()) {
      recipeIds.set(
        r.key,
        await ctx.db.insert("recipes", {
          title: r.title,
          description: r.description,
          ingredients: r.ingredients,
          steps: r.steps,
          tags: r.tags,
          prep_time: r.prep_time,
          cook_time: r.cook_time,
          servings: r.servings,
          difficulty: r.difficulty,
          home_id: homeId,
          created_by: who(i % 4),
          created: now - (40 - i * 5) * DAY,
          updated: now - (40 - i * 5) * DAY,
        }),
      );
    }
    const recipe = (key: string): Id<"recipes"> => {
      const id = recipeIds.get(key);
      if (!id) throw new Error(`No demo recipe ${key}`);
      return id;
    };

    // --- The calendar ----------------------------------------------------------
    // This weekend's Saturday, or next week's if Saturday evening is already over.
    let toSaturday = (6 - c.dow + 7) % 7;
    if (toSaturday === 0 && now > at(c, 0, 19)) toSaturday = 7;
    const toFriday = (5 - c.dow + 7) % 7 || 7;
    const remindedFor = (start: number, mins: number[]) => mins.map((m) => `${start}:${m}`);

    const partyStart = at(c, toSaturday, 19, 30);
    const partyId = await ctx.db.insert("events", {
      home_id: homeId,
      title: text.party.title,
      notes: text.party.notes,
      location: text.party.location,
      kind: "dinnerParty",
      starts_at: partyStart,
      ends_at: at(c, toSaturday, 23, 30),
      is_all_day: false,
      tz_offset: tzOffset,
      series_end: at(c, toSaturday, 23, 30),
      budget: text.party.budget,
      currency: text.currency,
      recipe_ids: text.partyMenu.map(recipe),
      attendees: people,
      rsvps: [
        { user_id: who(1), status: "going" },
        { user_id: who(0), status: "going" },
        { user_id: who(3), status: "going" },
        { user_id: who(2), status: "maybe" },
      ],
      reminders: [1440, 60],
      reminded: remindedFor(partyStart, [1440, 60]),
      created_by: who(1),
      created: now - 2 * DAY,
      updated: now - 2 * DAY,
    });

    const birthdayStart = at(c, 6, 0);
    await ctx.db.insert("events", {
      home_id: homeId,
      title: text.birthday.title,
      kind: "birthday",
      starts_at: birthdayStart,
      ends_at: at(c, 7, 0),
      is_all_day: true,
      tz_offset: tzOffset,
      series_end: at(c, 7, 0),
      attendees: people,
      rsvps: [
        { user_id: who(0), status: "going" },
        { user_id: who(1), status: "going" },
        { user_id: who(2), status: "going" },
      ],
      reminders: [1440],
      reminded: remindedFor(birthdayStart, [1440]),
      created_by: who(2),
      created: now - 9 * DAY,
      updated: now - 9 * DAY,
    });

    const movieStart = at(c, toFriday, 21, 0);
    await ctx.db.insert("events", {
      home_id: homeId,
      title: text.movieNight,
      kind: "movieNight",
      location: text.party.location,
      starts_at: movieStart,
      ends_at: at(c, toFriday, 23, 30),
      is_all_day: false,
      tz_offset: tzOffset,
      series_end: at(c, toFriday, 23, 30),
      attendees: people,
      rsvps: [
        { user_id: who(3), status: "going" },
        { user_id: who(1), status: "going" },
      ],
      reminders: [60],
      reminded: remindedFor(movieStart, [60]),
      created_by: who(3),
      created: now - 1 * DAY,
      updated: now - 1 * DAY,
    });

    // The rest of the month: one-offs, so every reminder is a single key to mark sent.
    const toSunday = (7 - c.dow) % 7 || 7;
    for (const [i, e] of text.calendar.entries()) {
      const day = e.day === "sunday" ? toSunday : e.day;
      const start = e.allDay ? at(c, day, 0) : at(c, day, e.hour, e.minute ?? 0);
      const end = e.allDay ? at(c, day + 1, 0) : start + e.hours * HOUR;
      const reminders = e.allDay ? [1440] : [60];
      const attendees = e.kind === "appointment" ? [who(e.by)] : people;
      const createdAt = Math.min(start, now) - (3 + (i % 4)) * DAY;
      await ctx.db.insert("events", {
        home_id: homeId,
        title: e.title,
        kind: e.kind,
        location: e.location,
        starts_at: start,
        ends_at: end,
        is_all_day: e.allDay ?? false,
        tz_offset: tzOffset,
        series_end: end,
        attendees,
        rsvps: attendees.length > 1
          ? attendees.filter((_, slot) => slot !== (e.by + 2) % 4).map((id) => ({ user_id: id, status: "going" as const }))
          : [{ user_id: who(e.by), status: "going" as const }],
        reminders,
        reminded: remindedFor(start, reminders),
        created_by: who(e.by),
        created: createdAt,
        updated: createdAt,
      });
    }

    // --- House problems --------------------------------------------------------
    const tapReported = past(c, at(c, -2, 23, 10));
    const tapActivity = now - 3 * HOUR;
    const tapId = await ctx.db.insert("issues", {
      home_id: homeId,
      title: text.issues.tap.title,
      details: text.issues.tap.details,
      area: "kitchen",
      category: "plumbing",
      severity: "urgent",
      status: "scheduled",
      is_open: true,
      reported_by: who(1),
      assigned_to: who(2),
      due_by: at(c, 2, 18),
      cost_estimate: text.issues.tap.estimate,
      currency: text.currency,
      vendor_name: text.plumber.vendor,
      vendor_phone: text.plumber.phone,
      me_too: [who(1), who(0), who(3)],
      last_activity_at: tapActivity,
      reminded: [`${at(c, 2, 18)}:overdue`, `${tapActivity}:stale`],
      created: tapReported,
      updated: tapActivity,
    });
    const visitStart = at(c, 1, 10);
    const visitId = await ctx.db.insert("events", {
      home_id: homeId,
      title: text.plumber.title,
      notes: text.issues.tap.details,
      location: text.plumber.location,
      kind: "appointment",
      starts_at: visitStart,
      ends_at: at(c, 1, 11),
      is_all_day: false,
      tz_offset: tzOffset,
      series_end: at(c, 1, 11),
      reminders: [60],
      reminded: remindedFor(visitStart, [60]),
      created_by: who(2),
      created: tapActivity,
      updated: tapActivity,
    });

    const lightFixed = past(c, at(c, -5, 18, 40));
    const lightActivity = lightFixed;
    const lightId = await ctx.db.insert("issues", {
      home_id: homeId,
      title: text.issues.light.title,
      details: text.issues.light.details,
      area: "hallway",
      category: "electrical",
      severity: "minor",
      status: "fixed",
      is_open: false,
      reported_by: who(3),
      assigned_to: who(2),
      resolved_at: lightFixed,
      resolved_by: who(2),
      resolution: text.issues.light.resolution,
      me_too: [who(3)],
      last_activity_at: lightActivity,
      reminded: [`${lightActivity}:stale`],
      created: at(c, -7, 21),
      updated: lightFixed,
    });

    const doorReported = at(c, -4, 9, 15);
    await ctx.db.insert("issues", {
      home_id: homeId,
      title: text.issues.door.title,
      details: text.issues.door.details,
      area: "balcony",
      category: "furniture",
      severity: "cosmetic",
      status: "reported",
      is_open: true,
      reported_by: who(3),
      me_too: [who(3), who(1)],
      last_activity_at: doorReported,
      reminded: [`${doorReported}:stale`],
      created: doorReported,
      updated: doorReported,
    });

    const timeline: {
      issue: Id<"issues">;
      author?: Id<"users">;
      kind: Doc<"issue_comments">["kind"];
      body?: string;
      from?: Doc<"issues">["status"];
      to?: Doc<"issues">["status"];
      created: number;
    }[] = [
      { issue: tapId, author: who(1), kind: "comment", body: text.issues.tap.comments[0], created: tapReported + 5 * MINUTE },
      { issue: tapId, author: who(3), kind: "comment", body: text.issues.tap.comments[1], created: now - 20 * HOUR },
      { issue: tapId, author: who(2), kind: "link", body: text.issues.tap.booked, created: tapActivity - MINUTE },
      { issue: tapId, author: who(2), kind: "status", from: "reported", to: "scheduled", created: tapActivity - MINUTE + 1 },
      { issue: tapId, author: who(2), kind: "comment", body: text.issues.tap.comments[2], created: tapActivity },
      { issue: lightId, author: who(2), kind: "status", from: "reported", to: "fixed", created: lightFixed },
      { issue: lightId, author: who(2), kind: "comment", body: text.issues.light.resolution, created: lightFixed + 1 },
    ];
    for (const entry of timeline) {
      await ctx.db.insert("issue_comments", {
        issue_id: entry.issue,
        home_id: homeId,
        author_id: entry.author,
        kind: entry.kind,
        body: entry.body,
        from_status: entry.from,
        to_status: entry.to,
        created: entry.created,
      });
    }

    // --- Chores ------------------------------------------------------------------
    let tapTask: Id<"tasks"> | undefined;
    for (const [i, t] of text.open.entries()) {
      const created = now - (2 + (i % 4)) * DAY;
      const id = await ctx.db.insert("tasks", {
        title: t.title,
        created_by: who((i + 1) % 4),
        updated_by: who((i + 1) % 4),
        assigned_to: t.who === null ? undefined : who(t.who),
        is_completed: false,
        home_id: homeId,
        priority: t.priority,
        type: t.type,
        due_date: at(c, t.due, t.hour),
        issue_id: t.issue ? tapId : undefined,
        created,
        updated: created,
      });
      if (t.issue) tapTask = id;
    }
    if (tapTask) await ctx.db.patch(tapId, { task_id: tapTask, event_id: visitId });
    else await ctx.db.patch(tapId, { event_id: visitId });

    for (const [i, t] of text.done.entries()) {
      // Spread across the day, never in the future, and never at the same
      // instant as another (the Done list sorts by it).
      const hour = 9 + ((i * 5) % 12);
      const completedAt = past(c, at(c, -t.ago, hour, (i * 7) % 60), (i + 1) * 23 * MINUTE);
      const created = completedAt - (1 + (i % 3)) * DAY;
      const taskId = await ctx.db.insert("tasks", {
        title: t.title,
        created_by: who((i + 2) % 4),
        updated_by: who(t.who),
        assigned_to: who(t.who),
        is_completed: true,
        completed_by: who(t.who),
        completed_at: completedAt,
        home_id: homeId,
        priority: "medium",
        type: t.type,
        due_date: created + DAY,
        created,
        updated: completedAt,
      });
      await ctx.db.insert("task_completions", {
        home_id: homeId,
        task_id: taskId,
        user_id: who(t.who),
        title: t.title,
        type: t.type,
        completed_at: completedAt,
      });
    }

    // --- Shopping ------------------------------------------------------------------
    for (const [i, s] of text.shopping.entries()) {
      const created = now - (30 + i * 47) * MINUTE - (i % 3) * DAY;
      const updated = s.bought ? past(c, now - (2 + i) * HOUR) : created;
      await ctx.db.insert("shopping_items", {
        name: s.name,
        quantity: s.quantity,
        is_purchased: s.bought ?? false,
        category: s.category,
        created_by: who(s.by),
        updated_by: s.bought ? who((s.by + 1) % 4) : who(s.by),
        home_id: homeId,
        created,
        updated,
      });
    }
    await ctx.db.insert("shopping_items", {
      name: text.eventItem,
      quantity: 1,
      is_purchased: false,
      category: "groceries",
      created_by: who(1),
      updated_by: who(1),
      home_id: homeId,
      event_id: partyId,
      event_title: text.party.title,
      created: now - 2 * DAY,
      updated: now - 2 * DAY,
    });
    await ctx.db.insert("shopping_items", {
      name: text.issueItem,
      quantity: 2,
      is_purchased: false,
      category: "other",
      created_by: who(3),
      updated_by: who(3),
      home_id: homeId,
      issue_id: tapId,
      issue_title: text.issues.tap.title,
      created: now - 20 * HOUR,
      updated: now - 20 * HOUR,
    });

    // --- Notes -----------------------------------------------------------------------
    for (const n of text.notes) {
      const created = now - n.ago * DAY;
      await ctx.db.insert("notes", {
        description: n.text,
        created_by: who(n.by),
        home_id: homeId,
        created,
        updated: created,
      });
    }

    // --- This week's dinners: Monday to Sunday, tonight included. -------------------
    const toMonday = -((c.dow + 6) % 7);
    for (let i = 0; i < 7; i++) {
      const offset = toMonday + i;
      const date = dateOf(c, offset);
      const plannedBy = who(i % 4);
      const created = now - (7 - i) * HOUR - 2 * DAY;
      // The party's evening first: on a Saturday before it, tonight IS the party.
      if (offset === toSaturday) {
        await ctx.db.insert("meal_plans", {
          home_id: homeId,
          kind: "cook",
          recipe_id: recipe(text.partyMenu[0]),
          date,
          event_id: partyId,
          planned_by: who(1),
          created,
          updated: created,
        });
        continue;
      }
      if (offset === 0) {
        await ctx.db.insert("meal_plans", {
          home_id: homeId,
          kind: "cook",
          recipe_id: recipe(text.tonight),
          date,
          planned_by: who(0),
          created,
          updated: created,
        });
        continue;
      }
      const plan = text.week[i];
      if (plan.kind === "cook") {
        await ctx.db.insert("meal_plans", {
          home_id: homeId,
          kind: "cook",
          recipe_id: recipe(plan.recipe),
          date,
          planned_by: plannedBy,
          created,
          updated: created,
        });
      } else {
        await ctx.db.insert("meal_plans", {
          home_id: homeId,
          kind: plan.kind,
          cuisine: plan.cuisine,
          place: plan.place,
          date,
          planned_by: plannedBy,
          created,
          updated: created,
        });
      }
    }
    // Saturday may be next week; it still gets its party dinner.
    if (toSaturday > 6 + toMonday) {
      await ctx.db.insert("meal_plans", {
        home_id: homeId,
        kind: "cook",
        recipe_id: recipe(text.partyMenu[0]),
        date: dateOf(c, toSaturday),
        event_id: partyId,
        planned_by: who(1),
        created: now - 2 * DAY,
        updated: now - 2 * DAY,
      });
    }

    // --- Films -------------------------------------------------------------------------
    const lists = {
      wishlist: await ctx.db.insert("movie_lists", {
        home_id: homeId, name: text.wishlist, type: "wishlist", is_preset: true, created: now - 120 * DAY, updated: now - 120 * DAY,
      }),
      watched: await ctx.db.insert("movie_lists", {
        home_id: homeId, name: text.watched, type: "watched", is_preset: true, created: now - 120 * DAY, updated: now - 120 * DAY,
      }),
      friday: await ctx.db.insert("movie_lists", {
        home_id: homeId, name: text.friday, type: "custom", is_preset: false, created: now - 30 * DAY, updated: now - 30 * DAY,
      }),
    };
    const file = async (listId: Id<"movie_lists">, ids: string[], daysAgo: number) => {
      for (const [i, id] of ids.entries()) {
        const f = filmOf(id);
        const created = now - (daysAgo - i) * DAY;
        await ctx.db.insert("movies", {
          imdb_id: f.id,
          home_id: homeId,
          list_id: listId,
          title: f.title,
          year: f.year,
          poster: f.poster,
          genres: f.genres,
          created,
          updated: created,
        });
      }
    };
    await file(lists.wishlist, WISHLIST, 12);
    await file(lists.watched, WATCHED, 25);
    await file(lists.friday, FRIDAY, 8);

    // An open round the owner hasn't swiped yet; two films already have two yeses.
    const roundAt = now - 5 * HOUR;
    const pollId = await ctx.db.insert("polls", {
      home_id: homeId,
      owner_id: who(1),
      title: text.round,
      type: "movie",
      status: "active",
      genre: "animation",
      created: roundAt,
      updated: roundAt,
    });
    for (const [i, id] of ROUND.entries()) {
      const f = filmOf(id);
      await ctx.db.insert("poll_items", {
        poll_id: pollId,
        external_id: f.id,
        label: f.title,
        thumbnail_url: f.poster,
        order: i,
        created: roundAt,
        updated: roundAt,
      });
    }
    const ballots: [number, string, boolean][] = [
      [1, "129", true], [1, "4935", true], [1, "8587", false], [1, "354912", true], [1, "10681", true],
      [2, "129", true], [2, "4935", false], [2, "324857", true], [2, "2062", true],
      [3, "129", false], [3, "354912", true], [3, "14160", true], [3, "8587", true],
    ];
    for (const [i, [slot, target, yes]] of ballots.entries()) {
      const votedAt = roundAt + (i + 1) * 7 * MINUTE;
      await ctx.db.insert("poll_votes", {
        poll_id: pollId,
        target_external_id: target,
        vote: yes,
        user_id: who(slot),
        created: votedAt,
        updated: votedAt,
      });
    }

    // --- Money: this month, split four ways. --------------------------------------------
    const monthStart = Date.UTC(c.y, c.m, 1) - tzOffset * MINUTE;
    const sinceMonth = Math.max(now - monthStart - HOUR, HOUR);
    const internetDue = at(c, 2, 12);
    const rentDue = at(c, 16, 12);
    const billReminders = [3, 1, 0];
    const internetId = await ctx.db.insert("bills", {
      home_id: homeId,
      title: text.bills.internet.title,
      amount: text.bills.internet.amount,
      currency: text.currency,
      category: "utilities",
      cycle: "monthly",
      due_date: internetDue,
      responsible: who(2),
      auto_split: true,
      is_archived: false,
      reminders: billReminders,
      reminded: [...billReminders.map((d) => `${internetDue}:${d}`), `${internetDue}:overdue`],
      last_paid_at: monthStart + Math.round(sinceMonth * 0.3),
      created_by: who(2),
      created: now - 90 * DAY,
      updated: now - 5 * DAY,
    });
    await ctx.db.insert("bills", {
      home_id: homeId,
      title: text.bills.rent.title,
      amount: text.bills.rent.amount,
      currency: text.currency,
      category: "rent",
      cycle: "monthly",
      due_date: rentDue,
      responsible: who(0),
      auto_split: true,
      is_archived: false,
      reminders: billReminders,
      reminded: [...billReminders.map((d) => `${rentDue}:${d}`), `${rentDue}:overdue`],
      created_by: who(0),
      created: now - 110 * DAY,
      updated: now - 110 * DAY,
    });

    const evenly = (total: number) => {
      const base = Math.floor(total / people.length);
      const remainder = total - base * people.length;
      return people.map((id, i) => ({ user_id: id, amount: base + (i < remainder ? 1 : 0) }));
    };
    for (const e of text.expenses) {
      const spentAt = monthStart + Math.round(sinceMonth * e.at);
      await ctx.db.insert("expenses", {
        home_id: homeId,
        title: e.title,
        amount: e.amount,
        currency: text.currency,
        category: e.category,
        paid_by: who(e.by),
        splits: evenly(e.amount),
        split_mode: "equal",
        spent_at: spentAt,
        bill_id: e.link === "internet" ? internetId : undefined,
        issue_id: e.link === "tap" ? tapId : e.link === "light" ? lightId : undefined,
        created_by: who(e.by),
        created: spentAt,
        updated: spentAt,
      });
    }
    // This month leaves the owner owing Ayşe/Maya and the others square-ups of
    // their own; the plan finance:summary draws is three transfers, the
    // owner's first.

    // The five months before: the same everyday spending, scaled, payers
    // rotated, each month squared up on the 28th the way finance:summary's
    // plan would, so the history chart has a shape and today's balances are
    // only this month's.
    const step = text.currency === "TRY" ? 1_000 : 10;
    for (const [n, factor] of text.history.entries()) {
      const back = text.history.length - n;
      const start = Date.UTC(c.y, c.m - back, 1) - tzOffset * MINUTE;
      const net = new Map<Id<"users">, number>();
      const bump = (id: Id<"users">, by: number) => net.set(id, (net.get(id) ?? 0) + by);
      for (const e of text.expenses) {
        if (e.link === "tap" || e.link === "light") continue;
        const fixed = e.link === "internet" || e.category === "subscriptions";
        const amount = fixed ? e.amount : Math.round((e.amount * factor) / step) * step;
        const payer = who((e.by + back) % people.length);
        const spentAt = start + Math.floor(e.at * 25) * DAY + 12 * HOUR;
        const splits = evenly(amount);
        bump(payer, amount);
        for (const s of splits) bump(s.user_id, -s.amount);
        await ctx.db.insert("expenses", {
          home_id: homeId,
          title: e.title,
          amount,
          currency: text.currency,
          category: e.category,
          paid_by: payer,
          splits,
          split_mode: "equal",
          spent_at: spentAt,
          bill_id: e.link === "internet" ? internetId : undefined,
          created_by: payer,
          created: spentAt,
          updated: spentAt,
        });
      }
      const squaredAt = start + 27 * DAY + 20 * HOUR;
      const creditors = [...net].filter(([, a]) => a > 0).map(([id, a]) => ({ id, a })).sort((x, y) => y.a - x.a);
      const debtors = [...net].filter(([, a]) => a < 0).map(([id, a]) => ({ id, a: -a })).sort((x, y) => y.a - x.a);
      for (let ci = 0, di = 0; ci < creditors.length && di < debtors.length; ) {
        const take = Math.min(creditors[ci].a, debtors[di].a);
        await ctx.db.insert("settlements", {
          home_id: homeId,
          from_user: debtors[di].id,
          to_user: creditors[ci].id,
          amount: take,
          currency: text.currency,
          note: text.squareUp,
          settled_at: squaredAt,
          created_by: debtors[di].id,
          created: squaredAt,
          updated: squaredAt,
        });
        creditors[ci].a -= take;
        debtors[di].a -= take;
        if (creditors[ci].a === 0) ci++;
        if (debtors[di].a === 0) di++;
      }
    }

    const settledAt = monthStart + Math.round(sinceMonth * 0.5);
    await ctx.db.insert("settlements", {
      home_id: homeId,
      from_user: who(3),
      to_user: who(0),
      amount: text.settlement.amount,
      currency: text.currency,
      note: text.settlement.note,
      settled_at: settledAt,
      created_by: who(3),
      created: settledAt,
      updated: settledAt,
    });
    for (const [category, limit] of [["groceries", text.budgets.groceries], ["dining", text.budgets.dining]] as const) {
      await ctx.db.insert("budgets", {
        home_id: homeId,
        category,
        limit,
        currency: text.currency,
        created_by: who(0),
        created: now - 60 * DAY,
        updated: now - 60 * DAY,
      });
    }

    // --- The group chat --------------------------------------------------------------------
    const lines = text.chat.lines;
    const convoId = await ctx.db.insert("conversations", {
      home_id: homeId,
      participants: people,
      is_group_chat: true,
      title: text.chat.title,
      created: now - 100 * DAY,
      updated: now - lines[lines.length - 1].ago * MINUTE,
    });
    for (const [i, line] of lines.entries()) {
      const sent = now - line.ago * MINUTE;
      // The owner has read all but the last two: a badge, not a backlog.
      const unreadByOwner = i >= lines.length - 2 && line.by !== 0;
      const readBy = unreadByOwner ? people.slice(1) : people;
      await ctx.db.insert("messages", {
        sender_id: who(line.by),
        conversation_id: convoId,
        content: line.text,
        message_type: "text",
        read_by: readBy,
        created: sent,
        updated: sent,
      });
    }
    const last = lines[lines.length - 1];
    await ctx.db.patch(convoId, { last_message: last.text, last_message_at: now - last.ago * MINUTE });

    // --- The bell: a few things that happened, as `inbox.record` files them. --------------
    for (const [i, a] of text.activity.entries()) {
      await ctx.db.insert("home_activity", {
        home_id: homeId,
        category: a.category,
        title: a.title,
        body: a.body,
        actor: who(a.by),
        actor_name: a.by === 0 ? owner.name : text.members[a.by - 1],
        // Unique within the home, as `inbox.record` keeps it.
        created: now - a.ago * MINUTE - i,
      });
    }

    return { homeId, lang: l, name: text.home, memberIds: fakes };
  },
});

// ---------------------------------------------------------------------------
// Nestie: a sunflower already in the album, and a magnolia most of the way up.
//
// Through the companion's own data model: the jar moves through `moveJar`
// (welcome, the first one's stages and graduation), and the one growing is
// credited through `putEntry` — its chores, dinners, the fixed light and the
// house's daily care — then recounted by `recount`, which sets its points and
// pays its stages exactly as a real house's would be.

export const seedNestie = internalMutation({
  args: { homeId: v.id("homes"), lang, tzOffset: v.number() },
  returns: v.object({ points: v.number(), stage: v.number(), leaves: v.number(), sparkles: v.number() }),
  handler: async (ctx, { homeId, lang: l, tzOffset }) => {
    const home = await ctx.db.get(homeId);
    if (!home || home.demo_seed !== seedName(l)) throw new Error("Not a screenshot home");
    const people = home.members;
    const now = Date.now();
    const c = clockFor(now, tzOffset);

    let house = await ensureHouse(ctx, homeId, { region: COPY[l].region, tzOffset });
    if (house.current_id) throw new Error("Nestie is already growing here");

    // The first one: grown and in the album.
    const firstSpecies = "sunflower";
    const growing = "magnolia";
    for (const species of [firstSpecies, growing]) {
      if (!isUsable(standingOfSpecies(species, shopContext(house, now)))) {
        throw new Error(`${species} can't be grown in this house today`);
      }
    }
    const firstStart = at(c, -26, 20);
    const graduatedAt = past(c, at(c, -12, 19, 30));
    const firstId = await ctx.db.insert("companions", {
      home_id: homeId,
      uuid: crypto.randomUUID().toUpperCase(),
      species: firstSpecies,
      seed: `${homeId}-0`,
      started_at: firstStart,
      status: "graduated",
      graduated_at: graduatedAt,
      points: CATALOG.graduateAt,
      paid_stage: stageFor(CATALOG.graduateAt, false),
      tz_offset: tzOffset,
      origin: "server",
      created: firstStart,
      of_age_at: firstStart + 6 * DAY,
      last_care_at: graduatedAt - 2 * HOUR,
      notified: ["ready"],
    });
    await moveJar(ctx, house._id, {
      key: "welcome",
      kind: "welcome",
      leaves: CATALOG.rewards.welcome.leaves,
      sparkles: CATALOG.rewards.welcome.sparkles,
      userId: people[1],
      companionId: firstId,
    });
    await ctx.db.patch(house._id, { welcomed: true });
    for (let n = 1; n <= stageFor(CATALOG.graduateAt, false); n++) {
      await moveJar(ctx, house._id, {
        key: `stage:0:${n}`,
        kind: "stage",
        leaves: CATALOG.rewards.stage.leaves,
        sparkles: CATALOG.rewards.stage.sparkles,
        companionId: firstId,
      });
    }
    await moveJar(ctx, house._id, {
      key: "graduation:0",
      kind: "graduation",
      leaves: CATALOG.rewards.graduation.leaves,
      sparkles: CATALOG.rewards.graduation.sparkles,
      userId: people[0],
      companionId: firstId,
    });
    await ctx.db.patch(house._id, { album_count: 1, grown_species: [firstSpecies], updated: now });

    // The one growing, started the moment the first graduated.
    const currentId = await ctx.db.insert("companions", {
      home_id: homeId,
      uuid: crypto.randomUUID().toUpperCase(),
      species: growing,
      seed: `${homeId}-1`,
      started_at: graduatedAt,
      status: "growing",
      points: 0,
      paid_stage: 0,
      tz_offset: tzOffset,
      origin: "server",
      created: graduatedAt,
      follows: firstId,
      of_age_at: graduatedAt + 6 * DAY,
      last_care_at: now - 2 * HOUR,
    });
    await ctx.db.patch(house._id, { current_id: currentId, updated: now });
    house = (await ctx.db.get(house._id))!;
    let companion = (await ctx.db.get(currentId))!;

    const entries: GrowthEntry[] = [];
    // Chores finished since it arrived, as the live path credits them.
    const completions = await ctx.db
      .query("task_completions")
      .withIndex("by_home_at", (q) => q.eq("home_id", homeId).gte("completed_at", graduatedAt).lte("completed_at", now))
      .take(200);
    for (const row of completions) {
      const task = await ctx.db.get(row.task_id);
      const entry = task ? __growth.choreEntry(task) : null;
      if (entry) entries.push(entry);
    }
    // Dinners decided, counted at 19:00 on their evening, up to yesterday.
    const today = dayOf(now, tzOffset);
    const plans = await ctx.db
      .query("meal_plans")
      .withIndex("by_home_date", (q) => q.eq("home_id", homeId).lt("date", today))
      .take(50);
    for (const plan of plans) {
      entries.push({
        key: `meal:${plan.date}`,
        kind: "dinner",
        at: dayStart(plan.date, tzOffset) + 19 * HOUR,
        userId: plan.planned_by,
        weight: W_DINNER,
        keepAt: true,
      });
    }
    // The light that got fixed.
    const fixed = await ctx.db
      .query("issues")
      .withIndex("by_home_open", (q) => q.eq("home_id", homeId).eq("is_open", false))
      .take(10);
    for (const issue of fixed) {
      if (issue.status !== "fixed" || issue.resolved_at === undefined) continue;
      entries.push({
        key: `fix:${issue._id}`,
        kind: "fix",
        at: issue.resolved_at,
        userId: issue.resolved_by,
        weight: W_FIX[issue.severity] ?? W_FIX.minor,
      });
    }
    // Somebody waters it most days; on some days two or three do.
    const carersByDay = [2, 1, 3, 2, 1, 2, 3, 1, 2, 2, 1, 3];
    for (let ago = 0; ago < carersByDay.length; ago++) {
      for (let k = 0; k < carersByDay[ago]; k++) {
        const slot = (ago + k) % people.length;
        const careAt = past(c, at(c, -ago, 8 + k * 4, 15), (k + 1) * 30 * MINUTE);
        if (careAt < graduatedAt) continue;
        const day = dayOf(careAt, tzOffset);
        entries.push({
          key: `care:${currentId}:${people[slot]}:${day}`,
          kind: "care",
          at: careAt,
          userId: people[slot],
          weight: 1,
          keepAt: true,
        });
      }
    }

    const days: string[] = [];
    for (const entry of entries) {
      days.push(...(await __growth.putEntry(ctx, companion, tzOffset, entry)));
    }
    await __growth.recount(ctx, currentId, house, days);
    companion = (await ctx.db.get(currentId))!;

    // A couple of decorations, bought from the jar like the shop buys them.
    house = (await ctx.db.get(house._id))!;
    for (const decor of ["fairyLights", "terracotta"]) {
      const price = itemPrice({ kind: "decor", id: decor });
      const standing = standingOfDecor(decor, shopContext(house, now));
      if (!price || (standing.type !== "buy" && standing.type !== "sale")) continue;
      const result = checkout({ leaves: house.leaves, sparkles: house.sparkles }, price);
      if (result.type === "short") continue;
      await moveJar(ctx, house._id, {
        key: `buy:demo-${crypto.randomUUID()}`,
        kind: "buy",
        leaves: -result.coins.leaves,
        sparkles: -result.coins.sparkles,
        userId: people[(decor.length % 3) + 1],
        item: `decor:${decor}`,
        madeUp: result.type === "makeUp" ? result.short : undefined,
      });
      house = (await ctx.db.get(house._id))!;
      await ctx.db.patch(house._id, { owned_decor: [...new Set([...house.owned_decor, decor])], updated: now });
      house = (await ctx.db.get(house._id))!;
    }
    const layout = cleanLayout(
      { tree: ["fairyLights"], pot: "terracotta", sky: "windowsill", left: "wateringCan" },
      availableDecor(shopContext(house, now)),
    );
    await ctx.db.patch(house._id, { layout, updated: now });
    house = (await ctx.db.get(house._id))!;

    return {
      points: companion.points,
      stage: companion.paid_stage,
      leaves: house.leaves,
      sparkles: house.sparkles,
    };
  },
});

// ---------------------------------------------------------------------------
// Entry points.

const seedOneResult = v.object({
  homeId: v.id("homes"),
  lang,
  name: v.string(),
  memberIds: v.array(v.id("users")),
  nestie: v.object({ points: v.number(), stage: v.number(), leaves: v.number(), sparkles: v.number() }),
  /** How many of the films came from TMDb just now; the rest used the fallback paths. */
  filmsFromTmdb: v.number(),
});
type SeedOne = Infer<typeof seedOneResult>;

async function seedOne(
  ctx: ActionCtx,
  ownerUserId: Id<"users">,
  l: Lang,
  tzOffset: number,
  resolved: { films: Film[]; live: number },
): Promise<SeedOne> {
  const household = await ctx.runMutation(internal.demo.seedHousehold, {
    ownerUserId,
    lang: l,
    tzOffset,
    films: resolved.films,
  });
  const nestie = await ctx.runMutation(internal.demo.seedNestie, { homeId: household.homeId, lang: l, tzOffset });
  return { ...household, nestie, filmsFromTmdb: resolved.live };
}

/** One screenshot household, in one language. */
export const seedScreenshotHome = internalAction({
  args: { ownerUserId: v.id("users"), lang, tzOffset: v.optional(v.number()) },
  returns: seedOneResult,
  handler: async (ctx, { ownerUserId, lang: l, tzOffset }): Promise<SeedOne> => {
    return await seedOne(ctx, ownerUserId, l, tzOffset ?? 180, await resolveFilms());
  },
});

/** Both screenshot households, Turkish and English, for the same owner. */
export const seedScreenshotHomes = internalAction({
  args: { ownerUserId: v.id("users"), tzOffset: v.optional(v.number()) },
  returns: v.array(seedOneResult),
  handler: async (ctx, { ownerUserId, tzOffset }): Promise<SeedOne[]> => {
    const resolved = await resolveFilms();
    const out: SeedOne[] = [];
    for (const l of ["tr", "en"] as const) {
      out.push(await seedOne(ctx, ownerUserId, l, tzOffset ?? 180, resolved));
    }
    return out;
  },
});

/** Every screenshot household on the deployment, with its members. */
export const listScreenshotHomes = internalQuery({
  args: {},
  returns: v.array(
    v.object({
      homeId: v.id("homes"),
      name: v.union(v.string(), v.null()),
      seed: v.string(),
      members: v.array(v.object({ userId: v.id("users"), name: v.union(v.string(), v.null()), demo: v.boolean() })),
    }),
  ),
  handler: async (ctx) => {
    const homes = await ctx.db
      .query("homes")
      .withIndex("by_demo_seed", (q) => q.gte("demo_seed", ""))
      .take(50);
    return await Promise.all(
      homes.map(async (home) => ({
        homeId: home._id,
        name: home.name ?? null,
        seed: home.demo_seed ?? "",
        members: await Promise.all(
          home.members.map(async (id) => {
            const user = await ctx.db.get(id);
            return { userId: id, name: user?.name ?? null, demo: user?.demo_seed !== undefined };
          }),
        ),
      })),
    );
  },
});

/**
 * Removes a screenshot household through the same path a last member leaving
 * takes (`cascadeDeleteHome`: the home and every member's mirror now, the rest
 * in scheduled batches, Nestie's rows included), then deletes its made-up
 * members. Refuses any home that isn't a screenshot one, and deletes only
 * users marked as made up who belong to no other home.
 */
export const purgeScreenshotHome = internalMutation({
  args: { homeId: v.id("homes") },
  returns: v.object({ deletedUsers: v.array(v.id("users")) }),
  handler: async (ctx, { homeId }) => {
    const home = await ctx.db.get(homeId);
    if (!home) throw new Error("No such home");
    if (!home.demo_seed) throw new Error("Not a screenshot home: refusing to delete a real household");
    const members = home.members;
    await cascadeDeleteHome(ctx, homeId);
    const deletedUsers: Id<"users">[] = [];
    for (const id of members) {
      const user = await ctx.db.get(id);
      if (!user || user.demo_seed === undefined) continue;
      if ((user.home_id ?? []).length > 0) continue;
      await ctx.db.delete(id);
      deletedUsers.push(id);
    }
    return { deletedUsers };
  },
});
