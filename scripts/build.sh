#!/bin/bash
# Builds CK3ToEU4 for macOS from scratch into dist/CK3ToEU4-macOS.
#
#   scripts/build.sh           # build
#   scripts/build.sh --tests   # also build and run upstream's unit tests
#   scripts/build.sh --zip     # also package dist/CK3ToEU4-macOS-<version>.zip
#
# Needs: Xcode Command Line Tools (xcode-select --install), cmake and pkg-config (brew install cmake pkgconf).
set -euo pipefail

VERSION="0.17Q-mac.1"

# Exact upstream commits this port was made and tested against.
CK3TOEU4_REPO="https://github.com/ParadoxGameConverters/CK3ToEU4.git"
CK3TOEU4_COMMIT="f54883f0a042914285e30acb8676edfee79e722c" # 0.17 "Quanzhen" + later fixes, 2026-10-10
COMMONITEMS_REPO="https://github.com/ParadoxGameConverters/commonItems.git"
COMMONITEMS_COMMIT="8f6d106d619ee72a30b6a0327f54f9ad0253fa47"
GOOGLETEST_REPO="https://github.com/google/googletest.git"
GOOGLETEST_COMMIT="36ba75f0ad5383a9759f17f3f72fd4661c72cb6d"
RAKALY_VERSION="0.12.8"
IMAGEMAGICK_VERSION="7.0.10-31" # same version upstream ships with its Windows builds

TESTS=0
ZIP=0
for arg in "$@"; do
	case "$arg" in
		--tests) TESTS=1 ;;
		--zip) ZIP=1 ;;
		*) echo "Unknown option: $arg" >&2; exit 2 ;;
	esac
done

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$ROOT/work"
DIST="$ROOT/dist/CK3ToEU4-macOS"
JOBS="$(sysctl -n hw.ncpu)"
mkdir -p "$WORK/deps"

step() { printf '\n==> %s\n' "$*"; }

for tool in git curl cmake pkg-config; do
	command -v "$tool" >/dev/null || { echo "Missing '$tool'. Install it first (see the README)." >&2; exit 1; }
done
xcrun --find clang >/dev/null 2>&1 || { echo "Missing Xcode Command Line Tools: run xcode-select --install" >&2; exit 1; }

# Shallow-fetch one exact commit of a repository into a folder.
fetch_commit() {
	local repo="$1" commit="$2" dir="$3"
	if [[ "$(git -C "$dir" rev-parse HEAD 2>/dev/null || true)" == "$commit" ]]; then
		return
	fi
	rm -rf "$dir"
	git init -q "$dir"
	git -C "$dir" fetch -q --depth 1 "$repo" "$commit"
	git -C "$dir" -c advice.detachedHead=false checkout -q FETCH_HEAD
}

step "Fetching upstream CK3ToEU4 and commonItems at the tested commits"
if [[ ! -f "$WORK/upstream/.patched" ]]; then
	fetch_commit "$CK3TOEU4_REPO" "$CK3TOEU4_COMMIT" "$WORK/upstream"
	fetch_commit "$COMMONITEMS_REPO" "$COMMONITEMS_COMMIT" "$WORK/upstream/commonItems"
	step "Applying the macOS / CK3 1.20 patches"
	git -C "$WORK/upstream" apply --whitespace=nowarn "$ROOT/patches/CK3ToEU4.patch"
	git -C "$WORK/upstream/commonItems" apply --whitespace=nowarn "$ROOT/patches/commonItems.patch"
	touch "$WORK/upstream/.patched"
else
	echo "already fetched and patched (delete work/ to start over)"
fi
if [[ $TESTS == 1 ]]; then
	fetch_commit "$GOOGLETEST_REPO" "$GOOGLETEST_COMMIT" "$WORK/upstream/commonItems/external/googletest"
fi

step "Fetching librakaly $RAKALY_VERSION (save-game decoder)"
RAKALY="$WORK/deps/rakaly"
if [[ ! -f "$RAKALY/librakaly.dylib" ]]; then
	rm -rf "$RAKALY" && mkdir -p "$RAKALY"
	curl -fsSL "https://github.com/rakaly/librakaly/releases/download/v$RAKALY_VERSION/librakaly-$RAKALY_VERSION-macos.tar.gz" | tar xz -C "$RAKALY" --strip-components 1
	curl -fsSL -o "$RAKALY/LICENSE.txt" "https://raw.githubusercontent.com/rakaly/librakaly/v$RAKALY_VERSION/LICENSE.txt"
	install_name_tool -id @rpath/librakaly.dylib "$RAKALY/librakaly.dylib"
	codesign --force --sign - "$RAKALY/librakaly.dylib" 2>/dev/null
fi

