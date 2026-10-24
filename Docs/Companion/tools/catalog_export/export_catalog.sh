#!/bin/sh
# Regenerates backend/convex/lib/companionData.ts from the app's catalog.
# Run after any change to CompanionCatalog.swift, CompanionModels.swift or
# Holidays.swift, and commit the result with the change. Backend first.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../../.." && pwd)
app="$root/NestZone/Features/Companion"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
swiftc -O -module-name CatalogExport \
  "$here/Stub.swift" "$here/main.swift" \
  "$app/CompanionModels.swift" "$app/CompanionCatalog.swift" "$app/Holidays.swift" \
  -o "$work/export"
"$work/export" "$root/backend/convex/lib/companionData.ts"

# Keep the app's own copy of the version in step: forHome's catalogVersion is
# the data's hash and the rules' version, and a build that differs logs it.
hash=$(sed -n 's/^export const CATALOG_VERSION = "\(.*\)";/\1/p' "$root/backend/convex/lib/companionData.ts")
rules=$(sed -n 's/^export const RULES_VERSION = \([0-9]*\);/\1/p' "$root/backend/convex/lib/companion.ts")
sed -i '' "s|public static let exported = \".*\"|public static let exported = \"$hash-r$rules\"|" "$app/CompanionCatalog.swift"
