# Deprecations

**One deployment serves every version of the app that exists.**

There is one backend. The phone in your hand is on the newest build; somebody
else's is on the one from March, because they have automatic updates off, or
they are in a country the release has not reached, or the build is still in
review. All of them talk to this deployment, and none of them can be asked to
update first.

So the rule is simple and it has no exceptions:

> **A backend change must not break any app version that is still in use.**
> Add, never remove. Widen, never narrow. Default, never require.

Convex makes the failure mode sharp: argument validation is **strict**, and an
unexpected or missing argument rejects the *whole request*. There is no partial
success and no warning — the screen that called it simply stops working, on a
build you cannot patch.

## What that means in practice

| Change | Safe? | Why |
|---|---|---|
| New table, new index | ✅ | Nothing old queries it. |
| New function | ✅ | Nothing old calls it. |
| New **optional** argument | ✅ | Old clients omit it; the handler defaults. |
| New **required** argument | ❌ | Every existing build is rejected outright. |
| New **optional** schema field | ✅ | Old rows have none; old clients ignore it. |
| New **required** schema field | ❌ | Every existing row fails validation. |
| New field in a **response** | ✅ | Swift decoders ignore unknown keys. |
| Removing a response field | ❌ | Unless every live client decodes it with `decodeIfPresent`. |
| Renaming anything | ❌ | A rename is a removal and an addition. Add the new one, keep the old, retire it here. |
| Adding an enum case | ⚠️ | Safe **because** the client decodes leniently (`decodeLenient`). It degrades one field instead of blanking a screen. Never rely on this without checking the field is decoded that way. |
| Changing what a function *means* | ❌ | Old clients keep calling it expecting the old meaning. Write a new function. |

A rename or a signature change is done in three deploys, never one:

1. **Add** the new thing beside the old one. Both work. Ship an app build that
   uses the new one.
2. **Wait.** Until the census below says nobody needs the old one.
3. **Remove** the old one, and strike its row from the register.

## Is it safe to remove yet?

```bash
cd backend && npx convex run inbox:versionCensus '{}'
```

Every device reports its app version when it registers for notifications — which
already happens once per launch, so it costs nothing extra. The census groups
those by version.

Two things to hold in mind while reading it:

- **`unknown` is the important row.** It counts devices whose build is too old
  to report a version at all. If it is not zero, old clients exist and you do
  not know which.
- **Every number is a floor, not a census.** A device that declined
  notifications never registers, so real usage is higher than this says. A floor
  is the safe direction for a question whose wrong answer breaks somebody's app.

Only remove when the version needing the old surface shows zero devices *and*
`unknown` is zero *and* the newest build has been out long enough that
stragglers have had a chance — a month is a reasonable default.

## The register

Every deliberate deprecation gets a row here, in the same commit that
deprecates it. A row without a removal condition is not a deprecation, it is a
wish.

| What | Deprecated in | Replaced by | Remove when | Steps |
|---|---|---|---|---|
| `inbox:activity` accepting `category: null` | 1.9.1 | the key being absent | `versionCensus` shows no devices on 1.9.0, and `unknown` is 0 | Change the validator back to `v.optional(v.string())` and drop the `?? undefined` in the handler. |

### Row format

- **What** — the exact function, argument or field. Name it so somebody can
  grep for it.
- **Deprecated in** — the app version whose build stopped needing it.
- **Replaced by** — what to use instead, or "nothing" if it is simply gone.
- **Remove when** — the condition, checkable against the census. Not a date.
- **Steps** — what removing it actually involves, written now while it is
  fresh, not in eight months by somebody reconstructing it.

## Notes on what is already here

The row above is what this rule looks like when it is actually load-bearing.
1.9.0 shipped a client that sends `category: null` to `inbox:activity` — a
Swift dictionary written as `["category": value?.rawValue]` puts the key in
with a nil value rather than leaving it out — and Convex rejects null against
`v.optional`. Every unfiltered read of the feed was refused and the panel
showed an error the instant it opened.

The client is fixed in 1.9.1. The tempting response is to leave the validator
strict, since the bug is on the client — but the fix only reaches a phone when
a *build* does, and this deployment serves the build that is on people's phones
right now. So the validator was widened to accept both spellings, which fixed
every installed copy without anybody updating anything, and the narrowing is
recorded above as work to do once nobody needs it.

Two more things are worth knowing about because they are instances of the rule
rather than exceptions to it:

- **`push:registerDevice` takes `appVersion` as optional, and it must stay
  optional.** Every build already on a phone calls this mutation without it.
  Making it required would break notification registration for every device
  that has not updated — which is precisely the class of failure this document
  exists to prevent.
- **`home_activity.category` is a free string, not a union.** Twelve modules
  supply it, and a validator would mean that adding a thirteenth makes the
  *recording* throw. The client decodes it leniently and falls back to `other`.
