#!/usr/bin/env bash
#
# Ship NestZone.
#
#   ./deploy.sh                 # backend, changelog, version, merge to stage, push
#   ./deploy.sh --backend       # backend + changelog only, no release
#   ./deploy.sh --bump patch    # 1.9.0 -> 1.9.1 first, then the lot
#   ./deploy.sh --local         # archive and upload from this Mac instead
#   ./deploy.sh --dry-run       # say what would happen, touch nothing
#
# WHO BUILDS THE APP
#
# Xcode Cloud does, and this script does not. It takes the release as far as a
# pushed `stage` branch and stops; Apple's builders take it from there, sign it
# and send it to TestFlight. Two reasons that division is the right one and not
# just a convenience:
#
#   - Convex cannot deploy from Xcode Cloud (it has no deploy key there, and
#     should not), and Xcode Cloud is the only one of the two that can sign a
#     build without this particular Mac being awake with the right identities
#     in its keychain. Each side does the half only it can do.
#   - Xcode Cloud builds what was *pushed*. That makes "you cannot ship
#     uncommitted work" a property of the pipeline rather than a warning this
#     script prints and you dismiss.
#
# `--local` is the fallback for when the cloud is queued or unavailable. It
# needs ASC_KEY_ID and ASC_ISSUER_ID (see the upload step). Do not run both for
# one version: each bumps the build number, so you would end up with two
# different binaries claiming to be the same release.
#
# ORDER, AND WHY IT IS THIS ONE
#
# Backend first, always. A new app build needs backend functions that only a
# new backend has; an old app build must keep working against that same backend
# (see backend/DEPRECATIONS.md). Deploy the backend first and both are true at
# every moment in between. Ship the app first and there is a window — minutes
# if it goes well, a week if review is slow — where the newest build on a phone
# is calling functions that do not exist.
#
# Everything here is re-runnable. `convex deploy` is idempotent, the changelog
# sync is idempotent by slug, and a failed push can simply be run again.

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"
ROOT="$PWD"
BACKEND="$ROOT/backend"

SCHEME="NestZone"
PROJECT="$ROOT/NestZone.xcodeproj"
PBXPROJ="$PROJECT/project.pbxproj"
BUILD_DIR="$ROOT/build"
ARCHIVE="$BUILD_DIR/$SCHEME.xcarchive"
EXPORT_DIR="$BUILD_DIR/export"
SIM_DESTINATION="platform=iOS Simulator,name=iPhone 17"

# Where work happens, and what Xcode Cloud watches. `stage` is not a second
# copy of the code — it is a pointer at the commit that is being released, and
# the only thing that ever moves it is this script.
WORK_BRANCH="dev"
RELEASE_BRANCH="stage"
REMOTE="origin"

DO_BACKEND=1
DO_RELEASE=1
BUILD_WHERE="cloud"
DRY_RUN=0
BUMP=""

# Set on the way in so the trap can put things back.
STARTING_BRANCH=""

# ---------------------------------------------------------------- output ----

bold() { printf "\033[1m%s\033[0m\n" "$*"; }
step() { printf "\n\033[1;36m==>\033[0m \033[1m%s\033[0m\n" "$*"; }
info() { printf "    %s\n" "$*"; }
warn() { printf "\033[33m    ! %s\033[0m\n" "$*"; }
die()  { printf "\n\033[31m✗ %s\033[0m\n" "$*" >&2; exit 1; }

run() {
  if [[ $DRY_RUN == 1 ]]; then
    printf "\033[2m    would run: %s\033[0m\n" "$*"
    return 0
  fi
  "$@"
}

# Whatever happens — a conflict, a refused push, a Ctrl-C — end up back on the
# branch the work is done on. A script that leaves somebody on `stage` without
# saying so is one that gets a day's work committed to the wrong place.
restore_branch() {
  local code=$?
  if [[ -n "$STARTING_BRANCH" && $DRY_RUN == 0 ]]; then
    local now
    now="$(git -C "$ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
    if [[ "$now" != "$STARTING_BRANCH" ]]; then
      git -C "$ROOT" checkout -q "$STARTING_BRANCH" 2>/dev/null \
        && printf "\033[2m    (back on %s)\033[0m\n" "$STARTING_BRANCH"
    fi
  fi
  exit $code
}
trap restore_branch EXIT INT TERM

# ------------------------------------------------------------------ args ----

