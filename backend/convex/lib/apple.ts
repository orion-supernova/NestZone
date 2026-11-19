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

import { createRemoteJWKSet, importPKCS8, jwtVerify, SignJWT } from "jose";

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

// MARK: - Revoking (account deletion)
//
// App Store Guideline 5.1.1(v): an app offering Sign in with Apple must revoke
// the user's tokens when they delete their account. The app hands over a
// fresh `authorizationCode` from a re-authorization; it is exchanged here for
// a refresh token, which is then revoked, and Apple stops listing the app
// under the person's "Sign in with Apple" settings.
//
// Configure the deployment once (a Sign in with Apple key from the Developer
// portal; not the APNs key, though the shape is the same):
//   npx convex env set SIWA_KEY_ID   <10-char key id>
//   npx convex env set SIWA_TEAM_ID  <10-char team id>
//   npx convex env set -- SIWA_PRIVATE_KEY "$(cat AuthKey_XXXXXXXXXX.p8)"

const APPLE_TOKEN_URL = "https://appleid.apple.com/auth/token";
const APPLE_REVOKE_URL = "https://appleid.apple.com/auth/revoke";

/** Whether this deployment can revoke at all. */
export function canRevokeApple(): boolean {
  return Boolean(
    process.env.SIWA_KEY_ID && process.env.SIWA_TEAM_ID && process.env.SIWA_PRIVATE_KEY,
  );
}

/**
 * Exchanges a native authorization code and revokes what it yields.
 *
 * Returns whether Apple confirmed the revocation. Answers from Apple are
 * returned as false, not thrown — a deletion must not hinge on a third party —
 * and neither the code nor a token is ever logged.
 */
export async function revokeAppleAuthorization(code: string): Promise<boolean> {
  if (!canRevokeApple()) return false;
  // The audience of a native token is the bundle id, so that is the client.
  const clientId = process.env.APNS_BUNDLE_ID || APPLE_AUDIENCE;

  // The client secret is an ES256 JWT, signed the way push.ts signs for APNs.
  const key = await importPKCS8(process.env.SIWA_PRIVATE_KEY!, "ES256");
  const clientSecret = await new SignJWT({})
    .setProtectedHeader({ alg: "ES256", kid: process.env.SIWA_KEY_ID! })
    .setIssuer(process.env.SIWA_TEAM_ID!)
    .setIssuedAt()
    .setExpirationTime("5m")
    .setAudience(APPLE_ISSUER)
    .setSubject(clientId)
    .sign(key);

  const form = (fields: Record<string, string>) => ({
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams(fields).toString(),
  });

  const exchanged = await fetch(
    APPLE_TOKEN_URL,
    form({
      client_id: clientId,
      client_secret: clientSecret,
      code,
      grant_type: "authorization_code",
    }),
  );
  if (!exchanged.ok) {
    // `invalid_grant` is the usual one: a code is single-use and lives five
    // minutes. The body is Apple's error name, never a credential.
    console.warn(`Sign in with Apple code exchange: ${exchanged.status} ${await exchanged.text()}`);
    return false;
  }
  const tokens = (await exchanged.json()) as { refresh_token?: string; access_token?: string };
  const token = tokens.refresh_token ?? tokens.access_token;
  if (!token) return false;

  const revoked = await fetch(
    APPLE_REVOKE_URL,
    form({
      client_id: clientId,
      client_secret: clientSecret,
      token,
      token_type_hint: tokens.refresh_token ? "refresh_token" : "access_token",
    }),
  );
  if (!revoked.ok) {
    console.warn(`Sign in with Apple revoke: ${revoked.status} ${await revoked.text()}`);
    return false;
  }
  return true;
}