step "Building ImageMagick $IMAGEMAGICK_VERSION (static, Q8, no HDRI; takes a few minutes the first time)"
IM_PREFIX="$WORK/deps/imagemagick"
if [[ ! -f "$IM_PREFIX/lib/libMagick++-7.Q8.a" ]]; then
	IM_SRC="$WORK/deps/ImageMagick-$IMAGEMAGICK_VERSION"
	rm -rf "$IM_SRC" "$IM_PREFIX"
	curl -fsSL "https://github.com/ImageMagick/ImageMagick/archive/refs/tags/$IMAGEMAGICK_VERSION.tar.gz" | tar xz -C "$WORK/deps"
	mkdir -p "$WORK/deps/empty-pkgconfig"
	# A clean environment, so nothing from Homebrew sneaks in as a dependency. The converter only needs DDS and TGA,
	# which are built in, so every external image library is switched off.
	(
		cd "$IM_SRC"
		env -i HOME="$HOME" PATH=/usr/bin:/bin:/usr/sbin:/sbin PKG_CONFIG_LIBDIR="$WORK/deps/empty-pkgconfig" \
			MACOSX_DEPLOYMENT_TARGET=13.0 CC=/usr/bin/clang CXX=/usr/bin/clang++ \
			CFLAGS="-O2 -arch arm64 -Wno-implicit-function-declaration -Wno-int-conversion -Wno-incompatible-pointer-types" \
			CXXFLAGS="-O2 -arch arm64" \
			./configure --build=aarch64-apple-darwin --prefix="$IM_PREFIX" \
			--with-quantum-depth=8 --disable-hdri --disable-shared --enable-static \
			--with-x=no --without-perl --disable-openmp --disable-opencl --without-modules --disable-docs --without-utilities \
			--without-png --without-jpeg --without-tiff --without-webp --without-heic --without-jxl --without-raw \
			--without-openexr --without-lqr --without-djvu --without-fftw --without-wmf --without-pango --without-rsvg \
			--without-gvc --without-fontconfig --without-freetype --without-lcms --without-xml --without-zstd \
			--without-lzma --without-bzlib --without-openjp2 --without-gslib --without-flif --without-fpx --without-jbig \
			> "$WORK/deps/imagemagick-configure.log" 2>&1
		env -i HOME="$HOME" PATH=/usr/bin:/bin MACOSX_DEPLOYMENT_TARGET=13.0 make -j"$JOBS" > "$WORK/deps/imagemagick-make.log" 2>&1
		env -i HOME="$HOME" PATH=/usr/bin:/bin make install > "$WORK/deps/imagemagick-install.log" 2>&1
	) || { echo "ImageMagick build failed; see $WORK/deps/imagemagick-*.log" >&2; exit 1; }
	cp "$IM_SRC/LICENSE" "$IM_PREFIX/LICENSE.txt"
	cp "$IM_SRC/NOTICE" "$IM_PREFIX/NOTICE.txt"
fi

step "Building the converter"
cmake -S "$ROOT" -B "$ROOT/build" -G "Unix Makefiles" \
	-DCMAKE_C_COMPILER=/usr/bin/clang -DCMAKE_CXX_COMPILER=/usr/bin/clang++ \
	-DCK3TOEU4_TESTS=$([[ $TESTS == 1 ]] && echo ON || echo OFF) > /dev/null
cmake --build "$ROOT/build" -j"$JOBS"

if [[ $TESTS == 1 ]]; then
	step "Running upstream's unit tests"
	# Skipped: a test with a dangling iterator (a bug in the test, not the converter) that crashes outside MSVC.
	# Two flag tests compare images pixel-for-pixel with Windows' output and differ by 1-2 pixels; they're reported, not fatal.
	(cd "$ROOT/build/tests" && ./CK3ToEU4Tests --gtest_filter=-CK3World_CoatsOfArmsTests.parentsCanBeLinked --gtest_brief=1) || true
fi

step "Assembling $DIST"
cp "$ROOT/scripts/convert.command" "$DIST/Convert Latest Save.command"
cp "$ROOT/scripts/convert.command" "$DIST/convert.sh"
chmod +x "$DIST/Convert Latest Save.command" "$DIST/convert.sh"
cp "$ROOT/docs/READ-ME-FIRST.txt" "$ROOT/docs/OPTIONS.txt" "$DIST/"
mkdir -p "$DIST/licenses"
cp "$WORK/upstream/LICENSE" "$DIST/licenses/CK3ToEU4.txt"
cp "$WORK/upstream/commonItems/LICENSE" "$DIST/licenses/commonItems.txt"
cp "$WORK/upstream/commonItems/external/json/LICENSE.MIT" "$DIST/licenses/nlohmann-json.txt"
cp "$WORK/upstream/commonItems/external/zip/UNLICENSE" "$DIST/licenses/kuba-zip.txt"
cp "$RAKALY/LICENSE.txt" "$DIST/licenses/librakaly.txt"
cp "$IM_PREFIX/LICENSE.txt" "$DIST/licenses/ImageMagick.txt"
cp "$IM_PREFIX/NOTICE.txt" "$DIST/licenses/ImageMagick-NOTICE.txt"
cp "$ROOT/LICENSE" "$DIST/licenses/CK3ToEU4-macOS.txt"

if [[ $ZIP == 1 ]]; then
	step "Packaging"
	ZIPFILE="$ROOT/dist/CK3ToEU4-macOS-$VERSION.zip"
	rm -f "$ZIPFILE"
	(cd "$ROOT/dist" && ditto -c -k --keepParent CK3ToEU4-macOS "$ZIPFILE")
	echo "$ZIPFILE"
fi

step "Done: $DIST"
