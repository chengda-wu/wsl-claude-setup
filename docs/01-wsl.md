# WSL 配置

## 基本信息

| 项 | 值 |
|---|---|
| 发行版 | Ubuntu 24.04.4 LTS |
| WSL 版本 | 2 |
| 内核 | 6.6.87.2-microsoft-standard-WSL2 |
| systemd | 已启用 |

## /etc/wsl.conf

```ini
[boot]
systemd=true
```

systemd 必须开启——后续若改用原生 Docker Engine 需要 systemd 管理服务。

## 管理命令（在 Windows PowerShell 执行）

```powershell
wsl --list --verbose          # 查看发行版及版本
wsl --shutdown                # 重启所有 distro（Docker 集成改动后需要）
wsl --set-default Ubuntu      # 设默认 distro
```

## 注意

- `wsl --shutdown` 会关闭**所有** WSL 会话和正在运行的任务，慎用
- Docker Desktop 的 WSL 集成 socket 注入只发生在 distro **启动时**，改动集成配置后必须 shutdown 再重开
