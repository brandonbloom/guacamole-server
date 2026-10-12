#!/bin/bash
# Builds guacd with VNC support on macOS against Homebrew libraries and
# packages it as a relocatable tarball:
#
#   guacd-<version>-macos-<arch>/
#     bin/guacd
#     lib/libguac*.dylib, lib/libguac-client-vnc.dylib, and every non-system
#     dylib they need, with install names rewritten to @executable_path/../lib
#
# Usage: scripts/macos-package.sh VERSION [OUTPUT_DIR]
# Requires: brew install autoconf automake libtool pkgconf cairo jpeg-turbo
#           libpng libvncserver ossp-uuid openssl@3 webp dylibbundler
set -euo pipefail

version="${1:?usage: scripts/macos-package.sh VERSION [OUTPUT_DIR]}"
output="${2:-$PWD/dist}"
arch="$(uname -m)"
[ "$arch" = x86_64 ] || arch=arm64
name="guacd-${version}-macos-${arch}"
brew="$(brew --prefix)"
work="$(mktemp -d)"
stage="$work/$name"

export PKG_CONFIG_PATH="$brew/opt/openssl@3/lib/pkgconfig:$brew/opt/jpeg-turbo/lib/pkgconfig:$brew/lib/pkgconfig"
export CPPFLAGS="-I$brew/include -I$brew/opt/jpeg-turbo/include -I$brew/opt/openssl@3/include -I$brew/opt/ossp-uuid/include"
export LDFLAGS="-L$brew/lib -L$brew/opt/jpeg-turbo/lib -L$brew/opt/openssl@3/lib -L$brew/opt/ossp-uuid/lib"

autoreconf -fi
./configure --prefix="$work/prefix" --disable-static \
    --disable-guacenc --disable-guaclog \
    --without-rdp --without-ssh --without-telnet --without-kubernetes \
    --without-pango --without-pulse --without-vorbis --without-libwebsockets \
    --without-libavcodec --without-libavformat --without-libavutil --without-libswscale
make -j"$(sysctl -n hw.ncpu)"
make install

mkdir -p "$stage/bin" "$stage/lib"
cp "$work/prefix/sbin/guacd" "$stage/bin/"
cp -P "$work/prefix/lib/"libguac*.dylib "$stage/lib/"

# Copy every non-system dependency into lib/ and point the binary and the
# libraries (including the dlopen()ed VNC plugin) at it.
dylibbundler --overwrite-files --bundle-deps --create-dir \
    --dest-dir "$stage/lib" --install-path "@executable_path/../lib/" \
    --search-path "$work/prefix/lib" \
    --fix-file "$stage/bin/guacd" --fix-file "$stage/lib/libguac-client-vnc.dylib"
# libguac and its plugin keep absolute install names from the build prefix.
for file in "$stage/bin/guacd" "$stage/lib/"*.dylib; do
    [ -L "$file" ] && continue
    for dep in $(otool -L "$file" | awk 'NR>1 {print $1}' | grep "^$work/prefix/lib/" || true); do
        install_name_tool -change "$dep" "@executable_path/../lib/$(basename "$dep")" "$file"
    done
    case "$file" in *.dylib) install_name_tool -id "@executable_path/../lib/$(basename "$file")" "$file" ;; esac
done
# Rewriting load commands invalidates signatures; arm64 requires one.
for file in "$stage/bin/guacd" "$stage/lib/"*.dylib; do
    [ -L "$file" ] || codesign --force --sign - "$file"
done

if otool -L "$stage/bin/guacd" "$stage/lib/"*.dylib | grep -E "^[[:space:]]+($brew|$work|/usr/local)/"; then
    echo "✗ the package still refers to build or Homebrew paths" >&2
    exit 1
fi
"$stage/bin/guacd" -v

mkdir -p "$output"
tar -C "$work" -czf "$output/$name.tar.gz" "$name"
(cd "$output" && shasum -a 256 "$name.tar.gz" > "$name.tar.gz.sha256")
echo "$output/$name.tar.gz"
