#!/usr/bin/env bash
# Fails closed if any GitHub Actions workflow or composite action references
# an external `uses:` action by a mutable ref (tag/branch) instead of a full
# 40-character commit SHA. Every external action must stay pinned by commit
# SHA, with the
# human-readable tag kept as a trailing comment for context.
#
# Local (`./...`) and Docker (`docker://...`) references are ignored: they
# are not fetched from a mutable remote ref the same way a marketplace action
# is.
#
# Usage: tools/check_action_pins.sh [repository-root]
set -euo pipefail

if [ "$#" -gt 1 ]; then
  echo "Usage: $0 [repository-root]" >&2
  exit 2
fi

repo_root_arg=${1:-$(dirname "${BASH_SOURCE[0]}")/..}
if [ ! -d "$repo_root_arg" ]; then
  echo "❌ repository root does not exist: $repo_root_arg" >&2
  exit 2
fi
repo_root=$(cd "$repo_root_arg" && pwd)
cd "$repo_root"

shopt -s nullglob globstar
files=(.github/workflows/*.yml .github/workflows/*.yaml .github/actions/**/action.yml .github/actions/**/action.yaml)

if [ "${#files[@]}" -eq 0 ]; then
  echo "❌ no workflow or composite action files found under $repo_root/.github/ — failing closed (an empty scan must never read as green)"
  exit 1
fi

checked=0
violations=()

for f in "${files[@]}"; do
  while IFS= read -r line; do
    # Match a `uses:` value, ignoring leading indentation/list markers.
    ref=$(printf '%s\n' "$line" | sed -n 's/^[[:space:]]*-\{0,1\}[[:space:]]*uses:[[:space:]]*\(.*\)$/\1/p')
    [ -n "$ref" ] || continue
    # Strip a trailing comment, e.g. "actions/checkout@SHA # v7.0.1".
    ref=$(printf '%s\n' "$ref" | sed 's/[[:space:]]*#.*$//')
    # Strip surrounding quotes if present.
    ref=$(printf '%s\n' "$ref" | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'\$//")
    [ -n "$ref" ] || continue

    # Skip local composite actions and Docker image references.
    case "$ref" in
      ./*|docker://*) continue ;;
    esac

    checked=$((checked + 1))

    case "$ref" in
      *@*) : ;;
      *)
        violations+=("$repo_root/$f: uses '$ref' has no @ref at all")
        continue
        ;;
    esac

    action_ref="${ref#*@}"
    if ! printf '%s' "$action_ref" | grep -Eq '^[0-9a-f]{40}$'; then
      violations+=("$repo_root/$f: uses '$ref' is not pinned to a 40-character commit SHA")
    fi
  done < "$f"
done

echo "🔎 Verified $checked external 'uses:' reference(s) across ${#files[@]} file(s)."

if [ "${#violations[@]}" -gt 0 ]; then
  echo "❌ found ${#violations[@]} unpinned action reference(s):"
  for v in "${violations[@]}"; do
    echo "  · $v"
  done
  echo "Pin every external action to a full commit SHA (see README/AGENTS for the resolution method), keeping the tag as a trailing comment."
  exit 1
fi

echo "✅ all external actions are pinned to a commit SHA"
