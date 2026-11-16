#!/usr/bin/env bash
# Compiles the app to an AOT snapshot the way a release build does, without the native build.
#
# Debug builds and the unit tests run on the JIT, so a Dart AOT compiler crash only surfaced when someone built a release (dart-lang/sdk#64917 broke every release build for days).
# This runs the same kernel compiler (frontend_server with --aot --tfa) and then the Dart SDK's own gen_snapshot, which shares the release compiler's revision and, unlike Flutter's, prints the function it crashed on.
# Needs generated code (make build-runner and make translations).
set -euo pipefail

flutter_root=$(fvm flutter --version --machine | python3 -c 'import json, sys; print(json.load(sys.stdin)["flutterRoot"])')
cache="$flutter_root/bin/cache"
patched_sdk="$cache/artifacts/engine/common/flutter_patched_sdk_product"
[[ -d "$patched_sdk" ]] || fvm flutter precache --universal >/dev/null

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

echo "Compiling the AOT kernel"
"$cache/dart-sdk/bin/dartaotruntime" "$cache/dart-sdk/bin/snapshots/frontend_server_aot.dart.snapshot" \
  --sdk-root "$patched_sdk/" --target=flutter --aot --tfa \
  -Ddart.vm.product=true -Ddart.vm.profile=false --target-os=android \
  --packages .dart_tool/package_config.json \
  --output-dill "$work/app.dill" package:bb_mobile/main.dart > "$work/frontend.log" 2>&1 || {
  echo "AOT kernel compilation failed." >&2
  tail -30 "$work/frontend.log" >&2
  exit 1
}

echo "Compiling the AOT snapshot"
if ! "$cache/dart-sdk/bin/utils/gen_snapshot" --deterministic --snapshot_kind=app-aot-elf --elf="$work/app.so" --strip "$work/app.dill" > "$work/gen_snapshot.log" 2>&1; then
  echo "AOT compilation failed. Release builds of this tree will fail too." >&2
  grep -m1 '^==== ' "$work/gen_snapshot.log" | sed 's/^==== /Crashing function: /' >&2 || true
  head -5 "$work/gen_snapshot.log" >&2
  exit 1
fi
echo "AOT snapshot compiled"
