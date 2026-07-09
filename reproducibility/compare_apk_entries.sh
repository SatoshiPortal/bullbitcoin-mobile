#!/bin/sh
# Compares two APKs by hashing every zip entry's raw content, ignoring only
# legacy JAR signature files (MANIFEST.MF / *.RSA / *.SF / *.EC / *.DSA).
# Those exist purely because one APK may be signed and a from-source
# reproducibility build deliberately is not — everything else in META-INF
# (androidx *.version files, META-INF/services/* ServiceLoader registrations,
# app-metadata.properties, version-control-info.textproto, ...) is real
# shipped content and must be compared, not blanket-excluded.
#
# This is the authoritative verdict for reproducibility verification. Unlike
# a diff of apktool's decoded output, it cannot be fooled by normalization:
# baksmali can re-emit different dex bytes (map-list ordering, padding,
# debug-info encoding) as identical smali, and aapt2's resources.arsc can
# decode to identical XML from different underlying bytes. Hashing the actual
# shipped bytes of every entry has no such blind spot. The APK Signing Block
# (v2/v3 signatures) lives outside the zip's regular entries, so signing
# never perturbs these hashes.
set -eu

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <apk1> <apk2>" >&2
    exit 2
fi

apk1="$1"
apk2="$2"
exclude_re='^META-INF/(MANIFEST\.MF|[^/]+\.(RSA|SF|EC|DSA))$'

hash_entries() {
    unzip -Z1 "$1" | grep -Ev "$exclude_re" | LC_ALL=C sort | while IFS= read -r entry; do
        hash=$(unzip -p "$1" "$entry" 2>/dev/null | sha256sum | awk '{print $1}')
        printf '%s  %s\n' "$hash" "$entry"
    done
}

tmp1=$(mktemp)
tmp2=$(mktemp)
trap 'rm -f "$tmp1" "$tmp2"' EXIT

hash_entries "$apk1" > "$tmp1"
hash_entries "$apk2" > "$tmp2"

if diff -u "$tmp1" "$tmp2"; then
    echo "IDENTICAL"
    exit 0
else
    exit 1
fi
