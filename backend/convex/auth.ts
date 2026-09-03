// Convex Auth setup — email/password, with automatic linking to migrated
// PocketBase profiles by email.
//
// THE KEY BEHAVIOUR: your 7 existing users have a `users` doc (with email,
// pbId, home_id, ...) but NO auth account (bcrypt hashes can't be reused).
// When such a user signs up again with the SAME email, `createOrUpdateUser`
// finds their migrated doc and binds the new password account to it, so they
// keep their home, messages, votes, etc. New emails create a fresh user.

import { Password } from "@convex-dev/auth/providers/Password";
import { convexAuth } from "@convex-dev/auth/server";

export const { auth, signIn, signOut, store, isAuthenticated } = convexAuth({
  providers: [Password],
  callbacks: {
    async createOrUpdateUser(ctx, args) {
      // Existing authenticated user (e.g. re-login / token refresh): keep it.
      if (args.existingUserId) {
        return args.existingUserId;
      }

      const email = args.profile.email as string | undefined;
      const name = args.profile.name as string | undefined;

      // Link to a migrated profile with the same email, if present.
      if (email) {
        const migrated = await ctx.db
          .query("users")
          .withIndex("email", (q) => q.eq("email", email))
          .first();
        if (migrated) {
          // Optionally backfill a display name if the profile had none.
          if (!migrated.name && name) {
            await ctx.db.patch(migrated._id, { name });
          }
          return migrated._id;
        }
      }

      // Brand new user.
      return await ctx.db.insert("users", { email, name });
    },
  },
});
