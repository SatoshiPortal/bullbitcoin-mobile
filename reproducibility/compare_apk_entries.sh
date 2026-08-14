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
    # List entries as their own step first: if unzip can't read the archive
    # (missing/corrupt/truncated file, bad mount path) it must ABORT, not emit
    # an empty list that would later compare "equal" to another empty list and
    # yield a false IDENTICAL. `set -e` does not catch a failure mid-pipeline,
    # so the listing is captured and checked explicitly.
    entries=$(unzip -Z1 "$1") || { echo "error: cannot read zip entries from $1" >&2; return 3; }
    entry_tmp=$(mktemp)
    printf '%s\n' "$entries" | grep -Ev "$exclude_re" | LC_ALL=C sort | while IFS= read -r entry; do
        [ -n "$entry" ] || continue
        # unzip -p treats the member name as a shell-glob PATTERN: an entry name
        # containing * ? [ ] would extract some OTHER pattern-matched entry
        # (identically in both APKs), hashing a real byte difference as equal —
        # a false IDENTICAL. Escape the glob metacharacters so the name matches
        # literally. (-\ escaping per Info-ZIP's pattern syntax.)
        escaped=$(printf '%s' "$entry" | sed 's/[][*?\\]/\\&/g')
        # Extract to a temp file so we can check unzip's exit status: POSIX sh
        # has no pipefail, so `unzip -p ... | sha256sum` would hash empty input
        # and report success even when extraction failed — comparing the same
        # unreadable entry in both APKs would then hash equal (empty==empty) and
        # its real bytes would never be compared. A failed extraction ABORTS.
        if ! unzip -p "$1" "$escaped" > "$entry_tmp" 2>/dev/null; then
            echo "error: cannot extract entry '$entry' from $1" >&2
            rm -f "$entry_tmp"
            exit 3
        fi
        hash=$(sha256sum < "$entry_tmp" | awk '{print $1}')
        printf '%s  %s\n' "$hash" "$entry"
    done
    rc=$?
    rm -f "$entry_tmp"
    return $rc
}

tmp1=$(mktemp)
tmp2=$(mktemp)
trap 'rm -f "$tmp1" "$tmp2"' EXIT

hash_entries "$apk1" > "$tmp1" || exit 2
hash_entries "$apk2" > "$tmp2" || exit 2

# A readable APK always has at least one comparable entry. Empty output means
# the archive was empty or unreadable — treating that as "identical" would be a
# false reproducible verdict, so it is an error (exit 2), never exit 0.
if [ ! -s "$tmp1" ] || [ ! -s "$tmp2" ]; then
    echo "error: no comparable entries found (empty or unreadable APK)" >&2
    exit 2
fi

if diff -u "$tmp1" "$tmp2"; then
    echo "IDENTICAL"
    exit 0
else
    exit 1
fi
