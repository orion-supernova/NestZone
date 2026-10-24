// The shape of the generated companion catalog (`companionData.ts`).
//
// Mirrors the Swift types it is exported from — `Access`, `Price`, `Season`,
// `Reward`, `Holiday` — one for one, so a reader of either can find the other.

export type Currency = "leaves" | "sparkles";

export type Price = { currency: Currency; amount: number };

export type Season = { months: number[]; followsNature: boolean };

export type Reward =
  | { type: "graduations"; count: number }
  | { type: "birthday" }
  | { type: "grownAll" };

export type Access =
  | { type: "free" }
  | { type: "buy"; price: Price }
  | { type: "pack"; pack: string }
  | { type: "season"; season: Season }
  | { type: "holiday" }
  | { type: "holidaySale"; price: Price }
  | { type: "seasonSale"; price: Price; season: Season }
  | { type: "reward"; reward: Reward };

export type DecorKind = "above" | "sky" | "weather" | "tree" | "wearing" | "pot" | "floor" | "ground";

export type CatalogHoliday = {
  id: string;
  family: string;
  /** Whether it puts its things on sale: a faith's days bring free things only. */
  sells: boolean;
  days: number;
  lead: number;
  /** `Decor.rawValue`s: a `DecorItem` id, or `flags.<holiday>`. */
  decor: string[];
  /** Region ("*" for everywhere else) → year → first day, `YYYY-MM-DD`. */
  starts: Record<string, Record<string, string>>;
};

export type CatalogData = {
  graduateAt: number;
  stages: { plant: number[]; pet: number[] };
  rewards: {
    stage: { leaves: number; sparkles: number };
    graduation: { leaves: number; sparkles: number };
    welcome: { leaves: number; sparkles: number };
  };
  leavesPerSparkle: number;
  treeLimit: number;
  species: { id: string; isPet: boolean; access: Access }[];
  freeToHave: string[];
  decor: { id: string; kind: DecorKind; wintry: boolean; access: Access }[];
  packs: { id: string; price: Price; species: string[] }[];
  sparklePacks: { id: string; sparkles: number }[];
  holidays: CatalogHoliday[];
  /** Region ("*" for the rest) → the holidays a house there keeps by default. */
  holidayDefaults: Record<string, string[]>;
  southern: string[];
  spotsForPets: string[];
};
