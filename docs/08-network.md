# WSL 网络配置

## 网络模式

当前使用 **Mirrored 模式**（`networkingMode=Mirrored`）。

配置文件：Windows 侧 `C:\Users\<用户名>\.wslconfig`

```ini
[wsl2]
networkingMode=Mirrored
```

## 两种网络模式对比

| 项 | NAT（默认） | Mirrored（当前） |
|---|---|---|
| WSL IP | 独立子网（如 172.x） | 与 Windows 共享网络栈 |
| localhost 互通 | WSL↔Windows 默认不通 | WSL↔Windows 共享 localhost |
| 从 Windows 访问 WSL 服务 | 需端口转发 | 直接 localhost 访问 |
| IP | 每次重启可能变 | 镜像 Windows 的 IP |

## 当前实测

```
WSL eth0 IP: 172.30.221.166/32
WSL → localhost:8080 (SearXNG): 200 ✓
WSL → Windows host IP:8080: 502 ✗
```

## 对本栈的影响

### SearXNG (端口 8080)
- **WSL 内访问**：`http://localhost:8080` ✓（MCP 用这个）
- **Windows 浏览器访问**：Mirrored 模式下应可用 `http://localhost:8080`，但实测 502——可能需要容器绑定到 `0.0.0.0`（已配 `bind_address: 0.0.0.0`）或检查 Windows 防火墙
- mcp-searxng 的 `SEARXNG_URL=http://localhost:8080` 在 WSL 内正常工作

### Playwright MCP
- 浏览器跑在 WSL 内，访问外网走 WSL 网络栈，不受模式影响
- 若要连 Windows 上的服务，Mirrored 模式下可用 `localhost`

## 常用排查命令

```bash
# WSL IP
ip addr show eth0 | grep inet

# Windows 主机 IP（NAT 模式下作为网关）
ip route | grep default | awk '{print $3}'

# 测试端口连通
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8080/

# 看监听端口
ss -tlnp | grep 8080
```

## 切换网络模式

改 `.wslconfig` 后需 `wsl --shutdown` 重启所有 distro：

```ini
# NAT 模式（默认，删掉这行或改为）
[wsl2]
networkingMode=NAT

# Mirrored 模式（当前）
[wsl2]
networkingMode=Mirrored
```

## VPN / 代理配置

### 当前配置

通过 **Mirrored 模式 + 本地代理** 访问外网（典型 Clash/Mihomo 配置）。

代理端口：`127.0.0.1:7897`（HTTP 与 SOCKS5 同端口）

环境变量（已设置）：
```bash
HTTP_PROXY=http://127.0.0.1:7897
HTTPS_PROXY=http://127.0.0.1:7897
ALL_PROXY=socks5://127.0.0.1:7897
NO_PROXY=localhost,127.0.0.1,::1,.local
```

### 为什么能这样配

**Mirrored 模式的关键优势**：WSL 与 Windows 共享 localhost。所以 WSL 内的 `127.0.0.1:7897` 直接连到 Windows 上跑的代理客户端（Clash/Mihomo），**无需做端口转发**。

> NAT 模式下则不行——WSL 的 127.0.0.1 是 WSL 自己，要连 Windows 代理得用 Windows 主机 IP（`ip route | grep default` 拿到的网关 IP），且代理客户端要开"允许局域网连接"。

### 实测

```
出口 IP: 203.10.98.186（代理出口，非本机真实 IP）
google.com: 302, 0.3s  ✓ 代理工作正常
```

### 配置方法

代理环境变量通常配在 shell 的 `~/.bashrc` 或 `/etc/environment`：

```bash
# ~/.bashrc
export HTTP_PROXY=http://127.0.0.1:7897
export HTTPS_PROXY=http://127.0.0.1:7897
export ALL_PROXY=socks5://127.0.0.1:7897
export NO_PROXY=localhost,127.0.0.1,::1,.local
```

### 对本栈的影响

| 组件 | 是否走代理 | 说明 |
|---|---|---|
| SearXNG → 上游引擎 | **走代理** | SearXNG 容器需配代理才能访问 Google/Bing/Baidu（当前出口 203.10.98.186 即代理 IP） |
| mcp-searxng → SearXNG | 不走 | localhost 内部，在 NO_PROXY 里 |
| Playwright → 外网 | **走代理** | 浏览器访问外网走 WSL 网络栈，继承代理 |
| Claude Code → API 端点 | 看配置 | 你的 ANTHROPIC_BASE_URL 是自建端点，可能不走代理 |

### SearXNG 容器走代理

容器默认连不通外网引擎（bing/baidu 等全部 `HTTP connection error`）。**必须用 SearXNG 自己的 `outgoing.proxies`，光给容器配 `HTTP_PROXY` 环境变量不够**——实测 env 在场时引擎仍报 connection error，加 `outgoing.proxies` 才通。同时必须关 `enable_http2`、把 `request_timeout` 调到 10s（默认 3s 经代理太短）。

