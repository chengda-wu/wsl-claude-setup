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

容器默认不继承 WSL 的代理 env。若上游引擎访问异常，给容器配代理：

```yaml
# docker-compose.yml
services:
  searxng:
    environment:
      - HTTP_PROXY=http://host.docker.internal:7897
      - HTTPS_PROXY=http://host.docker.internal:7897
      - NO_PROXY=localhost,127.0.0.1
```

> Mirrored 模式下容器内 `host.docker.internal` 指向 Windows 主机；或用 `127.0.0.1`（Mirrored 下容器与主机共享 localhost）。代理客户端要允许局域网/外部连接。

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
