# Docker 配置

## 方案

Docker Desktop (Windows) + WSL 集成。Docker 引擎跑在 Windows 侧，通过 socket 注入到 WSL distro。

## 版本

```
Docker version 29.6.2
```

## 启用 WSL 集成

Docker Desktop → Settings → Resources → WSL Integration → 打开目标 distro → Apply & restart。

集成生效后会在 WSL 内注入：
- `/var/run/docker.sock`（属组 `docker`，普通用户可访问）
- `docker` 命令到 PATH

## 免 sudo：加入 docker 组

```bash
sudo usermod -aG docker $USER
# 然后重开终端（或新登录 shell）让组生效
```

验证：
```bash
groups              # 输出应含 docker
docker ps           # 无 sudo 可用
```

## 当前运行的容器

| 容器 | 镜像 | 端口 |
|---|---|---|
| searxng | searxng/searxng:latest | 0.0.0.0:8080->8080 |

## 常用命令

```bash
docker ps                                   # 看运行中容器
docker logs searxng                         # 看日志
docker restart searxng                      # 重启
docker stop searxng / docker start searxng  # 停/启
```

## 已知问题

- Docker Desktop 重启后，WSL 内 socket 可能需要 distro 重启才重新注入
- 如果 `docker ps` 又报 permission denied，重开 WSL 终端即可（docker 组已加好）
- 手改 `settings-store.json` 写 `WslIntegrations` 键不一定被认，优先用 GUI
