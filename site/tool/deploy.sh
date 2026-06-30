#!/usr/bin/env bash
#
# Build the Jaspr site and deploy it to the CORRECT Vercel project, then verify.
#
# Why this script exists (read before "simplifying" it):
#   * `jaspr build` wipes site/build/jaspr/ on every run — including the
#     `.vercel/` link that lives there. After a build, that directory has NO
#     project link.
#   * `vercel deploy --yes` with no link does NOT fail — it auto-creates/links a
#     project named after the directory ("jaspr") and deploys there. That is how
#     a release once went to a stray `jaspr` project while qseq.app (an alias of
#     the `qseq` project) kept serving the old build.
#
# The fix: re-pin the link to the qseq project (by name + team) AFTER the build
# and BEFORE the deploy, never depend on whatever `.vercel` happens to be on
# disk, and fail loudly if production doesn't end up serving the new asset.
#
# Usage:  site/tool/deploy.sh
set -euo pipefail

TEAM="meerv"            # Vercel scope (team slug)
PROJECT="qseq"          # Vercel project that owns qseq.app — NEVER "jaspr"
DOMAIN="qseq.app"
ASSET="QSeq.dmg"        # asset we verify end-to-end (the notarized macOS DMG)

SITE_DIR="$(cd "$(dirname "$0")/.." && pwd)"   # .../site
OUT="$SITE_DIR/build/jaspr"

# jaspr rejects the standalone Homebrew `dart`; it needs Flutter's bundled SDK.
FLUTTER_BIN="$(dirname "$(readlink -f "$(command -v flutter)")")"
export PATH="$FLUTTER_BIN/cache/dart-sdk/bin:$FLUTTER_BIN:$PATH"
echo "› dart: $(command -v dart)"

echo "› building jaspr site…"
( cd "$SITE_DIR" && dart pub global run jaspr_cli:jaspr build )
[ -f "$OUT/$ASSET" ] || { echo "✗ $ASSET missing from build output ($OUT)"; exit 1; }

# Re-pin the link to the right project (the build just wiped any .vercel here).
echo "› linking $OUT → $TEAM/$PROJECT …"
( cd "$OUT" && vercel link --yes --scope "$TEAM" --project "$PROJECT" >/dev/null )

# Sanity-check the link actually points at the intended project before deploying.
LINKED="$(python3 -c "import json,sys;print(json.load(open('$OUT/.vercel/project.json'))['projectName'])" 2>/dev/null || echo '?')"
[ "$LINKED" = "$PROJECT" ] || { echo "✗ link points at '$LINKED', expected '$PROJECT' — aborting"; exit 1; }

echo "› deploying to production ($TEAM/$PROJECT)…"
( cd "$OUT" && vercel deploy --prod --yes --scope "$TEAM" )

# Verify production really serves the freshly built asset (defeats CDN staleness
# by comparing content hashes, not just HTTP 200).
echo "› verifying https://$DOMAIN/$ASSET …"
sleep 5
LOCAL="$(shasum -a256 "$OUT/$ASSET" | awk '{print $1}')"
LIVE="$(curl -fsSL "https://$DOMAIN/$ASSET?cb=$$" | shasum -a256 | awk '{print $1}')"
if [ "$LOCAL" = "$LIVE" ]; then
  echo "✓ $DOMAIN/$ASSET matches the new build ($LOCAL)"
else
  echo "✗ MISMATCH — $DOMAIN served $LIVE but build is $LOCAL"
  echo "  (check that $DOMAIN is a production alias of the $PROJECT project)"
  exit 1
fi