```yaml
# settings.yml（见 docs/03-searxng.md「代理」）
outgoing:
  request_timeout: 10.0
  enable_http2: false
  proxies:
    all://:
      - http://host.docker.internal:7897
```

`host.docker.internal` 由 Docker Desktop 解析到宿主机（固定 `192.168.65.254`，不随局域网 IP 变化），代理客户端要开"允许局域网连接"。改完 `docker compose down && up -d`（不要用 restart）。

### 排查代理问题

```bash
# 看出口 IP（确认是否走代理）
curl -s https://api.ipify.org

# 测试代理连通
curl -s -o /dev/null -w "%{http_code}\n" --proxy http://127.0.0.1:7897 https://www.google.com

# 看代理 env
env | grep -i proxy
```

## 注意

- Mirrored 模式是较新特性，某些端口转发/防火墙行为与 NAT 不同
- WSL2 的 localhost 转发行为依赖 `wslrelay`，偶有失效，重启 WSL 可恢复
- 本栈核心（SearXNG + MCP）都在 WSL 内闭环，网络模式对日常使用无影响
- 代理客户端（Clash/Mihomo）需在 Windows 侧常驻运行，否则 WSL 内所有外网访问失败

---

## 本机 Mirrored 为什么通（对比另一台必须用 NAT 的根因）

本机用 Mirrored，`127.0.0.1:7897` 直接通（`curl` 200，0.47s，出口 IP `203.10.98.186` 即代理出口）。为什么本机通、另一台必须退回 NAT？实测定位到 **Windows 版本差异** 是决定因素。

### 本机环境

```
Windows: 10.0.26100.8973  (Windows 11 24H2 稳定版)
WSL 内核: 6.6.87.2-microsoft-standard-WSL2
.wslconfig: 仅 networkingMode=Mirrored（无 firewall/autoProxy 等额外项）
```

### 通的机制：loopback0 中继网卡

Mirrored 模式靠一张 Hyper-V 虚拟网卡把 WSL 的 `127.0.0.1` 流量中继到 Windows 的 `127.0.0.1`。本机这张网卡在、且正常工作：

```
$ ip -br addr
lo          127.0.0.1/8  10.255.255.254/32
eth0        172.30.221.166/32          # 镜像的某个 Windows 网卡（/32 是 Mirrored 特征）
loopback0   UP                          # ← Mirrored 的 loopback 中继桥
eth1        7.250.75.250/24             # 镜像的另一个 Windows 网卡（默认出口走它）

$ ip -d link show loopback0
link/ether 00:15:5d:99:69:ce ... parentbus vmbus ...   # 00:15:5d 是 Hyper-V MAC 前缀，vmbus = Hyper-V 虚拟设备
```

验证它确实在跨边界中继（而非 WSL 本地直连）：

```
$ ss -tlnp | grep 7897
（空）                              # WSL 内没有任何进程监听 7897

$ curl -s -o /dev/null -w "%{http_code} %{time_total}s\n" --proxy http://127.0.0.1:7897 https://www.google.com
200 0.47s                           # 但能连上 → 流量经 loopback0 穿到 Windows 侧的 Clash

$ curl -s https://api.ipify.org
203.10.98.186                       # 代理出口 IP，证明走了 Windows 的 Clash
```

WSL 自己没监听 7897 却能连上 → 连接是经 `loopback0` 中继到 Windows 的 `127.0.0.1:7897`（Clash 监听处）。这就是 Mirrored loopback 中继工作的直接证据。

### 关键结论：版本决定中继是否可用

| 机器 | Windows 版本 | Mirrored loopback 中继 | 结果 |
|---|---|---|---|
| **本机** | 11 **24H2 (build 26100)** | ✅ `loopback0` 正常工作 | Mirrored 直接通 |
| **另一台** | 11 **25H2/预览 (build 26200)** | ❌ 中继不工作 | 必须退回 NAT |

两台 `.wslconfig` 都是最小 `networkingMode=Mirrored`，配置无差异；区别只在 Windows 版本。**26100（24H2）的 Mirrored loopback 中继稳定，26200（25H2 预览版）在该机器上中继失效**——属于该 build 的实现缺陷，非配置问题（详见下文「Mirrored 失败排查」）。

> 实务建议：先确认 Windows 版本。24H2（26100）可放心用 Mirrored；25H2/预览版（26200）若 Mirrored 下代理超时，直接退回 NAT（代理走网关 IP），不要在 mirror loopback 上耗时间排查——根因在平台层。

---

## NAT 模式（另一台机器的实际配置）

上面讲的是 Mirrored。另一台机器用 **NAT 模式**，代理走默认网关 IP，同样工作正常。两套配置二选一，取决于 Mirrored 在你机器上 loopback 中继是否正常（见下文「Mirrored 失败排查」）。

### .wslconfig（NAT）

```ini
[wsl2]
networkingMode=NAT

[experimental]
autoMemoryReclaim=gradual
dnsTunneling=true
sparseVhd=true
```

### 代理配置（NAT）

NAT 模式下 WSL 的 `127.0.0.1` 是 WSL 自己，**连不到** Windows 代理。要用默认网关 IP（= Windows 主机）：

