#!/usr/bin/env bash
# Reports gofiber-maintained middlewares that this list does not link yet.
# gofiber/fiber and gofiber/contrib are the source of truth, so they are read
# from their default branch instead of from a vendored copy.
#
# Usage: GH_TOKEN=... bash .github/scripts/check-middleware-coverage.sh [README.md]
set -euo pipefail

readme="${1:-README.md}"
missing=""

# One tree request per repo; a per-directory lookup would be 25 calls.
tree() {
  gh api "repos/$1/git/trees/HEAD?recursive=1" --jq "$2"
}

# A core middleware is a directory under middleware/ holding Go files.
core=$(tree gofiber/fiber '
  .tree[] | select(.type == "blob") | .path
  | select(startswith("middleware/") and endswith(".go"))
  | split("/") | select(length == 3) | .[1]' | sort -u)

# A contrib middleware is a v3 directory with its own module.
contrib=$(tree gofiber/contrib '
  .tree[] | select(.type == "blob") | .path
  | select(startswith("v3/") and endswith("/go.mod"))
  | split("/") | select(length == 3) | .[1]' | sort -u)

# An empty list means the API answer changed shape, not that a repo lost its
# middlewares - reporting "all listed" for that would be the worst outcome.
if [ -z "$core" ] || [ -z "$contrib" ]; then
  echo "::error::could not read the middleware list from GitHub" >&2
  exit 1
fi

collect() {
  local label="$1" link="$2" names="$3" name
  while read -r name; do
    [ -n "$name" ] || continue
    grep -qF "${link}${name})" "$readme" && continue
    missing+="- ${label}: \`${name}\` (${link}${name})"$'\n'
  done <<< "$names"
}

collect core "https://github.com/gofiber/fiber/tree/main/middleware/" "$core"
collect contrib "https://github.com/gofiber/contrib/tree/main/v3/" "$contrib"

if [ -z "$missing" ]; then
  echo "All gofiber middlewares are listed."
  exit 0
fi

printf 'Missing entries:\n%s' "$missing"
if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  {
    echo "### Middlewares missing from the list"
    echo
    printf '%s' "$missing"
  } >> "$GITHUB_STEP_SUMMARY"
fi
exit 1
