#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "usage: $0 <apk>" >&2
  exit 2
fi

apk=$1
if [ ! -f "$apk" ]; then
  echo "certification APK not found: $apk" >&2
  exit 2
fi

scratch_dir=$(mktemp -d)
trap 'rm -rf "$scratch_dir"' EXIT

# Inspect strings from the assembled artifact, not source files or build logs.
# The fixed profile must be visibly bound to the approved staging origins and
# must not retain any retired/production service origin it could contact.
unzip -p "$apk" | strings -a > "$scratch_dir/apk.strings"

required_origins=(
  'https://staging-vibe-bbx.bull-wallet.com'
  'https://staging-vibe.bull-wallet.com'
  'https://pay2.bull-wallet.com'
)

for origin in "${required_origins[@]}"; do
  if ! grep -Fq -- "$origin" "$scratch_dir/apk.strings"; then
    echo "certification APK is missing required origin: $origin" >&2
    exit 1
  fi
done

forbidden_origins=(
  'https://api.bullbitcoin.com'
  'https://accounts.bullbitcoin.com'
  'https://api01.bullbitcoin.dev'
  'https://staging-vibe-bullnym.bull-wallet.com'
)

for origin in "${forbidden_origins[@]}"; do
  if grep -Fq -- "$origin" "$scratch_dir/apk.strings"; then
    echo "certification APK contains forbidden origin: $origin" >&2
    exit 1
  fi
done

echo "Certification APK origin profile verified."