while [[ $# -gt 0 ]]; do
  case "$1" in
    --backend)   DO_RELEASE=0 ;;
    --local)     BUILD_WHERE="local" ;;
    --cloud)     BUILD_WHERE="cloud" ;;
    --dry-run)   DRY_RUN=1 ;;
    --bump)      BUMP="${2:-}"; shift ;;
    -h|--help)   sed -n '2,45p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)           die "Unknown option: $1 (try --help)" ;;
  esac
  shift
done

if [[ -n "$BUMP" && ! "$BUMP" =~ ^(major|minor|patch)$ ]]; then
  die "--bump takes major, minor or patch"
fi

# ----------------------------------------------------------- the version ----

marketing_version() {
  # The first MARKETING_VERSION in the file is the app target's. The others
  # belong to the test bundles and are all 1.0, which is why this takes one
  # rather than the set.
  grep -m1 -E 'MARKETING_VERSION = ' "$PBXPROJ" \
    | sed -E 's/.*MARKETING_VERSION = ([^;]+);.*/\1/' | tr -d ' '
}

build_number() {
  grep -m1 -E 'CURRENT_PROJECT_VERSION = ' "$PBXPROJ" \
    | sed -E 's/.*CURRENT_PROJECT_VERSION = ([^;]+);.*/\1/' | tr -d ' '
}

# `sed` over the pbxproj rather than agvtool, which rewrites both the project
# and the Info.plists and then disagrees with this project's build settings
# about which one is the truth.
set_marketing_version() {
  run /usr/bin/sed -i '' "s/MARKETING_VERSION = ${1};/MARKETING_VERSION = ${2};/g" "$PBXPROJ"
}

set_build_number() {
  run /usr/bin/sed -i '' -E "s/CURRENT_PROJECT_VERSION = [^;]+;/CURRENT_PROJECT_VERSION = ${1};/g" "$PBXPROJ"
}

bump_version() {
  local major minor patch
  IFS=. read -r major minor patch <<< "$1"
  major=${major:-0}; minor=${minor:-0}; patch=${patch:-0}
  case "$2" in
    major) major=$((major + 1)); minor=0; patch=0 ;;
    minor) minor=$((minor + 1)); patch=0 ;;
    patch) patch=$((patch + 1)) ;;
  esac
  printf "%s.%s.%s" "$major" "$minor" "$patch"
}

# -------------------------------------------------------------- preflight ---

step "Preflight"

command -v xcodebuild >/dev/null || die "xcodebuild not found. Install Xcode."
command -v npx >/dev/null        || die "npx not found. Install Node."
command -v python3 >/dev/null    || die "python3 not found."
command -v git >/dev/null        || die "git not found."

git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1 || die "Not a git repository."

STARTING_BRANCH="$(git -C "$ROOT" rev-parse --abbrev-ref HEAD)"
info "branch: $STARTING_BRANCH"

if [[ $DO_RELEASE == 1 && "$STARTING_BRANCH" != "$WORK_BRANCH" ]]; then
  die "Releases are cut from '$WORK_BRANCH'; you are on '$STARTING_BRANCH'."
fi

# A release has to be reproducible from the repository afterwards, and with
# Xcode Cloud it is stricter than a preference: the cloud builds what was
# pushed, so anything uncommitted is simply not in the build. A warning that
# said "continue anyway?" would be inviting somebody to ship a binary that does
# not match any commit.
if [[ -n "$(git -C "$ROOT" status --porcelain --untracked-files=no)" ]]; then
  if [[ $DO_RELEASE == 1 ]]; then
    git -C "$ROOT" status --short --untracked-files=no | sed 's/^/      /'
    die "Uncommitted changes. Xcode Cloud builds what is pushed, so these would not be in it. Commit first."
  fi
  warn "Uncommitted changes (not shipping the app, so continuing)."
fi

if [[ -n "$BUMP" ]]; then
  CURRENT="$(marketing_version)"
  NEXT="$(bump_version "$CURRENT" "$BUMP")"
  step "Version: $CURRENT -> $NEXT"
  set_marketing_version "$CURRENT" "$NEXT"
fi

VERSION="$(marketing_version)"
BUILD="$(build_number)"
bold ""
bold "  NestZone $VERSION (build $BUILD)"
bold ""

# The changelog rule, enforced rather than remembered. A release that reaches
# phones with no note is a release nobody is told about, and by the time anyone
# notices, the context for writing one is gone.
step "Changelog"

CHANGELOG="$BACKEND/changelog.json"
[[ -f "$CHANGELOG" ]] || die "No $CHANGELOG."

python3 - "$CHANGELOG" "$VERSION" <<'PY' || die "Fix backend/changelog.json, then run again."
import json, sys
path, version = sys.argv[1], sys.argv[2]
try:
    doc = json.load(open(path, encoding="utf-8"))
