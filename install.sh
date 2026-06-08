#!/bin/bash
# FFmpeg Rockchip 一键下载安装脚本
# 用法: curl -fsSL https://raw.githubusercontent.com/ifroncy01/ffmpeg-rockchip/master/install.sh | sudo bash
#
# 也支持本地执行: sudo ./install.sh [--skip-rga] [--skip-ffmpeg]

set -euo pipefail

SKIP_RGA=false
SKIP_FFMPEG=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --skip-rga)    SKIP_RGA=true; shift ;;
        --skip-ffmpeg) SKIP_FFMPEG=true; shift ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

REPO_RGA="ifroncy01/librga"
REPO_FFMPEG="ifroncy01/ffmpeg-rockchip"
WORK_DIR="$(mktemp -d -t ffmpeg-install-XXXXXX)"
trap 'rm -rf "$WORK_DIR"' EXIT

echo "============================================"
echo " FFmpeg Rockchip 一键安装"
echo "============================================"
echo ""

# Install librga
if ! $SKIP_RGA; then
    echo ">>> 下载 librga ..."
    RGA_URL="https://github.com/${REPO_RGA}/releases/latest/download/librga-aarch64.tar.gz"
    curl -fsSL -o "$WORK_DIR/librga.tar.gz" "$RGA_URL" || {
        echo "ERROR: 无法下载 librga，请确认 ${REPO_RGA} 的 latest release 已构建完成"
        exit 1
    }
    echo ">>> 安装 librga ..."
    tar -xzf "$WORK_DIR/librga.tar.gz" -C /
    ldconfig
    echo "    librga 安装完成"
fi

# Install ffmpeg-rockchip
if ! $SKIP_FFMPEG; then
    echo ">>> 下载 FFmpeg Rockchip ..."
    FFMPEG_URL="https://github.com/${REPO_FFMPEG}/releases/latest/download/ffmpeg-rockchip-aarch64.tar.gz"
    curl -fsSL -o "$WORK_DIR/ffmpeg-rockchip.tar.gz" "$FFMPEG_URL" || {
        echo "ERROR: 无法下载 ffmpeg-rockchip，请确认 ${REPO_FFMPEG} 的 latest release 已构建完成"
        exit 1
    }
    echo ">>> 安装 FFmpeg Rockchip ..."
    tar -xzf "$WORK_DIR/ffmpeg-rockchip.tar.gz" -C /
    ldconfig
    echo "    FFmpeg Rockchip 安装完成"
fi

echo ""
echo "============================================"
echo " 安装完成！验证:"
echo "============================================"

if command -v ffmpeg &>/dev/null; then
    echo ""
    echo "版本: $(ffmpeg -version 2>&1 | head -1)"
    echo ""
    echo "硬件加速:"
    ffmpeg -hwaccels 2>&1 | grep -E "rkmpp|drm" || echo "  (未检测到 rkmpp)"
    echo ""
    echo "RGA 滤镜:"
    ffmpeg -filters 2>&1 | grep rkrga || echo "  (未检测到 rkrga)"
else
    echo ""
    echo "WARNING: ffmpeg 未找到，安装可能不完整"
fi

echo ""
echo "清理临时文件..."
rm -rf "$WORK_DIR"
echo "完成！"