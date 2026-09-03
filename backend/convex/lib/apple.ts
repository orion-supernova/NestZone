// Verification for native "Sign in with Apple" identity tokens.
//
// The iOS app uses ASAuthorizationAppleIDProvider, which hands the client a
// signed JWT (the identity token) — there is no browser redirect and no OAuth
// callback, which matters here because this self-hosted deployment only proxies
// /.well-known/* to the HTTP-actions origin (see the runbook's tunnel section),
// so the redirect-based OAuth routes would not be reachable anyway.
//
// We verify the token the way Apple documents it:
//   - RS256 signature against Apple's published JWKS
//   - iss === https://appleid.apple.com
//   - aud === our bundle id (the audience for a NATIVE app is the bundle id,
//     not a Services ID — that only applies to the web flow)
//   - not expired
//
// `sub` is Apple's stable, per-app user id and is the ONLY value present on
// every sign-in. Apple returns `email` and the user's name ONLY on the very
// first authorization, so accounts are keyed on `sub`, never on email.

import { createRemoteJWKSet, jwtVerify } from "jose";

const APPLE_ISSUER = "https://appleid.apple.com";
const APPLE_JWKS_URL = new URL("https://appleid.apple.com/auth/keys");

/** Audience of a native Sign in with Apple token = the app's bundle id. */
export const APPLE_AUDIENCE = "com.walhallaa.NestZone";

// jose caches the fetched key set and only refetches when it sees an unknown
// `kid`, so this does not hit Apple on every sign-in.
const jwks = createRemoteJWKSet(APPLE_JWKS_URL);

export type AppleIdentity = {
  /** Apple's stable per-app user id. Always present. */
  subject: string;
  /** Only supplied on the first authorization, and may be a private relay address. */
  email?: string;
  emailVerified: boolean;
  /** True when the address is an Apple "Hide My Email" relay. */
  isPrivateRelay: boolean;
};

export async function verifyAppleIdentityToken(
  identityToken: string,
): Promise<AppleIdentity> {
  const { payload } = await jwtVerify(identityToken, jwks, {
    issuer: APPLE_ISSUER,
    audience: APPLE_AUDIENCE,
    algorithms: ["RS256"],
  });

  const subject = typeof payload.sub === "string" ? payload.sub : "";
  if (!subject) throw new Error("Apple token has no subject");

  const email = typeof payload.email === "string" ? payload.email : undefined;
  // Apple sends these as either booleans or the strings "true"/"false".
  const asBool = (v: unknown) => v === true || v === "true";

  return {
    subject,
    email,
    emailVerified: asBool(payload.email_verified),
    isPrivateRelay: asBool(payload.is_private_email),
  };
}
