// Convex Auth — "Sign in with Apple" ONLY.
//
// Email/password sign-in was removed deliberately: it made the app responsible
// for storing and verifying secrets, and on this self-hosted deployment the
// provider's default hashing (pure-JS Lucia scrypt, run inside a mutation) could
// not even complete within Convex's 1-second mutation budget. Apple verifies the
// user for us and we only ever store an opaque identifier.
//
// There is no sign-up flow and no password: the same button covers first and
// subsequent sign-ins. Accounts are keyed on Apple's `sub` (stable per-app user
// id), which is the only claim present on EVERY sign-in — Apple returns the
// email and name just once, at the first authorization.

import { ConvexCredentials } from "@convex-dev/auth/providers/ConvexCredentials";
import { convexAuth, createAccount, retrieveAccount } from "@convex-dev/auth/server";
import { verifyAppleIdentityToken } from "./lib/apple";

const APPLE_PROVIDER_ID = "apple";

const AppleIdToken = ConvexCredentials({
  id: APPLE_PROVIDER_ID,
  authorize: async (credentials, ctx) => {
    const identityToken = credentials.identityToken;
    if (typeof identityToken !== "string" || identityToken.length === 0) {
      throw new Error("Missing Apple identity token");
    }

    // Throws if the signature, issuer, audience or expiry is wrong, so an
    // attacker cannot mint their own token or replay one from another app.
    const identity = await verifyAppleIdentityToken(identityToken);

    // Apple only sends the display name alongside the FIRST authorization, and
    // not inside the token, so the client forwards it as a separate param.
    const displayName =
      typeof credentials.name === "string" && credentials.name.trim().length > 0
        ? credentials.name.trim()
        : undefined;

    // Returning user: an account already exists for this Apple subject.
    try {
      const { user } = await retrieveAccount(ctx, {
        provider: APPLE_PROVIDER_ID,
        account: { id: identity.subject },
      });
      return { userId: user._id };
    } catch {
      // No account yet — fall through and create one.
    }

    const { user } = await createAccount(ctx, {
      provider: APPLE_PROVIDER_ID,
      account: { id: identity.subject },
      profile: {
        email: identity.email,
        name: displayName,
        // Surfaced so createOrUpdateUser below can see Apple's verdict.
        emailVerified: identity.emailVerified && !identity.isPrivateRelay,
      } as any,
      // Safe only because Apple has verified the address itself. Never link on a
      // private-relay address: those are per-app aliases, so matching one to an
      // existing profile would be meaningless.
      shouldLinkViaEmail:
        identity.emailVerified && !identity.isPrivateRelay && !!identity.email,
    });
    return { userId: user._id };
  },
});

export const { auth, signIn, signOut, store, isAuthenticated } = convexAuth({
  providers: [AppleIdToken],
  callbacks: {
    /**
     * Adopt an existing profile with the same email instead of creating a second
     * one for the same person.
     *
     * The library will not do this on its own: its linking path goes through
     * `uniqueUserWithVerifiedEmail`, which only matches users that already carry
     * `emailVerificationTime`. Any user created outside this flow — the accounts
     * imported from PocketBase, for instance — has no such marker, so signing in
     * with Apple silently produced a SECOND user on the same address and the
     * person lost their homes and history.
     *
     * We link only when Apple itself verified the address and it is not a
     * private-relay alias (relay addresses are per-app, so matching on one would
     * be meaningless). We also stamp `emailVerificationTime` on the way through,
     * so the library's own linking works from then on.
     */
    async createOrUpdateUser(ctx, args) {
      // Re-login or token refresh on a known account.
      if (args.existingUserId) return args.existingUserId;

      const email = args.profile.email as string | undefined;
      const name = args.profile.name as string | undefined;
      const linkable = args.shouldLinkViaEmail === true;

      if (email && linkable) {
        const existing = await ctx.db
          .query("users")
          .withIndex("email", (q) => q.eq("email", email))
          .first();
        if (existing) {
          const patch: Record<string, unknown> = {};
          if (!existing.name && name) patch.name = name;
          if (!(existing as any).emailVerificationTime) {
            patch.emailVerificationTime = Date.now();
          }
          if (Object.keys(patch).length > 0) {
            await ctx.db.patch(existing._id, patch as any);
          }
          return existing._id;
        }
      }

      return await ctx.db.insert("users", {
        email,
        name,
        emailVerificationTime: email && linkable ? Date.now() : undefined,
      } as any);
    },
  },
});