```bash
# ~/.bashrc
export WIN_HOST=$(ip route | grep default | awk '{print $3}')   # NAT 网关 = Windows 主机
export HTTP_PROXY="http://${WIN_HOST}:7897"
export HTTPS_PROXY="$HTTP_PROXY"
export ALL_PROXY="socks5://${WIN_HOST}:7897"
export NO_PROXY="localhost,127.0.0.1,::1"
```

> 网关 IP 每次 `wsl --shutdown` 后可能变，所以用 `ip route` 动态取，不要写死。
> 代理客户端（Clash Verge）要开"允许局域网连接"，否则拒绝来自 WSL 子网的连接。

### 实测

```
网关: 172.24.160.1
WSL → 172.24.160.1:7897: 200, 1.5s ✓
出口 IP: 203.10.99.50（代理出口）
```

### SearXNG 容器走代理（NAT）

同 Mirrored 段：用 `settings.yml` 的 `outgoing.proxies`（不是 env 变量），关 `enable_http2`，`request_timeout: 10.0`。`host.docker.internal` 由 Docker Desktop 解析到 Windows 主机（`192.168.65.254`，不随局域网 IP 变化）。

```yaml
# settings.yml
outgoing:
  request_timeout: 10.0
  enable_http2: false
  proxies:
    all://:
      - http://host.docker.internal:7897
```

> 不要把代理地址写死成局域网 IP（如 `192.168.10.7`）——路由器重新分配后搜索会再失效。`host.docker.internal` 是稳定选择。

## Mirrored 失败排查（某台机器 loopback 中继不工作）

**背景**：一台机器从 Mirrored 切到 NAT，因为 Mirrored 下代理不通。后又尝试切回 Mirrored，仍失败。

**现象**：Mirrored 模式下，WSL 连 `127.0.0.1:7897`（代理）超时，连 `127.0.0.1:9097`（Clash external-controller，Windows 侧确认在监听）也超时。但 Windows 自己连 `127.0.0.1:7897` 正常（200）。

**结论**：Mirrored 的 **localhost 中继本身在这台机器不工作**——WSL 的 `127.0.0.1` 没镜像到 Windows loopback。不是防火墙（`firewall=false` 无效）、不是 Clash（Windows 侧正常）、不是配置过载（最小 Mirrored 配置也失败）。

**试过但无效**：
- 最小配置 `networkingMode=Mirrored` + `nestedVirtualization=true`
- 加 `firewall=false`（关 Hyper-V 防火墙）
- 加/删 `hostAddressLoopback=true`、`autoProxy`、`dnsTunneling`
- `CheckNetIsolation LoopbackExempt -a -n=MicrosoftCorporationII.WindowsSubsystemForLinux_...`（CSDN 文章给的 UWP 环回豁免方案，Win11 26200 上无效——豁免加成功但 `127.0.0.1:7897` 仍超时）
- `Set-NetFirewallHyperVVMSetting -DefaultInboundAction Allow` + `LoopbackEnabled Allow`（按微软官方 mirror 文档配 Hyper-V 防火墙，仍超时；`LoopbackEnabled` 设了不生效，回 `NotConfigured`）

**官方文档说支持但实测不通**：微软 [WSL networking 文档](https://learn.microsoft.com/en-us/windows/wsl/networking) 明确称 mirror 模式可"用 `127.0.0.1` 从 Linux 连 Windows 服务"，并要求配 Hyper-V 防火墙 `Set-NetFirewallHyperVVMSetting ... Allow`。本机照做仍超时——属于该机器 mirror loopback 转发的实现缺陷，非配置问题。

**autoProxy 的坑**：mirror 模式开 `autoProxy=true` 后，注入 WSL 的代理地址被探错——写成路由器网关 IP（如 `192.168.10.1`）而非 Windows 本机，导致代理变量指向一个没跑代理的地址。所以 autoProxy 在此机不可靠，手动配更稳。

**已定位的关键线索（版本差异）**：本机（build 26100 / 24H2）Mirrored loopback 中继正常工作（见上文「本机 Mirrored 为什么通」），这台（build 26200 / 25H2 预览版）中继失效。两台 `.wslconfig` 配置相同，唯一区别是 Windows 版本——**根因在 26200 这个 build 的 Mirrored loopback 实现缺陷，不是配置问题**。这也解释了为何所有配置层排查（防火墙、autoProxy、LoopbackExempt、Hyper-V 防火墙）都无效：改配置修不了平台层 bug。

**务实选择**：NAT 模式行为可预测、文档成熟，代理走网关 IP 稳定工作。Mirrored 不通就回退 NAT，不影响本栈任何功能。

> 注意区分两个独立问题：(1) Mirrored loopback 中继不工作（WSL 配置层面，未解决）；(2) Clash 进程偶发僵死（监听在但不响应新连接，Windows 侧自测也超时，重启 Clash + 选可用节点即恢复）。两者都表现为 WSL 代理不通，但根因不同。
