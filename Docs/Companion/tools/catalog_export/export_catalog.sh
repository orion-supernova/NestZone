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
