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
if echo "$exports" | grep -qE "src/(crypto|data)/|src/domain/ports/(secret_store_port|secure_key_value_store_port)|src/ui/(mnemonic_reader|privacy_guard)"; then
  note "barrel exports an internal src/ path"
fi
if echo "$exports" | grep -qE "\b(SecretStorePort|SecureKeyValueStorePort|Mnemonic|Seed|MnemonicReader|SecretGuard|[A-Za-z]+Adapter|[A-Za-z]+Impl)\b"; then
  note "barrel exports an internal adapter/model type"
fi
# A `part` directive re-exposes a file's internals while sidestepping the export
# grep above — the barrel must only `export`.
if grep -qE "^\s*part\s+['\"]" "$barrel" 2>/dev/null; then
  note "barrel uses a 'part' directive (can leak internals past the export check)"
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

# 4) Naming convention: capability implementations are `*Adapter`, never
#    `*Impl` (Port/Adapter, secrets-package convention).
pkg=packages/secrets/lib
impl=$(grep -rnE "class\s+[A-Za-z0-9_]+Impl\b" --include='*.dart' "$pkg" 2>/dev/null || true)
[ -n "$impl" ] && note "a *Impl class exists — use *Adapter (Port/Adapter convention):
$impl"

# 5) `useAndForget` (the raw secret-read) is allow-listed to the single guard +
#    the sealed UI reader. Anywhere else widens the secret's exposure surface.
# Match actual call sites (`.useAndForget(`), not the declaration/doc comments.
uaf=$(grep -rnE "\.useAndForget\(" --include='*.dart' "$pkg" 2>/dev/null \
  | grep -vE "secret_guard.dart|mnemonic_reader.dart" \
  || true)
[ -n "$uaf" ] && note "useAndForget called outside the guard/reader allow-list:
$uaf"

# 6) `flutter_secure_storage` (the raw secret-at-rest backend) may be imported
#    ONLY by the files below — no other code may touch the keychain directly.
#    The enforceable invariant is "the raw plugin is confined to the secrets
#    adapter + the app's existing storage layer, and the SEED is owned only by
#    secrets". The three app files stay allow-listed: per migration decision G1,
#    non-seed secrets (swap keys, PIN, exchange api-key) deliberately remain on
#    the shared keychain, so the live storage layer keeps keychain access even
#    after the F1 seed migration — the list does NOT shrink to just the adapter.
#    NO NEW external import. Matched as exact whole paths (anchored, dots literal)
#    so a `…storage_locator.dart.bak.dart`-style name cannot slip through.
fss_allow_list='packages/secrets/lib/src/data/adapters/flutter_secure_storage_adapter.dart
lib/core/storage/storage_locator.dart
lib/core/storage/data/datasources/key_value_storage/impl/secure_storage_data_source_impl.dart
lib/core/storage/data/datasources/key_value_storage/impl/secure_storage_legacy_datasource_impl.dart'
fss=$(grep -rlE "import\s+['\"]package:flutter_secure_storage(_legacy)?/" \
  --include='*.dart' $SCAN_DIRS 2>/dev/null \
  | grep -v '/.dart_tool/' \
  | grep -vxF "$fss_allow_list" \
  || true)
[ -n "$fss" ] && note "flutter_secure_storage imported outside the secrets adapter / live storage layer (raw keychain must stay sealed):
$fss"

if [ "$fail" -ne 0 ]; then
  echo "🔒 Seal check FAILED."
  exit 1
fi
echo "✅ Seal check passed."
