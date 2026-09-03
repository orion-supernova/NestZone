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
});
