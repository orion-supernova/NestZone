#!/usr/bin/env bash
#
# Ship NestZone.
#
# One command for the whole release: check, deploy the backend, sync the
# changelog, archive the app, upload it to App Store Connect.
#
#   ./deploy.sh                 # the lot
#   ./deploy.sh --backend       # backend + changelog only
#   ./deploy.sh --app           # archive + upload only
#   ./deploy.sh --bump patch    # 1.9.0 -> 1.9.1 first, then the lot
#   ./deploy.sh --no-upload     # build and archive, stop before Apple
#   ./deploy.sh --dry-run       # say what would happen, touch nothing
#
# ORDER MATTERS, and it is backend first.
#
# A new app build expects backend functions that a new backend has; an old app
# build must keep working against that same backend, which is what
# backend/DEPRECATIONS.md is for. Deploy the backend first and both hold at
# every moment in between: the old app still works (the change was additive)
# and the new app has what it needs by the time it reaches anybody. Ship the app
# first and there is a window — minutes if it goes well, a week if the upload
# fails — where the newest build is calling functions that do not exist.
#
# Everything here is re-runnable. `convex deploy` is idempotent, the changelog
# sync is idempotent by slug, and a failed upload can simply be run again.

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

DO_BACKEND=1
DO_APP=1
DO_UPLOAD=1
DRY_RUN=0
BUMP=""

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

# ------------------------------------------------------------------ args ----

while [[ $# -gt 0 ]]; do
  case "$1" in
    --backend)   DO_APP=0 ;;
    --app)       DO_BACKEND=0 ;;
    --no-upload) DO_UPLOAD=0 ;;
    --dry-run)   DRY_RUN=1 ;;
    --bump)      BUMP="${2:-}"; shift ;;
    -h|--help)   sed -n '2,28p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
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

# Rewrites the app target's version everywhere it appears at that value.
#
# `sed` over the pbxproj rather than agvtool, which rewrites both the project
# and the Info.plists and disagrees with this project's build settings about
# where the truth lives.
set_marketing_version() {
  local from="$1" to="$2"
  run /usr/bin/sed -i '' "s/MARKETING_VERSION = ${from};/MARKETING_VERSION = ${to};/g" "$PBXPROJ"
}

set_build_number() {
  local to="$1"
  run /usr/bin/sed -i '' -E "s/CURRENT_PROJECT_VERSION = [^;]+;/CURRENT_PROJECT_VERSION = ${to};/g" "$PBXPROJ"
}

