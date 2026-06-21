#!/usr/bin/env bash
# Seal-gate for the `secrets` package (the enforceable slice of SECRETS_*_SPEC's
# CI gates). Fails CI if the library-privacy seal is breached from outside the
# package. Run via `make seal-check`.
#
# The hard wall is library-privacy + non-export; `package:lints` already makes a
# cross-package `import 'package:secrets/src/...'` an info (fatal under
# `--fatal-infos`). This adds belt-and-suspenders greps that also catch
# barrel-export mistakes and suppression of the internal-member lint.
set -euo pipefail

fail=0
note() { echo "❌ SEAL VIOLATION: $*"; fail=1; }

# Directories scanned for external (non-package) seal violations.
SCAN_DIRS="lib features packages test integration_test"

# 1) Nothing OUTSIDE packages/secrets may import the package's src/.
hits=$(grep -rnE "import\s+['\"]package:secrets/src/" \
  --include='*.dart' $SCAN_DIRS 2>/dev/null \
  | grep -v 'packages/secrets/' || true)
[ -n "$hits" ] && note "external import of package:secrets/src/:
$hits"

# 2) The barrel must never export an internal type / src path. Only inspect
#    actual `export` directives (doc comments may legitimately name them).
barrel=packages/secrets/lib/secrets.dart
exports=$(grep -E "^\s*export\b" "$barrel" 2>/dev/null || true)
# Internal src trees + internal ui helpers (only src/ui/widgets/* are public).
if echo "$exports" | grep -qE "src/(crypto|storage|data)/|src/ui/(mnemonic_reader|privacy_guard)"; then
  note "barrel exports an internal src/ path"
fi
if echo "$exports" | grep -qE "\b(SecretStore|SecureKeyValueStore|SeedSecret|MnemonicSeedSecret|BytesSeedSecret|MnemonicReader|PortImpl|SeedRepositoryImpl)\b"; then
  note "barrel exports an internal/impl type"
fi
# Any src/ export MUST use a `show` allowlist — a bare re-export leaks every
# public name in that file (incl. internal helpers). Parse FULL statements
# (export ... ;) since they may span multiple lines.
statements=$(tr '\n' ' ' < "$barrel" | grep -oE "export[[:space:]]+['\"][^;]*;" || true)
while IFS= read -r stmt; do
  [ -z "$stmt" ] && continue
  if echo "$stmt" | grep -q "src/" && ! echo "$stmt" | grep -qE "\bshow\b"; then
    note "barrel has a src/ export without a 'show' allowlist: $stmt"
  fi
done <<< "$statements"

# 3) No one may suppress the internal-member lint to reach a @internal secret
#    accessor (Bip85Derivation.words / Bip85HexResult.hexForView / ArkSecret.bytes).
sup=$(grep -rnE "//\s*ignore.*invalid_use_of_internal_member" \
  --include='*.dart' $SCAN_DIRS 2>/dev/null \
  | grep -v 'packages/secrets/' || true)
[ -n "$sup" ] && note "inline suppression of invalid_use_of_internal_member outside secrets:
$sup"

# 3b) Nor may a consumer downgrade the lint via analysis_options.yaml config
#     (errors: invalid_use_of_internal_member: ignore/info) — that silences the
#     only hard wall for an entire package without an inline comment.
cfg=$(grep -rnE "invalid_use_of_internal_member" \
  --include='analysis_options.yaml' $SCAN_DIRS 2>/dev/null \
  | grep -v 'packages/secrets/' || true)
[ -n "$cfg" ] && note "analysis_options downgrades invalid_use_of_internal_member outside secrets:
$cfg"

if [ "$fail" -ne 0 ]; then
  echo "🔒 Seal check FAILED."
  exit 1
fi
echo "✅ Seal check passed."
