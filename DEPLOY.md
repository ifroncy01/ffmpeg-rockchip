# Rockchip 媒体全家桶 — 在线构建与桌面集成方案

## 一、整体架构

```
┌─────────────────────────────────────────────────────────────────────┐
│                        GitHub CI (在线自动构建)                       │
│                                                                     │
│   librga                ffmpeg-rockchip           mpv-rockchip      │
│  ┌──────────┐          ┌──────────────┐          ┌──────────────┐  │
│  │ 打包预编译│          │ 编译 FFmpeg  │          │ 编译 mpv     │  │
│  │ .so+头文件│          │ + rkmpp/rkrga│          │ + rkmpp/rkrga│  │
│  └────┬─────┘          └──────┬───────┘          └──────┬───────┘  │
│       │ latest release        │ latest release           │          │
│       ▼                       ▼                          │          │
│  librga.tar.gz           ffmpeg.tar.gz  ──依赖──→  mpv.tar.gz      │
│  (120 KB)                (28.1 MB)               (待创建仓库)       │
└─────────────────────────────────────────────────────────────────────┘
                              │
                    curl install.sh | bash
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    目标设备 (Rockchip ARM64)                         │
│                                                                     │
│   /usr/bin/ffmpeg, ffprobe, ffplay, mpv                            │
│   /usr/lib/libavcodec.so* ... (8个 FFmpeg 库)                       │
│   /usr/lib/aarch64-linux-gnu/librga.so*                            │
│   /usr/share/applications/                                          │
│     ├── ffplay-rockchip.desktop    → 桌面菜单入口                    │
│     └── mpv-rockchip.desktop       → 桌面菜单入口                    │
└─────────────────────────────────────────────────────────────────────┘
```

## 二、三个仓库详情

### 2.1 librga — `github.com/ifroncy01/librga`

| 项目 | 说明 |
|------|------|
| 作用 | Rockchip RGA 2D 加速库，FFmpeg/mpv 的底层依赖 |
| 分支 | `main` |
| Runner | `ubuntu-latest` (纯打包，无需 ARM 环境) |
| 产物 | `librga-aarch64.tar.gz` (120 KB) |
| Release | https://github.com/ifroncy01/librga/releases/download/latest/librga-aarch64.tar.gz |

**安装内容：**

```
/usr/include/rga/rga.h, drmrga.h
/usr/lib/aarch64-linux-gnu/librga.so       → librga.so.2
/usr/lib/aarch64-linux-gnu/librga.so.2     → librga.so.2.1.0
/usr/lib/aarch64-linux-gnu/librga.so.2.1.0
/usr/lib/aarch64-linux-gnu/pkgconfig/librga.pc
```

**关键 Bug 修复：**

- YAML 中 `<< 'EOF'` heredoc 被 GitHub Actions 解析器误认为是 YAML merge key，改用 `printf` 替代
- Runner 从 `ubuntu-24.04-arm` 改为 `ubuntu-latest`（无需 ARM 环境）

### 2.2 ffmpeg-rockchip — `github.com/ifroncy01/ffmpeg-rockchip`

| 项目 | 说明 |
|------|------|
| 作用 | FFmpeg 编译，启用 rkmpp 硬解码/硬编码 + rkrga 滤镜 |
| 分支 | `master` |
| Runner | `ubuntu-24.04-arm` (ARM64 原生编译) |
| 编译时间 | ~20 分钟 |
| 产物 | `ffmpeg-rockchip-aarch64.tar.gz` (28.1 MB) |
| Release | https://github.com/ifroncy01/ffmpeg-rockchip/releases/download/latest/ffmpeg-rockchip-aarch64.tar.gz |

**编译流程 (build-rockchip.sh)：**

```
apt install 依赖 (含 libsdl2-dev)
  → git clone rockchip-mpp → cmake build → install
  → 安装 librga (从本地 libs/ 目录预编译 .so)
  → git clone FFmpeg → ./configure --enable-rkmpp --enable-rkrga
  → make -j$(nproc)
  → 打包 tar.gz
```

**安装内容：**

```
/usr/bin/ffmpeg, ffprobe, ffplay
/usr/lib/libavcodec.so, libavformat.so, libavfilter.so,
           libavutil.so, libswscale.so, libswresample.so,
           libavdevice.so, libpostproc.so
/usr/share/applications/ffplay-rockchip.desktop
```

**关键 Bug 修复：**

- MPP CMake 源路径错误：`cmake "$cmake_src"` → `cmake ..`
- 函数体外 `local` 关键字：移除
- ffplay 编译缺失：添加 `libsdl2-dev` 依赖
- ffplay 打包容错：`cp ffplay ... 2>/dev/null || echo "skipping"`

### 2.3 mpv-rockchip — `github.com/ifroncy01/mpv-rockchip` *(待建仓库)*

| 项目 | 说明 |
|------|------|
| 作用 | mpv 播放器编译，启用 rkmpp 解码 + rkrga 滤镜 + DRM 输出 |
| 分支 | `master` |
| Runner | `ubuntu-24.04-arm` (ARM64 原生编译) |
| 依赖 | 先从 librga + ffmpeg-rockchip 的 latest release 下载安装 |
| 产物 | `mpv-rockchip-aarch64.tar.gz` |

