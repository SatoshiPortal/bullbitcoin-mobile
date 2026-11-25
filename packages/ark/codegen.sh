#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
if [[ "$(flutter_rust_bridge_codegen --version)" != "flutter_rust_bridge_codegen 2.13.0" ]]; then
  echo "flutter_rust_bridge_codegen 2.13.0 is required" >&2
  exit 1
fi
export FVM_EXECUTABLE
FVM_EXECUTABLE="$(command -v fvm)"
tool_dir="$(mktemp -d)"
trap 'rm -rf "$tool_dir"' EXIT
cat > "$tool_dir/fvm" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "install" ]]; then exit 0; fi
exec "$FVM_EXECUTABLE" "$@"
EOF
cat > "$tool_dir/dart" <<'EOF'
#!/usr/bin/env bash
exec "$FVM_EXECUTABLE" dart "$@"
EOF
chmod +x "$tool_dir/fvm" "$tool_dir/dart"
PATH="$tool_dir:$PATH" flutter_rust_bridge_codegen generate --skip-fvm-install "$@"
python3 ../../tools/patch_frb_native_assets.py lib/src/rust/frb_generated.dart
python3 patch_frb_secret.py lib/src/rust/frb_generated.dart