bump_version() {
  local current="$1" kind="$2"
  local major minor patch
  IFS=. read -r major minor patch <<< "$current"
  major=${major:-0}; minor=${minor:-0}; patch=${patch:-0}
  case "$kind" in
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

git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1 || die "Not a git repository."

BRANCH="$(git -C "$ROOT" rev-parse --abbrev-ref HEAD)"
info "branch: $BRANCH"

if [[ -n "$(git -C "$ROOT" status --porcelain --untracked-files=no)" ]]; then
  warn "Working tree has uncommitted changes."
  warn "Shipping something that is not committed means the build cannot be"
  warn "reproduced from the repository afterwards."
  if [[ $DRY_RUN == 0 ]]; then
    read -r -p "    Continue anyway? [y/N] " reply
    [[ "$reply" =~ ^[Yy]$ ]] || die "Stopped. Commit first."
  fi
fi

if [[ -n "$BUMP" ]]; then
  CURRENT="$(marketing_version)"
  NEXT="$(bump_version "$CURRENT" "$BUMP")"
  step "Bumping version: $CURRENT -> $NEXT"
  set_marketing_version "$CURRENT" "$NEXT"
fi

VERSION="$(marketing_version)"
BUILD="$(build_number)"
bold ""
bold "  NestZone $VERSION (build $BUILD)"
bold ""

# The changelog rule, enforced rather than remembered.
#
# An entry for the version being shipped is the whole point of the Updates tab:
# a release that reaches phones with no note is a release nobody is told about,
# and by the time anybody notices, the context for writing one is gone.
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

  step "Backend: compatibility reminder"
  info "One deployment serves every app version that exists."
  info "Add, never remove. Widen, never narrow. Default, never require."
  info "See backend/DEPRECATIONS.md — and after this deploy:"
  info "  npx convex run inbox:versionCensus '{}'"

  step "Backend: deploy"
  ( cd "$BACKEND" && run npx convex deploy -y ) || die "convex deploy failed."

  step "Changelog: sync"
  # Idempotent by slug: safe on every deploy, and a re-sync never re-announces
  # an entry that already has a publication date.
  ( cd "$BACKEND" && run npx convex run inbox:syncChangelog "$(cat "$CHANGELOG")" ) \
    || die "Changelog sync failed."
fi

# -------------------------------------------------------------------- app ---

if [[ $DO_APP == 1 ]]; then
  # A build number Apple has already seen is rejected on upload, after the
  # archive and after the transfer — the slowest possible place to find out.
  # Bumped before the archive so the number in the binary is the one that goes.
  if [[ $DO_UPLOAD == 1 ]]; then
    NEXT_BUILD=$((BUILD + 1))
    step "Build number: $BUILD -> $NEXT_BUILD"
    set_build_number "$NEXT_BUILD"
    BUILD="$NEXT_BUILD"
  fi

  step "App: build for the simulator"
  # Cheap, and it fails in seconds rather than in the middle of an archive.
  run xcodebuild -scheme "$SCHEME" -destination "$SIM_DESTINATION" build \
    | tail -3 || die "Simulator build failed."

  step "App: archive"
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

  if [[ $DO_UPLOAD == 1 ]]; then
    step "App: upload to App Store Connect"

    # An API key rather than an Apple ID and an app-specific password: it does
    # not expire on a password change, it carries no second factor, and it is
    # the only form that works unattended.
    #
    #   export ASC_KEY_ID=XXXXXXXXXX
    #   export ASC_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
    #
    # with AuthKey_$ASC_KEY_ID.p8 in ~/.appstoreconnect/private_keys/, which is
    # where xcodebuild looks for it without being told.
    if [[ -z "${ASC_KEY_ID:-}" || -z "${ASC_ISSUER_ID:-}" ]]; then
      warn "ASC_KEY_ID / ASC_ISSUER_ID are not set — skipping the upload."
      warn "The archive is ready; open it in Xcode's Organizer to send it by hand:"
      warn "  open '$ARCHIVE'"
    else
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
      # `manageAppVersionAndBuildNumber` is false on purpose: with it true,
      # Xcode silently rewrites the build number it feels like using, and the
      # number in the archive stops matching the number in the repository.
      run xcodebuild -exportArchive \
        -archivePath "$ARCHIVE" \
        -exportOptionsPlist "$OPTIONS" \
        -exportPath "$EXPORT_DIR" \
        -allowProvisioningUpdates \
        -authenticationKeyIssuerID "$ASC_ISSUER_ID" \
        -authenticationKeyID "$ASC_KEY_ID" \
        -authenticationKeyPath "$HOME/.appstoreconnect/private_keys/AuthKey_${ASC_KEY_ID}.p8" \
        | tail -5 || die "Upload failed."
      info "sent to App Store Connect"
    fi
  fi
fi

# ------------------------------------------------------------------ done ----

step "Done"
info "NestZone $VERSION (build $BUILD)"
[[ $DO_BACKEND == 1 ]] && info "backend deployed, changelog synced"
[[ $DO_APP == 1 && $DO_UPLOAD == 1 ]] && info "build sent — it appears in App Store Connect in a few minutes"

if [[ $DRY_RUN == 0 && $DO_APP == 1 ]]; then
  echo ""
  info "The version and build number in project.pbxproj changed. Commit them:"
  info "  git add NestZone.xcodeproj/project.pbxproj && git commit -m 'version bump'"
fi
