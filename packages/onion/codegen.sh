#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
if [[ "$(flutter_rust_bridge_codegen --version)" != "flutter_rust_bridge_codegen 2.13.0" ]]; then
  echo "flutter_rust_bridge_codegen 2.13.0 is required" >&2
  exit 1
fi
flutter_rust_bridge_codegen generate "$@"
python3 ../../tools/patch_frb_native_assets.py lib/src/rust/frb_generated.dart
