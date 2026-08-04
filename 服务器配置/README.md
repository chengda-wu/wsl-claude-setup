# H20 HGX 服务器配置

推理服务器 (Hopper HGX, 8×H20) 的驱动 / CUDA / Fabric Manager 升级记录。

## 当前环境 → 目标

| 组件 | 升级前 | 升级后 |
|---|---|---|
| OS | Ubuntu 20.04 | Ubuntu 20.04 (不变) |
| 驱动 | 575.57.08 (R575) | **610.57.04 (R610)** |
| Fabric Manager | 575.57.08 | **610.57.04** |
| CUDA Toolkit | 12.9 | **13.3.1** |
| DCGM | 未装 | 不装 (不接入监控) |

## 关键决策

1. **不升级 OS。** CUDA 13 官方只列 Ubuntu 22.04/24.04/26.04,但 `.run` 安装器跨发行版,20.04 用 `--override` 即可。
2. **Fabric Manager 用 22.04 的 deb。** 20.04 仓库只到 575,无 610;但 22.04 的 `nvidia-fabricmanager_610.57.04` 依赖只要 `libc6 >= 2.10`(查 NVIDIA Packages 元数据确认),20.04 的 glibc 2.31 远超,**装得上**。
3. **CUDA `.run` 只装 toolkit。** 13.3.1 的 `.run` 内部绑定驱动 610.43.02(比单独的 610.57.04 旧),用 `--toolkit` 跳过驱动,避免降级。
4. **框架用 cu130 wheel。** vLLM(cu130)与 SGLang(默认 cu130)的公约数 = CUDA 13.0;宿主 13.3.1 向后兼容 cu130。

## 升级前检查 (已确认)

- **VBIOS ≥ 96.00.68.00.xx**:实测 `96.00.A5.00.09`(第三段 A5=十进制165 > 门槛 68=104),✓ 满足 R610 要求。低于此的卡装 R610 会初始化失败,需先升 VBIOS。
- **DCGM**:R610 要求 ≥ 4.3.x,但不装 DCGM 不影响推理,本机不接入监控故跳过。

## 下载链接 (服务器离线,需先下到本脚本同目录)

```
# 1. 驱动 R610 (.run, 跨发行版)
https://us.download.nvidia.com/tesla/610.57.04/NVIDIA-Linux-x86_64-610.57.04.run

# 2. Fabric Manager 610.57.04 (22.04 deb, 依赖 libc6>=2.10)
https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/nvidia-fabricmanager_610.57.04-1ubuntu1_amd64.deb

# 3. CUDA Toolkit 13.3.1 (.run, 跨发行版)
https://developer.download.nvidia.com/compute/cuda/13.3.1/local_installers/cuda_13.3.1_610.43.02_linux.run
```

## 执行

```bash
# 1. 把三个包下载到 服务器配置/ 目录
# 2. 上传整个目录到服务器
# 3. 运行
sudo bash h20-cuda13-upgrade.sh
```

脚本会: 检查 VBIOS → 卸载旧 575 驱动 → 装 610 驱动 → 装 Fabric Manager → 装 CUDA toolkit → 验证。
中途若提示重启(内核模块未卸干净),`reboot` 后重跑即可(脚本幂等,已装步骤会跳过/重装)。

## 验证升级成功

```bash
nvidia-smi                                  # 驱动 610.57.04, 8 卡可见
nvidia-smi topo -m                          # NVSwitch 拓扑, 8 卡全互联
nv-fabricmanager -v                         # 610.57.04, 与驱动一致
nvcc --version                              # release 13.3
```

## 装框架 (升级后)

```bash
export CUDA_HOME=/usr/local/cuda

# SGLang (默认 cu130)
pip install --upgrade pip uv
uv pip install --prerelease=allow sglang

# vLLM (cu130 wheel, 参考其官方 cu130 索引)
pip install vllm   # 默认 cu130 构建
```

## 踩坑

- **CUDA `.run` 带旧驱动**: 13.3.1 的 runfile 内含驱动 610.43.02,比独立的 610.57.04 旧。务必 `--toolkit` 只装工具链,否则会把驱动降级。
- **Fabric Manager 版本必须与驱动精确匹配**: H20 HGX 有 NVSwitch,版本不一致会导致 NVLink 拓扑起不来。`nv-fabricmanager -v` 必须等于驱动版本。
- **20.04 卸旧驱动**: R575 若是 `.run` 装的,用 `/usr/bin/nvidia-uninstall`;deb 装的用 `apt-get --purge remove "*nvidia*"`。卸完 `nvidia-smi` 应 command not found,再装新的。
- **内核模块占着装不上**: 卸载后 `modprobe -r` 不掉,需 `reboot`,重启后重跑脚本。
