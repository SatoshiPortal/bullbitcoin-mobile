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

# Directories scanned for external (non-package) seal violations. `tool` is
# included because it holds Dart code (e.g. tool/gen_all_test.dart): a file there
# could `import 'package:secrets/src/...'` with an internal-member suppression
# and read raw words+passphrase, and the greps below are the only defense — they
# must look there too.
SCAN_DIRS="lib features packages test integration_test tool"

# 1) Nothing OUTSIDE packages/secrets may import OR RE-EXPORT the package's src/.
#    An app-side `export 'package:secrets/src/...';` would re-expose an internal
#    (e.g. FssSecretStoreAdapter's public ctor + raw useAndForget) just as an
#    import would, so both keywords are matched here.
hits=$(grep -rnE "(import|export)\s+['\"]package:secrets/src/" \
  --include='*.dart' $SCAN_DIRS 2>/dev/null \
  | grep -v 'packages/secrets/' || true)
[ -n "$hits" ] && note "external import/export of package:secrets/src/:
$hits"

# 2) The barrel is the ENTIRE public surface. DEFAULT-DENY: every `export
#    'src/...'` path MUST appear on the explicit public allow-list below.
#    Adding a new internal src/ file and exporting it FAILS until it is
#    deliberately listed here — unlike a blocklist, this cannot silently pass a
#    newly-added internal (the old rule missed `src/domain/log_sanitizer.dart`
#    and `src/data/datasources/*`). To make a file public: add an explicit
#    `show` export AND its path here, in the same review.
barrel=packages/secrets/lib/secrets.dart
public_exports='src/secrets_api.dart
src/data/migration/secret_migrator.dart
src/data/migration/reconcile_report.dart
src/domain/ports/secret_index_port.dart
src/domain/secrets_failure.dart
src/domain/secrets_error.dart
src/domain/value_objects/secret_info.dart
src/domain/value_objects/mnemonic_language.dart
src/domain/value_objects/mnemonic_length.dart
src/domain/value_objects/descriptors.dart
src/domain/value_objects/psbt.dart
src/domain/value_objects/bip85_types.dart
src/domain/value_objects/backup.dart
src/domain/value_objects/ark_secret.dart
src/domain/value_objects/signing_intent.dart
src/domain/value_objects/swap_request.dart
src/domain/value_objects/created_swap.dart
src/ui/widgets/secret_revealer.dart
src/ui/widgets/verify_backup_view.dart
src/ui/widgets/bip85_mnemonic_view.dart
src/ui/widgets/bip85_hex_view.dart'

# A `part` directive re-exposes a file's internals while sidestepping the export
# grep below — the barrel must only `export`.
if grep -qE "^\s*part\s+['\"]" "$barrel" 2>/dev/null; then
  note "barrel uses a 'part' directive (can leak internals past the export check)"
fi
# Parse FULL export statements (export … ;) since they may span multiple lines.
statements=$(tr '\n' ' ' < "$barrel" | grep -oE "export[[:space:]]+['\"][^;]*;" || true)
while IFS= read -r stmt; do
  [ -z "$stmt" ] && continue
  path=$(echo "$stmt" | grep -oE "src/[A-Za-z0-9_/]+\.dart" || true)
  [ -z "$path" ] && continue # non-src export (e.g. locator.dart) — not internal
  if ! echo "$public_exports" | grep -qxF "$path"; then
    note "barrel exports a non-allow-listed src/ path (default-deny): $path"
  fi
  # Every src/ export MUST use a `show` allowlist — a bare re-export leaks every
  # public name in that file (incl. internal helpers).
  if ! echo "$stmt" | grep -qE "\bshow\b"; then
    note "barrel has a src/ export without a 'show' allowlist: $stmt"
  fi
done <<< "$statements"

# 2b) The barrel is the ONLY .dart file that may live directly under
#     packages/secrets/lib/ — a second file there could re-export src/ internals
#     while sidestepping the barrel-export grep above (it checks exports IN the
#     barrel, not other files). An import of `package:secrets/other.dart` would
#     also bypass the `package:secrets/src/` grep in check 1.
other_lib_files=$(find packages/secrets/lib -maxdepth 1 -name '*.dart' \
  ! -name 'secrets.dart' 2>/dev/null || true)
[ -n "$other_lib_files" ] && note "a .dart file other than the barrel exists directly under packages/secrets/lib/:
$other_lib_files"

