// TMDb proxy.
//
// The iOS client used to hold the TMDb API key as a string literal in
// `MovieAPI.swift` and call api.themoviedb.org directly. A key compiled into an
// app binary is readable by anyone who downloads the app — `strings` on the
// binary is enough — so it was effectively public and attributable to this
// account. It now lives in the Convex deployment environment and never leaves
// the server:
//
//     npx convex env set TMDB_API_KEY <key>
//
// Rotate the old key: it is in the git history and in every build already
// shipped.
//
// This also fixes two client-side inefficiencies. Multi-page discovery fetched
// pages 1..3 sequentially, so a genre browse cost three round trips end to end;
// here they are fetched in parallel. And de-duplication was an O(n²)
// `contains(where:)` scan per inserted movie; here it is a Set.

import { action } from "./_generated/server";
import { v } from "convex/values";
import { getAuthUserId } from "@convex-dev/auth/server";
import { ActionCtx } from "./_generated/server";

const BASE = "https://api.themoviedb.org/3";
const PAGES = 3;

/**
 * The fewest TMDb votes a film needs to be worth putting in front of a
 * household.
 *
 * `sort_by=popularity.desc` orders what it is given but filters nothing, so a
 * narrow round scraped the bottom of the catalogue to fill three pages: a 1937
 * round came back 43-of-60 films with under fifty votes, thirteen of them with
 * no poster at all, and a household deciding between *It Happened One Night*
 * and a one-vote obscurity with a blank card is not deciding anything. A floor
 * of twenty still leaves 1937 with 109 films and the 1930s with 1117 — far
 * more than a thirty-card deck needs — while removing the noise. A shorter
 * deck of real films beats a full one padded out.
 */
const MIN_VOTES = 20;

const GENRES: Record<string, number> = {
  action: 28, adventure: 12, animation: 16, comedy: 35, crime: 80,
  documentary: 99, drama: 18, family: 10751, fantasy: 14, history: 36,
  horror: 27, music: 10402, mystery: 9648, romance: 10749, "sci-fi": 878,
  thriller: 53, war: 10752, western: 37,
};

/** Actions have no `ctx.db`, so the `requireUser` helper (which reads the user
 *  document) does not apply here. The identity check is all we need. */
async function requireSignedIn(ctx: ActionCtx): Promise<void> {
  const uid = await getAuthUserId(ctx);
  if (!uid) throw new Error("Not authenticated");
}

function apiKey(): string {
  const key = process.env.TMDB_API_KEY;
  if (!key) {
    throw new Error(
      "TMDB_API_KEY is not set on this deployment. " +
        "Run: npx convex env set TMDB_API_KEY <key>",
    );
  }
  return key;
}

function url(path: string, params: Record<string, string | number | boolean>): string {
  const search = new URLSearchParams({ api_key: apiKey() });
  for (const [k, value] of Object.entries(params)) search.set(k, String(value));
  return `${BASE}${path}?${search.toString()}`;
}

type TMDbMovie = {
  id: number;
  title?: string;
  name?: string;
  release_date?: string;
  poster_path?: string | null;
  genre_ids?: number[];
  genres?: { id: number; name: string }[];
};

/** A film as it appears under a person, which is the only place the job and
 *  the popularity that `/discover/movie` sorts by are both available. */
type TMDbCredit = TMDbMovie & {
  job?: string;
  adult?: boolean;
  popularity?: number;
};

const GENRE_NAMES: Record<number, string> = Object.fromEntries(
  Object.entries(GENRES).map(([name, id]) => [id, name]),
);

/** TMDb's shape → the app's `Movie`. */
function toMovie(raw: TMDbMovie) {
  const year = raw.release_date ? Number(raw.release_date.slice(0, 4)) : undefined;
  const genres = raw.genres
    ? raw.genres.map((g) => g.name.toLowerCase())
    : (raw.genre_ids ?? []).map((id) => GENRE_NAMES[id]).filter(Boolean);
  return {
    id: String(raw.id),
    title: raw.title ?? raw.name ?? "",
    year: Number.isFinite(year) ? year : undefined,
    poster: raw.poster_path ?? undefined,
    genres,
  };
}

async function fetchJSON(target: string): Promise<any> {
  const response = await fetch(target);
  if (!response.ok) {
    throw new Error(`TMDb ${response.status}`);
  }
  return await response.json();
}

/** Fetches `PAGES` pages at once and de-duplicates by id, preserving order. */
async function fetchPages(
  path: string,
  params: Record<string, string | number | boolean>,
): Promise<ReturnType<typeof toMovie>[]> {
  const pages = await Promise.all(
    Array.from({ length: PAGES }, (_, i) =>
      fetchJSON(url(path, { ...params, page: i + 1 })).catch(() => ({ results: [] })),
    ),
  );

  const seen = new Set<string>();
  const movies: ReturnType<typeof toMovie>[] = [];
  for (const page of pages) {
    for (const raw of (page.results ?? []) as TMDbMovie[]) {
      const movie = toMovie(raw);
      // A card is a poster and a title. Without the poster there is nothing to
      // swipe on, so an entry missing one is not a candidate — it is a gap
      // being counted as one.
      if (!movie.title || !movie.poster || seen.has(movie.id)) continue;
      seen.add(movie.id);
      movies.push(movie);
    }
  }
  return movies;
}

/**
 * One entry point for every way the app browses the catalogue. A single action
 * keeps the client's dependency surface to two functions instead of twelve.
 */
