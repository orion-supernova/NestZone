# Xcode Cloud

`./deploy.sh` deploys the backend, syncs the changelog, bumps the build number,
merges `dev` into `stage` and pushes it. **Xcode Cloud does the rest** — build,
sign, upload to TestFlight — and it only does that if a workflow is switched on
and watching `stage`.

This file is the one-time setup, and how to tell whether it worked.

## Where things stand

Xcode Cloud is already provisioned for this app. Xcode's local database has a
product whose id matches `NestZone.xcodeproj/xcshareddata/xcodecloud/manifest.json`,
and a workflow named **Default**. Two things are true about it:

- it is **disabled** (`isEnabled: 0`), and
- it has **never run** (zero builds).

So this is not "set Xcode Cloud up from nothing". It is: point the existing
workflow at the right branch, take the test action off it, and switch it on.

## The setup, once

1. Open `NestZone.xcodeproj` in Xcode.
2. **Product → Xcode Cloud → Manage Workflows…**
3. Select **Default**, then **Edit Workflow**.

### Start Conditions

Delete whatever is there and add one:

| | |
|---|---|
| Condition | **Branch Changes** |
| Repository | `orion-supernova/NestZone` |
| Branch | **`stage`** |
| Files and folders | Start builds for all changes |
| Auto-cancel | On |

`stage` and not `dev`, and this is the whole point of there being two branches:
`dev` moves several times a day and none of those are releases. `stage` moves
exactly once per `./deploy.sh`, so one push is one build is one TestFlight
version — and the branch's log reads as a list of releases rather than a list
of commits.

### Actions

**Remove the Test action.** This project does not run its test suite as part of
shipping, and a workflow that does will block releases on it. Leave one action:

| | |
|---|---|
| Action | **Archive** |
| Scheme | `NestZone` |
| Platform | iOS |
| Deployment Preparation | **TestFlight (Internal Testing Only)** |

Use *TestFlight and App Store* instead only when you want every push to `stage`
to be submittable to review. Internal-only is the safer default: it still gets
the build onto your phone, and it does not create a thing you might
accidentally submit.

### Post-Actions

Optional. **TestFlight Internal Testing** with your internal group means the
build installs on your devices without you going back to look for it. Nothing
else here is needed.

### Environment

Leave it empty. Nothing in this app needs a secret at build time — the Convex
deployment URL is a constant in `ConvexConnection`, and every third-party key
(TMDb, APNs) lives in Convex's environment on the server, never in the app.

## `ci_scripts/` — why the first builds failed

The first Xcode Cloud run failed five times over with variations on:

> Macro "ComposableArchitectureMacros" from package
> "swift-composable-architecture" must be enabled before it can be used

and the same for `swift-perception`, `swift-navigation`, `swift-case-paths` and
`swift-dependencies` — five of the five macro packages this app is built out of.

Nothing was wrong with the code. A Swift macro runs arbitrary code inside the
compiler, so SwiftPM will not execute one until a human has agreed to it, and
it records that agreement as a fingerprint in

```
~/Library/org.swift.swiftpm/security/macros.json
```

The load-bearing character is `~`. That file is **per user, per machine**, and
it is nowhere in this repository — on a laptop Xcode writes it the first time
it shows the "Trust & Enable" sheet, and nobody thinks about it again. Xcode
Cloud is a fresh machine with nobody at the keyboard, so it has no such file
and cannot be asked to make one.

`ci_scripts/ci_post_clone.sh` copies `ci_scripts/macros.json` into place before
anything resolves or builds. That file is this project's answer to the trust
sheet, checked in where it can be read: five named macros at five exact
fingerprints.

It deliberately does **not** set `IDESkipMacroFingerprintValidation`, which is
the usual advice found online and which turns the check off altogether. That
would trust any macro from any dependency, present or future, in the one
environment where nobody is watching the build. An allowlist of five is a list
you can review; a skip flag is a thing nobody revisits.

**It will break again, on purpose.** A fingerprint belongs to a package
*version*, so bumping any of those five changes it and CI starts failing with
the same message. New macro code deserves a fresh look. The fix is one line,
after Xcode has prompted you locally:

```bash
cp ~/Library/org.swift.swiftpm/security/macros.json ci_scripts/macros.json
```

Commit it in the same commit as the `Package.resolved` change that caused it —
they describe the same fact.

**If a build still refuses a macro** after this, the escape hatch is to add
this line to `ci_post_clone.sh`, ship a green build, and then work out why:

```sh
defaults write com.apple.dt.Xcode IDESkipMacroFingerprintValidation -bool YES
```

### Finally

**Enable the workflow.** It is currently off, which is why the manifest has
been sitting in the repo without a single build ever having run.

## Did it work?

```bash
./deploy.sh
```

Then, in Xcode: **Product → Xcode Cloud → Builds**. A build should appear
within a minute or so of the push.

If nothing appears, in order of likelihood:

1. **The workflow is still disabled.** It is off by default and turning it on
   is a separate switch from saving the edits.
2. **It is watching the wrong branch.** A Default workflow usually starts on
   the repository's default branch, which here is `main` — not `stage`.
3. **Xcode Cloud has no access to the repository.** GitHub access is granted
   per-repository; Xcode prompts for it the first time and it is easy to have
   dismissed. App Store Connect → the app → Xcode Cloud → Settings →
   Repositories.
4. **The push did not happen.** `git log origin/stage -1` — if that is not the
   release commit, the push failed and the script would have said so.

## The division of labour

| | Who | Why |
|---|---|---|
| Convex backend | `./deploy.sh`, locally | Xcode Cloud has no Convex deploy key, and should not have one. |
| Changelog sync | `./deploy.sh`, locally | Same deployment, same credentials, same moment. |
| Version + build number | `./deploy.sh`, committed | The number in the binary has to be the number in the repository. |
| `dev` → `stage` merge | `./deploy.sh` | One push per release. |
| Build, sign, upload | **Xcode Cloud** | It signs without this Mac being awake, and it builds only what was pushed. |

That last row is why the script refuses to run with uncommitted changes when it
is releasing. The cloud builds what is on the branch; anything sitting in the
working tree is simply not in the binary, and a build that matches no commit is
one nobody can reproduce later.

## When the cloud is not available

```bash
./deploy.sh --local
```

Archives and uploads from this Mac. It needs `ASC_KEY_ID` and `ASC_ISSUER_ID`
set, with `AuthKey_$ASC_KEY_ID.p8` in `~/.appstoreconnect/private_keys/` (there
are already two keys in there; the issuer id is in App Store Connect → Users
and Access → Integrations → App Store Connect API, and is not recoverable from
the key file).

**Do not run both for one version.** Each path bumps the build number, so you
would end up with two different binaries claiming to be the same release.
