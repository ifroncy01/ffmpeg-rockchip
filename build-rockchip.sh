#!/bin/bash
# Build FFmpeg with Rockchip MPP + RGA hardware acceleration
# Source: https://github.com/ifroncy01/ffmpeg-rockchip
#
# Usage: ./build-rockchip.sh [--prefix /usr] [--skip-deps] [--skip-mpp] [--skip-rga]

set -euo pipefail

PREFIX="/usr"
SKIP_DEPS=false
SKIP_MPP=false
SKIP_RGA=false
JOBS="${JOBS:-$(nproc)}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --prefix) PREFIX="$2"; shift 2 ;;
        --skip-deps) SKIP_DEPS=true; shift ;;
        --skip-mpp) SKIP_MPP=true; shift ;;
        --skip-rga) SKIP_RGA=true; shift ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TMP_DIR="$(mktemp -d -t ffmpeg-build-XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

echo "=== FFmpeg Rockchip Build ==="
echo "Prefix:   $PREFIX"
echo "Jobs:     $JOBS"
echo "Temp:     $TMP_DIR"
echo ""

# 1. System dependencies
if ! $SKIP_DEPS; then
    echo ">>> Installing build dependencies..."
    sudo apt-get update -qq
    sudo apt-get install -y -qq \
        build-essential git pkg-config cmake meson ninja-build nasm yasm \
        libdrm-dev libx264-dev libx265-dev libvpx-dev \
        libfdk-aac-dev libmp3lame-dev libopus-dev libvorbis-dev libass-dev \
        libsdl2-dev
fi

# 2. Build rockchip-mpp from source
if ! $SKIP_MPP && ! pkg-config --exists rockchip_mpp; then
    echo ">>> Building rockchip-mpp..."
    git clone --depth=1 https://github.com/rockchip-linux/mpp.git "$TMP_DIR/mpp"
    cd "$TMP_DIR/mpp"

    # Build in a separate build directory; CMakeLists.txt is at repo root
    mkdir -p build && cd build
    cmake -DCMAKE_INSTALL_PREFIX="$PREFIX" \
          -DCMAKE_BUILD_TYPE=Release \
          -DCMAKE_INSTALL_LIBDIR=lib \
          ..
    make -j"$JOBS"
    sudo make install
    sudo ldconfig
    echo ">>> MPP: $(pkg-config --modversion rockchip_mpp)"
else
    echo ">>> rockchip-mpp: already installed, skipping"
fi

# 3. Install librga from ifroncy01/librga
if ! $SKIP_RGA && ! pkg-config --exists librga; then
    echo ">>> Installing librga..."
    git clone --depth=1 https://github.com/ifroncy01/librga.git "$TMP_DIR/librga"
    cd "$TMP_DIR/librga"

    # Install headers
    sudo mkdir -p "$PREFIX/include/rga"
    sudo cp include/*.h "$PREFIX/include/rga/"

    # Install prebuilt library
    libdir="$PREFIX/lib"
    [ -d "$PREFIX/lib/aarch64-linux-gnu" ] && libdir="$PREFIX/lib/aarch64-linux-gnu"
    sudo cp libs/Linux/gcc-aarch64/librga.so "$libdir/librga.so.2.1.0"
    sudo ln -sf librga.so.2.1.0 "$libdir/librga.so.2"
    sudo ln -sf librga.so.2 "$libdir/librga.so"
    sudo ldconfig

    # Create pkg-config file
    pcdir="$PREFIX/lib/pkgconfig"
    [ -d "$PREFIX/lib/aarch64-linux-gnu/pkgconfig" ] && pcdir="$PREFIX/lib/aarch64-linux-gnu/pkgconfig"
    sudo mkdir -p "$pcdir"
    sudo tee "$pcdir/librga.pc" > /dev/null << EOF
prefix=$PREFIX
libdir=$libdir
includedir=$PREFIX/include

Name: librga
Description: Userspace interface to Rockchip RGA 2D accelerator
Version: 2.1.0
Libs: -L\${libdir} -lrga
Cflags: -I\${includedir}
EOF
    echo ">>> RGA installed"
else
    echo ">>> librga: already installed, skipping"
fi

# 4. Build ffmpeg-rockchip
echo ">>> Configuring FFmpeg..."
cd "$SCRIPT_DIR"

pkg-config --exists rockchip_mpp || { echo "ERROR: rockchip_mpp not found"; exit 1; }
pkg-config --exists librga || { echo "ERROR: librga not found"; exit 1; }

./configure \
    --prefix="$PREFIX" \
    --enable-gpl --enable-version3 --enable-nonfree \
    --enable-libdrm --enable-rkmpp --enable-rkrga \
    --enable-libx264 --enable-libx265 --enable-libvpx \
    --enable-libfdk-aac --enable-libmp3lame \
    --enable-libopus --enable-libvorbis --enable-libass

echo ">>> Building FFmpeg..."
make -j"$JOBS"

echo ""
echo "=== Build complete ==="
echo "  ffmpeg:  $(./ffmpeg -version 2>&1 | head -1)"
echo "  hwaccels: $(./ffmpeg -hwaccels 2>&1 | grep rkmpp)"
echo ""
echo "Install:  sudo make install"
echo "Test:     ffmpeg -hwaccels | grep rkmpp"