except json.JSONDecodeError as e:
    print(f"    changelog.json is not valid JSON: {e}")
    sys.exit(1)

entries = doc.get("entries", [])
slugs = [e.get("slug") for e in entries]
if len(slugs) != len(set(slugs)):
    dupes = {s for s in slugs if slugs.count(s) > 1}
    print(f"    Duplicate slugs: {', '.join(sorted(map(str, dupes)))}")
    print("    A slug is the upsert key; two entries sharing one overwrite each other.")
    sys.exit(1)

live = [e for e in entries if not e.get("draft")]
for e in live:
    missing = [k for k in ("slug", "kind", "title", "body") if not e.get(k)]
    if missing:
        print(f"    Entry {e.get('slug', '?')} is missing: {', '.join(missing)}")
        sys.exit(1)

matching = [e for e in live if e.get("version") == version]
if not matching:
    print(f"    No published changelog entry for version {version}.")
    print("")
    print("    Every release people would notice gets one — that is what the")
    print("    Updates tab is for. Add it at the top of backend/changelog.json:")
    print("")
    print('      {')
    print(f'        "slug": "{version}-something",')
    print(f'        "version": "{version}",')
    print('        "kind": "feature",')
    print('        "title": "...",')
    print('        "body": "..."')
    print('      }')
    print("")
    print("    If this release genuinely changes nothing a household would")
    print("    notice, it does not need shipping to the App Store either.")
    sys.exit(1)

print(f"    ok — {len(matching)} entry for {version}, {len(live)} published in total")
for e in matching:
    print(f"      · [{e['kind']}] {e['title']}")
PY

# ---------------------------------------------------------------- backend ---

if [[ $DO_BACKEND == 1 ]]; then
  step "Backend: typecheck"
  ( cd "$BACKEND" && run npx tsc --noEmit -p tsconfig.json ) \
    || die "Backend does not typecheck."
  info "ok"

  step "Backend: deploy"
  info "One deployment serves every app version that exists."
  info "Add, never remove. Widen, never narrow. Default, never require."
  ( cd "$BACKEND" && run npx convex deploy -y ) || die "convex deploy failed."

  step "Changelog: sync"
  ( cd "$BACKEND" && run npx convex run inbox:syncChangelog "$(cat "$CHANGELOG")" ) \
    || die "Changelog sync failed."

  step "Who is still out there"
  # Printed on every deploy rather than kept in a runbook, because the moment
  # it matters is the moment somebody is about to remove something. See
  # backend/DEPRECATIONS.md — `unknown` means a build too old to report, and
  # every number is a floor.
  ( cd "$BACKEND" && run npx convex run inbox:versionCensus '{}' ) || true
fi

[[ $DO_RELEASE == 0 ]] && { step "Done"; info "backend deployed, changelog synced"; exit 0; }

# ---------------------------------------------------------- the build no. ---

# A build number Apple has already seen is rejected on upload — after the
# build, after the transfer, which is the slowest possible place to find out.
# Bumped and committed before anything is pushed, so the number in the binary
# is the number in the repository whichever side builds it.
NEXT_BUILD=$((BUILD + 1))
step "Build number: $BUILD -> $NEXT_BUILD"
set_build_number "$NEXT_BUILD"
BUILD="$NEXT_BUILD"

if [[ $DRY_RUN == 0 ]]; then
  git -C "$ROOT" add "$PBXPROJ"
  git -C "$ROOT" commit -q -m "version bump" || true
  info "committed on $WORK_BRANCH"
else
  info "would commit the bump on $WORK_BRANCH"
fi

# ------------------------------------------------------------------- ship ---

