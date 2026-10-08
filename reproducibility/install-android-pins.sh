#!/bin/bash
set -euo pipefail
sdk_root="${1:?Android SDK root required}"
api="${2:?Android API level required}"
build_tools="${3:-36.0.0}"
ndk="${4:-29.0.14206865}"
# Review archives together with android/gradle.properties on toolchain updates.
[[ "$api/$build_tools/$ndk" == 36/36.0.0/29.0.14206865 ]] || { echo "No reviewed Android archive set for API=$api build-tools=$build_tools NDK=$ndk" >&2; exit 1; }
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
install_archive() {
    local archive="$1" checksum="$2" directory="$3" layout="${4:-nested}"
    curl --proto '=https' --tlsv1.2 -fsSL "https://dl.google.com/android/repository/$archive" -o "$tmp/package.zip"
    echo "$checksum  $tmp/package.zip" | sha256sum -c -
    mkdir "$tmp/unpack"
    unzip -q "$tmp/package.zip" -d "$tmp/unpack"
    local roots=("$tmp/unpack"/*)
    if [[ "$layout" == nested ]]; then
        [[ ${#roots[@]} == 1 && -d "${roots[0]}" ]] || { echo "Unexpected SDK archive layout" >&2; exit 1; }
    else
        [[ -f "$tmp/unpack/source.properties" && -x "$tmp/unpack/bin/cmake" ]] || { echo "Unexpected CMake archive layout" >&2; exit 1; }
    fi
    [[ ! -e "$sdk_root/$directory" ]] || { echo "Refusing to replace existing SDK package $directory" >&2; exit 1; }
    mkdir -p "$(dirname "$sdk_root/$directory")"
    if [[ "$layout" == nested ]]; then
        mv "${roots[0]}" "$sdk_root/$directory"
        rmdir "$tmp/unpack"
    else
        mv "$tmp/unpack" "$sdk_root/$directory"
    fi
    # Generic SDK packages (NDK/CMake) need local metadata for AGP/sdkmanager.
    # The standalone archives omit package.xml; without it AGP may download again.
    if [[ "$directory" == ndk/* || "$directory" == cmake/* ]]; then
        local revision="${directory#*/}" major minor micro
        IFS=. read -r major minor micro <<< "$revision"
        printf '%s\n' \
            '<?xml version="1.0" encoding="UTF-8"?>' \
            '<sdk:repository xmlns:sdk="http://schemas.android.com/repository/android/common/02" xmlns:generic="http://schemas.android.com/repository/android/generic/02" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">' \
            "<localPackage path=\"${directory/\//;}\" obsolete=\"false\">" \
            '<type-details xsi:type="generic:genericDetailsType"/>' \
            "<revision><major>$major</major><minor>$minor</minor><micro>$micro</micro></revision>" \
            "<display-name>${directory/\// }</display-name>" \
            '</localPackage></sdk:repository>' > "$sdk_root/$directory/package.xml"
    fi
}
install_archive platform-tools_r37.0.1-linux.zip d230f13842f60f782a8645f9c813f8f845bf36089ea7289f28c48f17979313f1 platform-tools
install_archive platform-36_r02.zip 37607369a28c5b640b3a7998868d45898ebcb777565a0e85f9acf36f29631d2e platforms/android-36
install_archive android-ndk-r29-linux.zip 4abbbcdc842f3d4879206e9695d52709603e52dd68d3c1fff04b3b5e7a308ecf ndk/29.0.14206865
install_archive android-ndk-r28c-linux.zip dfb20d396df28ca02a8c708314b814a4d961dc9074f9a161932746f815aa552f ndk/28.2.13676358
install_archive android-ndk-r27-linux.zip 2f17eb8bcbfdc40201c0b36e9a70826fcd2524ab7a2a235e2c71186c302da1dc ndk/27.0.12077973
install_archive build-tools_r36_linux.zip 5d9ac77fb6ff43d9da518a337b4fcf8f9097113df531d99ccefe80ef7ce8250b build-tools/36.0.0
install_archive cmake-3.22.1-linux.zip 9196644852a978012caf7a4067ba1898debf6cc204c3341562771e31080d6869 cmake/3.22.1 flat