# 3) No one may suppress the internal-member lint to reach a @internal secret
#    accessor: Bip85Derivation.words / Bip85HexResult.hexForView / ArkSecret.bytes
#    AND `Secrets.mnemonicReader` (the raw root {words, passphrase} reader for the
#    sealed display widgets) — the most sensitive of the set, so it is called out
#    explicitly even though the grep matches any @internal member.
sup=$(grep -rnE "//\s*ignore.*invalid_use_of_internal_member" \
  --include='*.dart' $SCAN_DIRS 2>/dev/null \
  | grep -v 'packages/secrets/' || true)
[ -n "$sup" ] && note "inline suppression of invalid_use_of_internal_member outside secrets:
$sup"

# 3b) Nor may a consumer downgrade the lint via analysis_options.yaml config
#     (errors: invalid_use_of_internal_member: ignore/info) — that silences the
#     only hard wall for an entire package without an inline comment.
#     SCAN_DIRS covers subdirs; the ROOT analysis_options.yaml (which governs
#     lib/) is checked separately since "." isn't in SCAN_DIRS.
cfg=$(grep -rnE "invalid_use_of_internal_member" \
  --include='analysis_options.yaml' $SCAN_DIRS 2>/dev/null \
  | grep -v 'packages/secrets/' || true)
root_cfg=$(grep -nE "invalid_use_of_internal_member" \
  analysis_options.yaml 2>/dev/null \
  | grep -v 'packages/secrets/' || true)
[ -n "$cfg" ] && note "analysis_options downgrades invalid_use_of_internal_member outside secrets:
$cfg"
[ -n "$root_cfg" ] && note "root analysis_options.yaml downgrades invalid_use_of_internal_member:
$root_cfg"

# 4) Naming convention: capability implementations are `*Adapter`, never
#    `*Impl` (Port/Adapter, secrets-package convention).
pkg=packages/secrets/lib
impl=$(grep -rnE "class\s+[A-Za-z0-9_]+Impl\b" --include='*.dart' "$pkg" 2>/dev/null || true)
[ -n "$impl" ] && note "a *Impl class exists — use *Adapter (Port/Adapter convention):
$impl"

# 5) `useAndForget` (the raw secret-read) is allow-listed to two — and only two —
#    principled categories, so the secret's exposure surface cannot creep:
#      (A) RAW-SECRET READERS — the code that decodes plaintext to USE it. Kept
#          to exactly two: the single guard chokepoint + the sealed UI reader.
#      (B) SecretStorePort IMPLEMENTATIONS / DECORATORS — the store layer itself,
#          which delegates `useAndForget` to a backing store (the oubliette
#          adapter → the plugin; the dual-read decorator → hw/fss; the migrator →
#          copies fss→hw). These do not *consume* a secret to act on it; they are
#          the storage plumbing the readers sit on top of.
#    Anything OUTSIDE these two categories widens the surface. (The FSS adapter
#    *defines* `useAndForget` but its body calls `use(bytes)`, not `.useAndForget(`,
#    so it is not a call site and needs no entry.)
# Match actual call sites (`.useAndForget(`), not the declaration/doc comments.
# Anchored on the FULL allow-listed path (leading `^`, literal dots, trailing
# `:` from grep -n) so a name that merely CONTAINS an allow-listed basename
# (e.g. `evil_secret_guard.dart`) is NOT exempted.
uaf=$(grep -rnE "\.useAndForget\(" --include='*.dart' "$pkg" 2>/dev/null \
  | grep -vE "^($pkg/src/data/adapters/secret_guard\.dart|$pkg/src/ui/mnemonic_reader\.dart|$pkg/src/data/adapters/oubliette_secret_store_adapter\.dart|$pkg/src/data/adapters/dual_read_store\.dart|$pkg/src/data/migration/secret_migrator\.dart):" \
  || true)
[ -n "$uaf" ] && note "useAndForget called outside the reader / store-implementation allow-list:
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

# 7) `package:oubliette` (the NEW hardware seed-at-rest backend) is, like the FSS
#    backend, a raw store that keys seeds under `seed_<fp>`. It must stay
#    confined to the secrets package: app code constructing an `Oubliette`
#    directly could read `seed_<fp>` and bypass every gate. UNLIKE FSS, NO app
#    file legitimately needs it (it is purely the secrets hardware backend), so
#    the rule is simply "no import outside packages/secrets/" — mirroring check 1.
oub=$(grep -rlE "import\s+['\"]package:oubliette/" \
  --include='*.dart' $SCAN_DIRS 2>/dev/null \
  | grep -v 'packages/secrets/' \
  | grep -v '/.dart_tool/' \
  || true)
[ -n "$oub" ] && note "package:oubliette imported outside packages/secrets (raw hardware seed store must stay sealed):
$oub"

if [ "$fail" -ne 0 ]; then
  echo "🔒 Seal check FAILED."
  exit 1
fi
echo "✅ Seal check passed."