if [[ "$BUILD_WHERE" == "cloud" ]]; then
  step "Release: $WORK_BRANCH -> $RELEASE_BRANCH"

  # A cheap build first. Xcode Cloud takes minutes to tell you the same thing,
  # and a red build on `stage` is a commit you have to chase with another.
  info "compiling first, so a broken build never reaches the branch"
  run xcodebuild -scheme "$SCHEME" -destination "$SIM_DESTINATION" build \
    > /dev/null 2>&1 || die "It does not build. Nothing pushed."
  info "builds clean"

  if [[ $DRY_RUN == 0 ]]; then
    git -C "$ROOT" push -q "$REMOTE" "$WORK_BRANCH" || die "Could not push $WORK_BRANCH."
    info "pushed $WORK_BRANCH"

    # Create the release branch on first use rather than making it a
    # prerequisite somebody has to know about.
    if ! git -C "$ROOT" show-ref --verify --quiet "refs/heads/$RELEASE_BRANCH"; then
      git -C "$ROOT" branch "$RELEASE_BRANCH" "$WORK_BRANCH"
      info "created $RELEASE_BRANCH"
    fi

    git -C "$ROOT" checkout -q "$RELEASE_BRANCH"
    # --no-ff so every release is one commit on this branch with a message
    # saying what it was. Fast-forwarded, `stage` would just be a moving
    # pointer and its log would say nothing about releases at all.
    if ! git -C "$ROOT" merge --no-ff "$WORK_BRANCH" -m "Release $VERSION (build $BUILD)"; then
      git -C "$ROOT" merge --abort || true
      die "Merge conflict on $RELEASE_BRANCH. Nothing pushed; resolve it there by hand."
    fi
    git -C "$ROOT" push -q -u "$REMOTE" "$RELEASE_BRANCH" || die "Could not push $RELEASE_BRANCH."
    info "merged and pushed $RELEASE_BRANCH"
    git -C "$ROOT" checkout -q "$WORK_BRANCH"
  else
    info "would push $WORK_BRANCH"
    info "would merge $WORK_BRANCH into $RELEASE_BRANCH (--no-ff) and push it"
    info "would check out $WORK_BRANCH again"
  fi

  step "Done"
  info "NestZone $VERSION (build $BUILD)"
  info "backend deployed, changelog synced, $RELEASE_BRANCH pushed"
  echo ""
  info "Xcode Cloud takes it from here — if the workflow is on and watching"
  info "'$RELEASE_BRANCH'. Watch it in Xcode: Product > Xcode Cloud > Builds,"
  info "or in App Store Connect under the app's Xcode Cloud tab."
  info "Never run this and not seen a build? See XCODE_CLOUD.md."
  exit 0
fi

# ------------------------------------------------------ local, as a fallback -

step "Release: archive on this Mac"
warn "Local build. If Xcode Cloud also builds '$RELEASE_BRANCH', do not push"
warn "this version there as well — two binaries, one build number."

run rm -rf "$ARCHIVE" "$EXPORT_DIR"
run mkdir -p "$BUILD_DIR"
run xcodebuild archive \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -destination "generic/platform=iOS" \
  -archivePath "$ARCHIVE" \
  -allowProvisioningUpdates \
  | tail -3 || die "Archive failed."
info "archived: $ARCHIVE"

step "Release: upload"

# An API key rather than an Apple ID and an app-specific password: it does not
# expire on a password change, it carries no second factor, and it is the only
# form that works unattended.
#
#   export ASC_KEY_ID=XXXXXXXXXX        # from the .p8 filename
#   export ASC_ISSUER_ID=<uuid>         # App Store Connect > Users and Access
#                                       #   > Integrations > App Store Connect API
#
# with AuthKey_$ASC_KEY_ID.p8 in ~/.appstoreconnect/private_keys/, which is
# where xcodebuild looks without being told.
if [[ -z "${ASC_KEY_ID:-}" || -z "${ASC_ISSUER_ID:-}" ]]; then
  warn "ASC_KEY_ID / ASC_ISSUER_ID are not set — skipping the upload."
  warn "The archive is ready; send it from Xcode's Organizer instead:"
  warn "  open '$ARCHIVE'"
  exit 0
fi

OPTIONS="$BUILD_DIR/ExportOptions.plist"
if [[ $DRY_RUN == 0 ]]; then
  cat > "$OPTIONS" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>app-store-connect</string>
  <key>destination</key><string>upload</string>
  <key>uploadSymbols</key><true/>
  <key>manageAppVersionAndBuildNumber</key><false/>
</dict>
</plist>
PLIST
fi
# `manageAppVersionAndBuildNumber` false on purpose: with it true, Xcode
# silently substitutes a build number of its own and the binary stops matching
# the repository.
run xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportOptionsPlist "$OPTIONS" \
  -exportPath "$EXPORT_DIR" \
  -allowProvisioningUpdates \
  -authenticationKeyIssuerID "$ASC_ISSUER_ID" \
  -authenticationKeyID "$ASC_KEY_ID" \
  -authenticationKeyPath "$HOME/.appstoreconnect/private_keys/AuthKey_${ASC_KEY_ID}.p8" \
  | tail -5 || die "Upload failed."

step "Done"
info "NestZone $VERSION (build $BUILD) sent from this Mac"
info "Commit the version bump and push when you are ready."