**编译流程 (build-mpv.sh)：**

```
apt install 依赖 (libdrm-dev, wayland, vulkan, libplacebo...)
  → 下载安装 librga latest release
  → 下载安装 ffmpeg-rockchip latest release
  → git clone mpv v0.39.0
  → ./waf configure --enable-rkmpp --enable-rkrga --enable-drm
  → ./waf build
  → 打包 (mpv 二进制 + libmpv.so + 桌面入口)
```

## 三、一键安装

在 Rockchip ARM64 设备上，**一条命令完成全部安装**：

```bash
curl -fsSL https://raw.githubusercontent.com/ifroncy01/ffmpeg-rockchip/master/install.sh | sudo bash
```

**脚本执行流程：**

1. 下载 `librga-aarch64.tar.gz` → 解压到 `/` → `ldconfig`
2. 下载 `ffmpeg-rockchip-aarch64.tar.gz` → 解压到 `/` → `ldconfig` → 刷新桌面数据库
3. 下载 `mpv-rockchip-aarch64.tar.gz` → 解压到 `/` → `ldconfig` → 刷新桌面数据库
4. 验证：打印 ffmpeg 版本、hwaccel、滤镜；打印 mpv 版本；显示桌面入口

**可选参数：**

```bash
sudo ./install.sh --skip-rga      # 跳过 librga
sudo ./install.sh --skip-ffmpeg   # 跳过 ffmpeg
sudo ./install.sh --skip-mpv      # 跳过 mpv
```

## 四、桌面环境集成

安装后，应用程序菜单中自动出现两个播放器：

| 桌面入口 | 启动命令 | 说明 |
|---------|---------|------|
| **FFplay (Rockchip HW)** | `ffplay -hwaccel rkmpp -fs -- %f` | 轻量快速预览，基于 SDL2 |
| **mpv (Rockchip HW)** | `mpv --hwdec=rkmpp --player-operation-mode=pseudo-gui -- %U` | 完整播放体验，支持 DRM/Vulkan |

**关联文件类型：** mp4, mkv, avi, mov, webm, ogg 等

## 五、验证命令

```bash
# 命令行
ffmpeg -hwaccels | grep rkmpp    # 确认 rkmpp 硬件加速
ffmpeg -filters  | grep rkrga    # 确认 rkrga 滤镜
ffmpeg -decoders  | grep rkmpp   # 确认 rkmpp 解码器
ffmpeg -encoders  | grep rkmpp   # 确认 rkmpp 编码器

# ffplay 硬解播放
ffplay -hwaccel rkmpp /path/to/video.mp4

# mpv 硬解播放
mpv --hwdec=rkmpp /path/to/video.mp4
mpv --hwdec=rkmpp --vo=gpu-next /path/to/video.mp4  # Vulkan/DRM 输出
```

## 六、文件结构一览

```
/home/ifroncy/
├── librga/                              # RGA 2D 加速库
│   ├── .github/workflows/release.yml    # CI: 打包 → artifact → latest release
│   ├── include/                         # 头文件
│   └── libs/Linux/gcc-aarch64/          # 预编译 librga.so
│
├── ffmpeg-rockchip/                     # FFmpeg + Rockchip 硬件加速
│   ├── .github/workflows/build.yml      # CI: 编译 → 打包 → latest release
│   ├── build-rockchip.sh                # 构建脚本 (mpp+rga+ffmpeg)
│   ├── install.sh                       # 设备端一键安装脚本
│   └── DEPLOY.md                        # 本文档
│
└── mpv-rockchip/                        # mpv + Rockchip 硬件加速 (待推送)
    ├── .github/workflows/build.yml      # CI: 下载依赖 → 编译 → latest release
    └── build-mpv.sh                     # 构建脚本 (依赖 ffmpeg-rockchip)
```

## 七、CI 工作流配置摘要

| 仓库 | 触发条件 | 运行环境 | 产物 |
|------|---------|---------|------|
| librga | push main / tags v* | ubuntu-latest | librga-aarch64.tar.gz |
| ffmpeg-rockchip | push master / tags v* | ubuntu-24.04-arm | ffmpeg-rockchip-aarch64.tar.gz |
| mpv-rockchip | push master / tags v* | ubuntu-24.04-arm | mpv-rockchip-aarch64.tar.gz |

所有仓库 push master/main 时自动更新 `latest` pre-release，git tag `v*` 推送时创建正式 Release。

## 八、待完成

| 项目 | 状态 |
|------|------|
| librga CI + Release | ✅ 已完成 |
| ffmpeg-rockchip CI + Release + ffplay.desktop | ✅ 已完成 |
| install.sh 全家桶脚本 | ✅ 已完成 |
| mpv-rockchip 仓库创建 | ⏳ 需手动创建 GitHub 仓库 |
| mpv-rockchip CI + Release + mpv.desktop | ⏳ 代码就绪，创建仓库后推送即可 |

**mpv-rockchip 创建仓库：**

访问 https://github.com/new → Repository name 填 `mpv-rockchip` → Public → 不勾选 "Add a README file" → 创建后运行：

```bash
cd /home/ifroncy/mpv-rockchip
git remote add origin git@github.com:ifroncy01/mpv-rockchip.git
git push -u origin master
```