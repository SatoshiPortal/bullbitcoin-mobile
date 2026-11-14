#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 4 ]; then
  echo "Usage: $0 APK SDK_RUST_VERSION PAYJOIN_RUST_VERSION EXPECTED_ABI..." >&2
  exit 2
fi

apk=$1
sdk_rust=$2
payjoin_rust=$3
shift 3
expected_abis=("$@")

for tool in unzip strings find sort; do
  command -v "$tool" >/dev/null || { echo "Missing required tool: $tool" >&2; exit 1; }
done

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
unzip -tq "$apk" >/dev/null || { echo "Invalid APK: $apk" >&2; exit 1; }
unzip -q "$apk" 'lib/*/*.so' -d "$tmpdir" || { echo "No native libraries in APK: $apk" >&2; exit 1; }

abi_dirs=()
while IFS= read -r abi_dir; do
  abi_dirs+=("$abi_dir")
done < <(find "$tmpdir/lib" -mindepth 1 -maxdepth 1 -type d | sort)
if [ "${#abi_dirs[@]}" -eq 0 ]; then
  echo "No native ABI directories in APK: $apk" >&2
  exit 1
fi

for abi in "${expected_abis[@]}"; do
  if [ ! -d "$tmpdir/lib/$abi" ]; then
    echo "Missing expected ABI: $abi" >&2
    exit 1
  fi
done

for abi_dir in "${abi_dirs[@]}"; do
  abi=${abi_dir##*/}
  expected_abi=false
  for wanted_abi in "${expected_abis[@]}"; do
    if [ "$abi" = "$wanted_abi" ]; then
      expected_abi=true
      break
    fi
  done
  if [ "$expected_abi" = false ]; then
    for so in "$abi_dir"/*.so; do
      case "${so##*/}" in
        libonion.so|librust_lib_bull_sdk.so|libbdk_dart_ffi.so|libpayjoin_ffi_wrapper.so)
          echo "Tracked Rust library in unexpected ABI: $abi/${so##*/}" >&2
          exit 1
          ;;
      esac
      if ! strings "$so" > "$tmpdir/strings"; then
        echo "Cannot inspect library: $abi/${so##*/}" >&2
        exit 1
      fi
      if grep -qE 'rustc version [0-9]' "$tmpdir/strings"; then
        echo "Untracked Rust library in unexpected ABI: $abi/${so##*/}" >&2
        exit 1
      fi
    done
    continue
  fi
  for name in libonion.so librust_lib_bull_sdk.so libbdk_dart_ffi.so libpayjoin_ffi_wrapper.so; do
    so="$abi_dir/$name"
    if [ ! -f "$so" ]; then
      echo "Missing tracked Rust library: $abi/$name" >&2
      exit 1
    fi
    case "$name" in
      libonion.so|librust_lib_bull_sdk.so|libbdk_dart_ffi.so) expected=$sdk_rust ;;
      libpayjoin_ffi_wrapper.so) expected=$payjoin_rust ;;
    esac
    if ! strings "$so" > "$tmpdir/strings"; then
      echo "Cannot inspect Rust library: $abi/$name" >&2
      exit 1
    fi
    if ! grep -oE 'rustc version [0-9][0-9A-Za-z.+-]*' "$tmpdir/strings" > "$tmpdir/markers"; then
      echo "No rustc version marker: $abi/$name" >&2
      exit 1
    fi
    sort -u "$tmpdir/markers" > "$tmpdir/versions"
    if [ "$(wc -l < "$tmpdir/versions")" -ne 1 ] || [ "$(cat "$tmpdir/versions")" != "rustc version $expected" ]; then
      echo "Unexpected rustc markers in $abi/$name (expected $expected):" >&2
      cat "$tmpdir/versions" >&2
      exit 1
    fi
    echo "$abi/$name: rustc $expected"
  done
  for so in "$abi_dir"/*.so; do
    case "${so##*/}" in
      libonion.so|librust_lib_bull_sdk.so|libbdk_dart_ffi.so|libpayjoin_ffi_wrapper.so) continue ;;
    esac
    if ! strings "$so" > "$tmpdir/strings"; then
      echo "Cannot inspect library: $abi/${so##*/}" >&2
      exit 1
    fi
    if grep -qE 'rustc version [0-9]' "$tmpdir/strings"; then
      echo "Untracked Rust library: $abi/${so##*/}" >&2
      exit 1
    fi
  done
done
