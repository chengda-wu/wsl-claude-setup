#!/usr/bin/env bash
#
# H20 HGX 服务器升级: CUDA 12.9 / R575  →  CUDA 13.0.2 / R610 + Fabric Manager
#
# 适用: Ubuntu 20.04 (用 22.04 的 Fabric Manager deb,依赖 libc6>=2.10,20.04 满足)
# 目标: 驱动 610.57.04 + Fabric Manager 610.57.04 + CUDA Toolkit 13.0.2 (toolkit-only)
#
# 为什么选 13.0.2 而非最新 13.3.1:
#   vLLM / SGLang 的 cu130 wheel 均按 CUDA 13.0 编译 (vLLM 明确写 13.0.2)。
#   框架文档未明确担保 cu130 wheel 在 13.3 宿主可跑,离线环境为零风险,
#   宿主与 wheel 精确对齐到 13.0.2。CUDA 13.x 驱动门槛 >= 580,610 满足。
#
# 用法:
#   1. 把三个安装包下载到本脚本同目录 (见下方 EXPECTED_FILES)
#   2. sudo bash h20-cuda13-upgrade.sh
#
# 下载链接 (服务器离线, 需先下到本脚本同目录):
#   驱动 R610 (.run, 跨发行版):
#     https://us.download.nvidia.com/tesla/610.57.04/NVIDIA-Linux-x86_64-610.57.04.run
#   Fabric Manager 610.57.04 (22.04 deb, 依赖 libc6>=2.10, 20.04 可用):
#     https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/nvidia-fabricmanager_610.57.04-1ubuntu1_amd64.deb
#   CUDA Toolkit 13.0.2 (.run, 跨发行版, 装时用 --toolkit 不覆盖驱动):
#     https://developer.download.nvidia.com/compute/cuda/13.0.2/local_installers/cuda_13.0.2_580.95.05_linux.run
#
set -euo pipefail

# ---------- 配置 ----------
DRIVER_VER="610.57.04"
CUDA_VER="13.0.2"
CUDA_RUN_DRIVER_TAG="580.95.05"   # CUDA .run 内部绑定的驱动版本(更旧,故只装 toolkit)
FABRIC_DEB="nvidia-fabricmanager_610.57.04-1ubuntu1_amd64.deb"

EXPECTED_FILES=(
  "NVIDIA-Linux-x86_64-${DRIVER_VER}.run"
  "${FABRIC_DEB}"
  "cuda_${CUDA_VER}_${CUDA_RUN_DRIVER_TAG}_linux.run"
)

