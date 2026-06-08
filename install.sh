#!/bin/bash
# FFmpeg Rockchip 全家桶一键安装脚本
#   librga → ffmpeg-rockchip → mpv-rockchip
#
# 用法:
#   curl -fsSL https://raw.githubusercontent.com/ifroncy01/ffmpeg-rockchip/master/install.sh | sudo bash
#   sudo ./install.sh [--skip-rga] [--skip-ffmpeg] [--skip-mpv]

set -euo pipefail

SKIP_RGA=false
SKIP_FFMPEG=false
SKIP_MPV=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --skip-rga)    SKIP_RGA=true; shift ;;
        --skip-ffmpeg) SKIP_FFMPEG=true; shift ;;
        --skip-mpv)    SKIP_MPV=true; shift ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

REPO_RGA="ifroncy01/librga"
REPO_FFMPEG="ifroncy01/ffmpeg-rockchip"
REPO_MPV="ifroncy01/mpv-rockchip"
WORK_DIR="$(mktemp -d -t ffmpeg-install-XXXXXX)"
trap 'rm -rf "$WORK_DIR"' EXIT

echo "============================================"
echo " Rockchip 媒体全家桶 一键安装"
echo "  librga → ffmpeg → mpv"
echo "============================================"
echo ""

# Step 1: librga
if ! $SKIP_RGA; then
    echo ">>> [1/3] 下载 librga ..."
    curl -fsSL -o "$WORK_DIR/librga.tar.gz" \
        "https://github.com/${REPO_RGA}/releases/latest/download/librga-aarch64.tar.gz" || {
        echo "ERROR: 无法下载 librga，请确认 latest release 已构建完成"
        exit 1
    }
    echo ">>> [1/3] 安装 librga ..."
    tar -xzf "$WORK_DIR/librga.tar.gz" -C /
    ldconfig
    echo "    librga OK"
fi

# Step 2: ffmpeg-rockchip + ffplay desktop
if ! $SKIP_FFMPEG; then
    echo ">>> [2/3] 下载 FFmpeg Rockchip ..."
    curl -fsSL -o "$WORK_DIR/ffmpeg-rockchip.tar.gz" \
        "https://github.com/${REPO_FFMPEG}/releases/latest/download/ffmpeg-rockchip-aarch64.tar.gz" || {
        echo "ERROR: 无法下载 ffmpeg-rockchip，请确认 latest release 已构建完成"
        exit 1
    }
    echo ">>> [2/3] 安装 FFmpeg Rockchip (+ ffplay 桌面入口) ..."
    tar -xzf "$WORK_DIR/ffmpeg-rockchip.tar.gz" -C /
    ldconfig
    # Refresh desktop database so ffplay shows up in app menus
    update-desktop-database /usr/share/applications 2>/dev/null || true
    echo "    FFmpeg + ffplay OK"
fi

# Step 3: mpv-rockchip
if ! $SKIP_MPV; then
    echo ">>> [3/3] 下载 mpv Rockchip ..."
    curl -fsSL -o "$WORK_DIR/mpv-rockchip.tar.gz" \
        "https://github.com/${REPO_MPV}/releases/latest/download/mpv-rockchip-aarch64.tar.gz" || {
        echo "WARNING: 无法下载 mpv-rockchip (仓库可能尚未就绪)，跳过"
        echo "  mpv 仓库地址: https://github.com/${REPO_MPV}"
    }
    if [ -f "$WORK_DIR/mpv-rockchip.tar.gz" ]; then
        echo ">>> [3/3] 安装 mpv Rockchip ..."
        tar -xzf "$WORK_DIR/mpv-rockchip.tar.gz" -C /
        ldconfig
        update-desktop-database /usr/share/applications 2>/dev/null || true
        echo "    mpv OK"
    fi
fi

echo ""
echo "============================================"
echo " 安装完成！验证:"
echo "============================================"

if command -v ffmpeg &>/dev/null; then
    echo ""
    echo "  ffmpeg : $(ffmpeg -version 2>&1 | head -1)"
    echo "  hwaccel: $(ffmpeg -hwaccels 2>&1 | grep -o rkmpp || echo 'N/A')"
    echo "  rkrga  : $(ffmpeg -filters 2>&1 | grep -o rkrga || echo 'N/A')"
fi

if command -v ffplay &>/dev/null; then
    echo "  ffplay : 已安装 (桌面菜单: FFplay Rockchip HW)"
else
    echo "  ffplay : 未安装 (构建时可能缺少 SDL2)"
fi

if command -v mpv &>/dev/null; then
    echo ""
    echo "  mpv    : $(mpv --version 2>&1 | head -1)"
fi

echo ""
echo "=== 桌面播放器入口 ==="
echo "  ffplay : 应用程序菜单 → FFplay (Rockchip HW)"
echo "  mpv    : 应用程序菜单 → mpv (Rockchip HW)"
echo ""

echo "清理临时文件..."
rm -rf "$WORK_DIR"
echo "完成！"