export const discover = action({
  args: {
    kind: v.union(
      v.literal("search"),
      v.literal("genre"),
      v.literal("year"),
      v.literal("decade"),
      v.literal("actor"),
      v.literal("director"),
      v.literal("popular"),
      v.literal("topRated"),
      v.literal("nowPlaying"),
      v.literal("upcoming"),
    ),
    query: v.optional(v.string()),
    year: v.optional(v.number()),
    includeAdult: v.optional(v.boolean()),
  },
  handler: async (ctx, args) => {
    // Signed-in users only: this action spends our TMDb quota.
    await requireSignedIn(ctx);
    const includeAdult = args.includeAdult ?? false;
    const sortBy = "popularity.desc";

    switch (args.kind) {
      case "search": {
        const q = (args.query ?? "").trim();
        if (!q) return await fetchPages("/movie/popular", { include_adult: includeAdult });
        const data = await fetchJSON(
          url("/search/movie", { query: q, include_adult: includeAdult }),
        );
        return ((data.results ?? []) as TMDbMovie[]).map(toMovie).filter((m) => m.title);
      }

      case "genre": {
        const id = GENRES[(args.query ?? "").toLowerCase()];
        if (!id) {
          const data = await fetchJSON(
            url("/search/movie", { query: args.query ?? "", include_adult: includeAdult }),
          );
          return ((data.results ?? []) as TMDbMovie[]).map(toMovie).filter((m) => m.title);
        }
        return await fetchPages("/discover/movie", {
          with_genres: id, include_adult: includeAdult, sort_by: sortBy,
          "vote_count.gte": MIN_VOTES,
        });
      }

      case "year":
        return await fetchPages("/discover/movie", {
          primary_release_year: args.year ?? new Date().getFullYear(),
          include_adult: includeAdult, sort_by: sortBy,
          "vote_count.gte": MIN_VOTES,
        });

      case "decade": {
        const start = args.year ?? 2020;
        return await fetchPages("/discover/movie", {
          "primary_release_date.gte": `${start}-01-01`,
          "primary_release_date.lte": `${start + 9}-12-31`,
          include_adult: includeAdult, sort_by: sortBy,
          "vote_count.gte": MIN_VOTES,
        });
      }

      case "actor":
      case "director": {
        const people = await fetchJSON(
          url("/search/person", { query: (args.query ?? "").trim() }),
        );
        const person = (people.results ?? [])[0];
        if (!person) return [];

        if (args.kind === "actor") {
          return await fetchPages("/discover/movie", {
            with_cast: person.id, include_adult: includeAdult, sort_by: sortBy,
            "vote_count.gte": MIN_VOTES,
          });
        }

        // `with_crew` matches *any* crew credit, so a director's round filled
        // out with films they only produced: a Sam Raimi deck ran out of films
        // he directed after a dozen and then went on for another fifty of the
        // horror he lent his name to. The person's own credits carry the job,
        // so the round can be exactly what they directed. Three pages of
        // near-misses is not worth one wrong card — a short deck of the right
        // films is the answer, however short it comes out.
        const credits = await fetchJSON(url(`/person/${person.id}/movie_credits`, {}));
        const seen = new Set<string>();
        return ((credits.crew ?? []) as TMDbCredit[])
          .filter((raw) => raw.job === "Director")
          .filter((raw) => includeAdult || !raw.adult)
          // Student shorts and unreleased projects sit in a director's credits
          // with no artwork. They are correctly theirs and still not cards.
          .filter((raw) => raw.poster_path)
          // `movie_credits` comes back in no useful order; every other round is
          // richest first.
          .sort((a, b) => (b.popularity ?? 0) - (a.popularity ?? 0))
          .map(toMovie)
          // One film can carry two directing credits for the same person.
          .filter((movie) => {
            if (!movie.title || !movie.poster || seen.has(movie.id)) return false;
            seen.add(movie.id);
            return true;
          });
      }

      case "popular":
        return await fetchPages("/movie/popular", { include_adult: includeAdult });
      case "topRated":
        return await fetchPages("/movie/top_rated", { include_adult: includeAdult });
      case "nowPlaying":
        return await fetchPages("/movie/now_playing", { include_adult: includeAdult });
      case "upcoming":
        return await fetchPages("/movie/upcoming", { include_adult: includeAdult });
    }
  },
});

/**
 * Full detail for one movie: the base fields plus everything the detail sheet
 * shows. Credits and keywords come back in the same request via
 * `append_to_response`, which the client used to fetch separately.
 */
export const details = action({
  args: { tmdbId: v.string() },
  handler: async (ctx, { tmdbId }) => {
    await requireSignedIn(ctx);
    const data = await fetchJSON(
      url(`/movie/${tmdbId}`, { append_to_response: "credits,keywords" }),
    );

    const crew = data.credits?.crew ?? [];
    return {
      movie: toMovie(data),
      extras: {
        plot: data.overview || undefined,
        cast: (data.credits?.cast ?? []).slice(0, 12).map((c: any) => ({
          name: c.name,
          character: c.character || undefined,
          profilePath: c.profile_path ?? undefined,
        })),
        directors: crew.filter((c: any) => c.job === "Director").map((c: any) => c.name),
        writers: crew
          .filter((c: any) => c.department === "Writing")
          .map((c: any) => c.name)
          .slice(0, 5),
        runtimeMinutes: data.runtime ?? undefined,
        rating: data.vote_average ?? undefined,
        voteCount: data.vote_count ?? undefined,
        budget: data.budget || undefined,
        revenue: data.revenue || undefined,
        releaseDate: data.release_date || undefined,
        originalLanguage: data.original_language || undefined,
        productionCompanies: (data.production_companies ?? []).map((c: any) => c.name),
        keywords: (data.keywords?.keywords ?? []).map((k: any) => k.name).slice(0, 12),
        backdropPath: data.backdrop_path ?? undefined,
      },
    };
  },
});