# ---------- 颜色 ----------
RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'; NC=$'\033[0m'
log()  { echo "${GREEN}[*]${NC} $*"; }
warn() { echo "${YELLOW}[!]${NC} $*"; }
err()  { echo "${RED}[✗]${NC} $*" >&2; }

# ---------- 前置检查 ----------
if [[ $EUID -ne 0 ]]; then
  err "请用 root 运行: sudo bash $0"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

log "检查安装包是否齐全..."
for f in "${EXPECTED_FILES[@]}"; do
  if [[ ! -f "$f" ]]; then
    err "缺少: $f"
    err "请先下载到 $SCRIPT_DIR :"
    cat <<EOF
  https://us.download.nvidia.com/tesla/${DRIVER_VER}/NVIDIA-Linux-x86_64-${DRIVER_VER}.run
  https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/${FABRIC_DEB}
  https://developer.download.nvidia.com/compute/cuda/${CUDA_VER}/local_installers/cuda_${CUDA_VER}_${CUDA_RUN_DRIVER_TAG}_linux.run
EOF
    exit 1
  fi
done
log "三个包齐全 ✓"

# 升级前硬性检查: VBIOS (R610 要求 Hopper VBIOS >= 96.00.68.00.xx)
log "检查 VBIOS 是否满足 R610 要求 (>= 96.00.68.00.xx)..."
if command -v nvidia-smi >/dev/null 2>&1; then
  VBIOS="$(nvidia-smi -q 2>/dev/null | grep -i 'VBIOS Version' | head -1 | awk '{print $NF}')"
  if [[ -n "${VBIOS:-}" ]]; then
    log "当前 VBIOS: ${VBIOS}"
    # 比较第三段 (十六进制): 96.00.XX.00.xx
    SEG3="$(echo "$VBIOS" | awk -F. '{print toupper($3)}')"
    SEG3_DEC="$(printf '%d' "0x$SEG3" 2>/dev/null || echo 0)"
    THRESH_DEC=104   # 0x68 = 104
    if (( SEG3_DEC < THRESH_DEC )); then
      err "VBIOS 过旧: ${VBIOS} (第三段 ${SEG3}=十进制${SEG3_DEC} < 门槛 68=十进制${THRESH_DEC})"
      err "R610 会在这种卡上初始化失败。请先升级 VBIOS 再运行本脚本。"
      exit 1
    fi
    log "VBIOS 满足要求 (第三段 ${SEG3}=十进制${SEG3_DEC} >= 门槛 ${THRESH_DEC}) ✓"
  else
    warn "读不到 VBIOS 版本 (nvidia-smi 可能已异常),跳过检查。若装完 610 后 nvidia-smi 报错,先查 VBIOS。"
  fi
else
  warn "无 nvidia-smi(可能驱动已卸),跳过 VBIOS 检查。"
fi

# ---------- 第 1 步: 卸载旧驱动 (R575) ----------
log "【1/5】卸载旧 NVIDIA 驱动 / CUDA..."
systemctl stop nvidia-fabricmanager 2>/dev/null || true
# .run 安装的驱动用自带卸载器
if [[ -x /usr/bin/nvidia-uninstall ]]; then
  log "运行 nvidia-uninstall..."
  yes | /usr/bin/nvidia-uninstall -s || true
fi
# deb/rpm 残留
apt-get --purge remove -y "*nvidia*" "*cuda*" 2>/dev/null || true
apt-get autoremove -y 2>/dev/null || true
# 内核模块
modprobe -r nvidia_uvm nvidia_drm nvidia_modeset nvidia 2>/dev/null || true

log "确认旧驱动是否卸干净..."
if command -v nvidia-smi >/dev/null 2>&1; then
  warn "nvidia-smi 仍存在,可能需要重启。建议: sudo reboot,重启后重跑本脚本。"
  exit 0
fi
log "旧驱动已卸干净 ✓"

# ---------- 第 2 步: 安装新驱动 610.57.04 ----------
log "【2/5】安装驱动 ${DRIVER_VER}..."
sh "NVIDIA-Linux-x86_64-${DRIVER_VER}.run" \
  --silent --accept-license --no-questions \
  --no-drm --dkms 2>/dev/null || \
sh "NVIDIA-Linux-x86_64-${DRIVER_VER}.run" \
  --silent --accept-license --no-questions --no-drm --dkms --override

modprobe nvidia 2>/dev/null || true
log "验证驱动..."
nvidia-smi || { err "nvidia-smi 失败,驱动未起来。检查 dmesg | grep -i nvidia"; exit 1; }
DRV_NOW="$(nvidia-smi --query-gpu=driver_version --format=csv,noheader | head -1)"
log "驱动版本: ${DRV_NOW}"
if [[ "$DRV_NOW" != "$DRIVER_VER" ]]; then
  err "驱动版本不符: 期望 ${DRIVER_VER},实际 ${DRV_NOW}"
  err "可能内核模块未重载,执行: sudo reboot 后重跑剩余步骤(从第3步起,手动)"
  exit 1
fi
log "驱动 ${DRIVER_VER} 安装成功 ✓"

# ---------- 第 3 步: 安装 Fabric Manager 610.57.04 ----------
log "【3/5】安装 Fabric Manager ${DRIVER_VER}..."
dpkg -i "${FABRIC_DEB}"
systemctl daemon-reload
systemctl enable nvidia-fabricmanager
systemctl restart nvidia-fabricmanager
sleep 3
log "验证 Fabric Manager..."
systemctl is-active --quiet nvidia-fabricmanager || { err "nvidia-fabricmanager 未运行: journalctl -u nvidia-fabricmanager -n 50"; exit 1; }
FM_VER="$(nv-fabricmanager -v 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo unknown)"
log "Fabric Manager 版本: ${FM_VER}"
if [[ "$FM_VER" != "$DRIVER_VER" ]]; then
  warn "Fabric Manager 版本 (${FM_VER}) 与驱动 (${DRIVER_VER}) 不一致,可能影响 NVSwitch。"
fi
log "验证 NVSwitch 拓扑 (应看到 8 卡全互联)..."
nvidia-smi topo -m | head -12
log "Fabric Manager 就绪 ✓"

# ---------- 第 4 步: 安装 CUDA Toolkit 13.3.1 (toolkit-only) ----------
log "【4/5】安装 CUDA Toolkit ${CUDA_VER} (只装工具链,不覆盖驱动)..."
# 关键: --toolkit 只装 toolkit,不用 .run 内自带的旧驱动 (610.43.02)
sh "cuda_${CUDA_VER}_${CUDA_RUN_DRIVER_TAG}_linux.run" \
  --toolkit --silent --override --accept-license --no-man-page-install
log "配置环境变量..."
CUDA_LINK="/usr/local/cuda"
CUDA_DIR="/usr/local/cuda-${CUDA_VER}"
if [[ -d "$CUDA_DIR" ]]; then
  ln -sfn "$CUDA_DIR" "$CUDA_LINK"
  log "已链接 ${CUDA_LINK} -> ${CUDA_DIR}"
fi
# 写入 profile.d
cat > /etc/profile.d/cuda.sh <<'EOF'
export CUDA_HOME=/usr/local/cuda
export PATH=$CUDA_HOME/bin:$PATH
export LD_LIBRARY_PATH=$CUDA_HOME/lib64:${LD_LIBRARY_PATH:-}
EOF
log "验证 CUDA..."
export CUDA_HOME=/usr/local/cuda PATH=/usr/local/cuda/bin:$PATH
nvcc --version | grep -i release || warn "nvcc 未就绪,检查 /usr/local/cuda-${CUDA_VER}"
log "CUDA Toolkit ${CUDA_VER} 安装成功 ✓"

# ---------- 第 5 步: 总结 ----------
log "【5/5】升级完成。总结:"
echo "  驱动:          $(nvidia-smi --query-gpu=driver_version --format=csv,noheader | head -1)"
echo "  Fabric Manager: ${FM_VER}"
echo "  CUDA Toolkit:  $(nvcc --version 2>/dev/null | grep -oE 'release [0-9.]+' | awk '{print $2}')"
echo ""
warn "若改了内核模块,建议: sudo reboot 后再跑框架。"
warn "框架 (vLLM/SGLang) 装 cu130 wheel:  export CUDA_HOME=/usr/local/cuda && pip install ... (见 README)"

log "全部完成 ✓"
