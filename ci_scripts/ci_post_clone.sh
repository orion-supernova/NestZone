#!/bin/sh
#
# Xcode Cloud runs this after cloning and before it resolves packages or builds.
#
# WHY IT EXISTS
#
# Swift macros execute arbitrary code inside the compiler, so Swift Package
# Manager will not run one until a human has agreed to it. The agreement is a
# fingerprint recorded in
#
#   ~/Library/org.swift.swiftpm/security/macros.json
#
# and the important word is `~`. It is **per user, per machine**, and it is
# nowhere in this repository — on a laptop it gets written the first time Xcode
# shows the "Trust & Enable" sheet and is never thought about again.
#
# Xcode Cloud is a fresh machine with nobody at the keyboard. It has no such
# file, no way to produce one, and so it refuses every macro this app is built
# out of:
#
#   Macro "ComposableArchitectureMacros" from package
#   "swift-composable-architecture" must be enabled before it can be used
#
# and the same for swift-perception, swift-navigation, swift-case-paths and
# swift-dependencies. Five failures, one cause, and nothing wrong with the code.
#
# WHAT IT DOES, AND WHAT IT DELIBERATELY DOES NOT
#
# It copies `ci_scripts/macros.json` — this project's answer to that sheet,
# checked in and reviewable — into place before anything builds.
#
# It does **not** set `IDESkipMacroFingerprintValidation`, which is the usual
# advice and turns the check off entirely. That would trust any macro from any
# dependency, present or future, forever, in the one environment where nobody
# is watching the build. This trusts five named macros at five exact
# fingerprints and nothing else, which is a list you can read.
#
# WHEN IT BREAKS
#
# A fingerprint belongs to a package *version*, so bumping any of those five
# packages changes it and this build starts failing with the same message. That
# is the intended behaviour — new macro code deserves a fresh look — and the
# fix is one line, run after Xcode has prompted you locally:
#
#   cp ~/Library/org.swift.swiftpm/security/macros.json ci_scripts/macros.json
#
# Commit it alongside the `Package.resolved` change that caused it. The two
# belong in the same commit because they describe the same fact.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE="$SCRIPT_DIR/macros.json"
DESTINATION_DIR="$HOME/Library/org.swift.swiftpm/security"

echo "ci_post_clone: trusting this project's Swift macros"

if [ ! -f "$SOURCE" ]; then
  echo "ci_post_clone: $SOURCE is missing — every macro in this app will be refused." >&2
  exit 1
fi

mkdir -p "$DESTINATION_DIR"
cp "$SOURCE" "$DESTINATION_DIR/macros.json"

echo "ci_post_clone: wrote $DESTINATION_DIR/macros.json"
# Printed so a failing build shows which macros were trusted and at what
# fingerprints, next to the error saying one of them was not.
cat "$DESTINATION_DIR/macros.json"
