#!/bin/bash
# Runs inside the bull-mobile container to build an AAB + universal APK.
#
# Required env:
#   MODE              debug | release
#   GRADLE_HEAP       Gradle JVM heap (e.g. 4g)
#
# Release mode: if release signing creds are provided, the AAB is signed with
# jarsigner and the APK is signed with the release key via bundletool. If none
# are provided, the release AAB stays unsigned and the APK is debug-signed so
# third parties can reproduce the build without the release keystore.
# To sign for publishing, provide all of:
#   KEYSTORE_FILE     basename of the keystore (directory bind-mounted at /keys)
#   KEYSTORE_PASS     keystore password
#   KEY_ALIAS         signing key alias
#   KEY_PASS          key password

set -euo pipefail

cd /app

if [ -f /app/android/key.properties ]; then
    echo "❌ Found android/key.properties in repo."
    echo "   Docker builds must not rely on a committed key.properties."
    echo "   Pass signing credentials via env vars to 'make build release' instead."
    exit 1
fi

mkdir -p "$HOME/.gradle"
{
    echo "org.gradle.daemon=false"
    echo "org.gradle.jvmargs=-Xmx${GRADLE_HEAP:-4g} -XX:+HeapDumpOnOutOfMemoryError"
} > "$HOME/.gradle/gradle.properties"

fvm flutter pub get
fvm dart run build_runner build --delete-conflicting-outputs
fvm flutter gen-l10n

export SOURCE_DATE_EPOCH
SOURCE_DATE_EPOCH=$(git -C /app log -1 --format=%ct)
export CARGO_PROFILE_RELEASE_CODEGEN_UNITS=1

# Remap absolute build paths so .so files don't embed the host/container
# username, cargo cache location, or source mount point. Without this, a build
# in the devcontainer (USERNAME=<your login>) produces different binaries than
# `make build` (USERNAME=bull), even from the same commit.
export CARGO_ENCODED_RUSTFLAGS=$(printf '%s\037%s\037%s' \
    "--remap-path-prefix=$HOME/.cargo=/cargo" \
    "--remap-path-prefix=$HOME/.rustup=/rustup" \
    "--remap-path-prefix=/app=/build")

fvm flutter build appbundle --"${MODE}"

AAB="/app/build/app/outputs/bundle/${MODE}/app-${MODE}.aab"

if [ "${MODE}" = "release" ] && [ -n "${KEYSTORE_FILE:-}" ]; then
    : "${KEYSTORE_PASS:?release signing requires all of KEYSTORE_FILE, KEYSTORE_PASS, KEY_ALIAS, KEY_PASS}"
    : "${KEY_ALIAS:?release signing requires all of KEYSTORE_FILE, KEYSTORE_PASS, KEY_ALIAS, KEY_PASS}"
    : "${KEY_PASS:?release signing requires all of KEYSTORE_FILE, KEYSTORE_PASS, KEY_ALIAS, KEY_PASS}"

    jarsigner -keystore "/keys/${KEYSTORE_FILE}" \
        -storepass:env KEYSTORE_PASS \
        -keypass:env KEY_PASS \
        "${AAB}" "${KEY_ALIAS}"

    # bundletool only understands pass:<literal> or file:<path> — no env: variant.
    # Write passwords to a 0700 tmpdir so they don't end up in /proc/*/cmdline.
    pw_dir=$(mktemp -d)
    chmod 700 "$pw_dir"
    trap 'rm -rf "$pw_dir"' EXIT
    printf '%s' "${KEYSTORE_PASS}" > "$pw_dir/store"
    printf '%s' "${KEY_PASS}" > "$pw_dir/key"

    bundletool build-apks \
        --bundle="${AAB}" \
        --output=/tmp/app.apks \
        --mode=universal \
        --ks="/keys/${KEYSTORE_FILE}" \
        --ks-pass="file:$pw_dir/store" \
        --ks-key-alias="${KEY_ALIAS}" \
        --key-pass="file:$pw_dir/key" \
        --overwrite
else
    bundletool build-apks \
        --bundle="${AAB}" \
        --output=/tmp/app.apks \
        --mode=universal \
        --ks=/app/android/app/debug.keystore \
        --ks-pass=pass:android \
        --ks-key-alias=androiddebugkey \
        --key-pass=pass:android \
        --overwrite
fi

unzip -p /tmp/app.apks universal.apk > "/app/app-${MODE}.apk"
cp "${AAB}" "/app/app-${MODE}.aab"

echo "✅ Built: /app/app-${MODE}.aab and /app/app-${MODE}.apk"
sha256sum "/app/app-${MODE}.aab" "/app/app-${MODE}.apk"
