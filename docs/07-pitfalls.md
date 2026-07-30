# 踩坑笔记

搭建过程中踩的坑，按时间顺序记录。

## 1. Docker Desktop WSL 集成不生效

**现象**：WSL 内 `docker: command not found`，或 socket 不存在。

**原因**：Docker Desktop 的 WSL 集成 socket 注入只发生在 distro **启动时**。改了集成配置但没重启 distro，不会生效。

**尝试过但无效**：手改 `~/AppData/Roaming/Docker/settings-store.json` 加 `WslIntegrations: {Ubuntu: true}` 键——Docker Desktop 不一定认手改的键。

**解决**：
1. Docker Desktop GUI: Settings → Resources → WSL Integration → 打开 distro
2. Windows PowerShell 执行 `wsl --shutdown`
3. 重开 WSL 终端

> 若 GUI 找不到 WSL Integration 选项，检查是否在 Windows 容器模式（任务栏 Docker 菜单切换到 Linux 容器）。

## 2. docker 免 sudo

**现象**：`docker ps` 报 permission denied。

**原因**：用户不在 docker 组。

**解决**：
```bash
sudo usermod -aG docker $USER
# 重开终端让组生效
```

**坑**：当前已开的 shell 会话不会即时刷新组，需新登录 shell。临时可用 `sg docker -c 'docker ps'`。

## 3. SearXNG 禁用引擎字段名

**现象**：settings.yml 写 `enabled: false`，引擎仍启用。

**原因**：SearXNG 用 `disabled: true`，不是 `enabled: false`。

**解决**：改用 `disabled: true`。

## 4. SearXNG JSON 输出

**现象**：MCP 调用返回 403。

**原因**：默认只开 html 格式，没开 json。

**解决**：settings.yml 的 `search.formats` 加 `json`，重启容器。

## 5. mcp-searxng 在 Node 18 崩溃

**现象**：`Error [ReferenceError]: File is not defined`。

**原因**：mcp-searxng 依赖的 undici 需要 Node 20+，系统是 Node 18。

**解决**：用 nvm 装 Node 20 并设为默认，MCP 命令用 nvm 的 node/npx 绝对路径。

## 6. MCP 用 npx 启动慢/握手失败

**现象**：
- playwright：`claude mcp list` 报 `Connection closed`，但手动 `npx @playwright/mcp` 能正常 initialize
- searxng：启动要 7.6 秒，拖慢 Claude Code 启动

**原因**：npx 每次启动要检查/解析包，开销大；playwright 还可能 stdout 污染 JSON-RPC 导致 Claude Code 的 stdio 握手读不到响应。

**解决**：两个 MCP 都绕过 npx，用 `node <cli.js路径>` 直接调用：
```bash
# searxng（7.6s → 0.5s）
claude mcp add searxng -s user --env SEARXNG_URL=http://localhost:8080 \
  -- /home/witcher/.nvm/versions/node/v20.20.2/bin/node \
  /home/witcher/.npm/_npx/<hash>/node_modules/mcp-searxng/dist/cli.js

# playwright
claude mcp add playwright -s user -- \
  /home/witcher/.nvm/versions/node/v20.20.2/bin/node \
  /home/witcher/.npm/_npx/<hash>/node_modules/@playwright/mcp/cli.js \
  --browser chromium --no-sandbox
```

## 7. Playwright 浏览器选择

**现象**：`--browser chrome` 报 `Chromium distribution 'chrome' is not found at /opt/google/chrome/chrome`。

**原因**：`--browser chrome` 找系统 Chrome，WSL 内没装。

**尝试过但无效**：用 Windows Chrome（`/mnt/c/Program Files/Google/Chrome/Application/chrome.exe`）——`chrome.exe --version` 从 WSL 调用直接报错，跨 WSL/Windows 边界驱动浏览器不可行。

**解决**：`--browser chromium` + 预装 chromium 和 chrome-for-testing：
```bash
npx -y playwright install chromium
npx -y @playwright/mcp install-browser chrome-for-testing
```

## 8. WSL 下 Playwright 必须 --no-sandbox

**原因**：WSL/容器环境下 Chromium sandbox 权限问题，不加会启动失败。

**解决**：注册命令加 `--no-sandbox`。

## 9. Claude Code MCP 启动超时

**现象**：Playwright MCP 健康检查失败，但手动能连。

**原因**：Claude Code 默认 MCP 启动超时 30s，Playwright 初始化浏览器偏慢超时。

**解决**：settings.json 的 env 加 `MCP_TIMEOUT=60000`（60 秒）。

## 10. MCP 改配置不热加载

**现象**：改了 MCP 配置，当前会话 `/mcp` 还是旧的。

**原因**：MCP 只在 Claude Code 会话启动时加载。

**解决**：`/exit` 退出后重新 `claude`。

## 11. MCP scope 选择

**现象**：project scope 注册的 MCP 在某些会话不加载。

**解决**：用 user scope（`-s user`）注册，全局生效。

## 12. god-search 不可用

**调研结论**：god-search（号称免费无限无 key 的浏览器抓取方案）只有 2 star、发布一周、LobeHub 标 Unvalidated、文档自相矛盾。不推荐。SearXNG 的 google cse 引擎已能正常返回 Google 结果，不需要它。

## 13. wsl --shutdown 后 SearXNG 容器 restart 失败（bind mount 失效）

**现象**：`wsl --shutdown` 重进 WSL 后，`docker compose restart searxng` 报错：
```
mount src=/run/desktop/mnt/host/wsl/docker-desktop-bind-mounts/... no such file or directory
```
容器起不来，`localhost:8080` 返回 000。

**原因**：Docker Desktop 给 WSL bind mount 用临时路径 `/run/desktop/mnt/host/wsl/docker-desktop-bind-mounts/...`，`wsl --shutdown` 后该路径重建，旧容器记录的路径失效。`restart` 复用旧 mount 配置 → 找不到源文件。

**解决**：用 `down && up` 重建容器（重新建立 bind mount），不要用 `restart`：
```bash
cd ~/wsl-claude-setup
docker compose down && docker compose up -d
```

**根治（可选）**：把 `docker-compose.yml` 的 bind mount 改成 Docker named volume，路径由 Docker 稳定管理，不受 WSL 重启影响。代价是改 `settings.yml` 要进 volume 里改，不如 bind mount 方便。对偶尔 `wsl --shutdown` 的场景，`down/up` 已够用。

## 14. SearXNG 上游引擎反爬（google cse / brave / ddg / startpage / qwant 返回 0 结果）

**现象**：搜索引擎注册了但搜索返回 0 条，`docker logs searxng` 刷 ERROR：
- duckduckgo / qwant / startpage：`CAPTCHA`
- google cse：`unusual traffic`（suspend 180s）
- brave：无结果

**原因**：这些大引擎对 SearXNG 的自动化请求识别为机器人，主动拒。**和代理无关**——容器内经代理访问 google 返回 200，是上游引擎层反爬。

**解决**：禁用这些引擎（`disabled: true`），改用实测稳定的 bing/baidu/yandex/mojeek/sogou/360search。如需 google cse 或 brave，配对应 API key 后再启用。详见 [SearXNG 配置 · 引擎稳定性](03-searxng.md#引擎稳定性实测)。

## 15. SearXNG /search 返回 403（挂载的 settings.yml 是占位文件）

**现象**：容器在跑（`curl localhost:8080/` 返回 200），但 `/search?format=json` 返回 SearXNG 自己的 `403 Forbidden`（不是上游引擎 403）。MCP 调用报 `SearXNG server Error (403)`。

**原因**：`docker-compose.yml` 挂载 `./searxng:/etc/searxng`，但 repo 里的 `searxng/settings.yml` 是镜像自带的 204 字节占位（只 `use_default_settings` + `secret_key`，**没开 `search.formats: json`**）。SearXNG 默认只允许 html 输出，json 请求被拒 → 403。真实配置（含 json + 代理 + 引擎）在 `~/searxng/settings.yml`，没被挂载进去。

**验证**：
```bash
docker exec searxng sh -c 'grep -A3 formats: /etc/searxng/settings.yml'
# 空 / 没有 json → 就是这个问题
```

**解决**：让 compose 挂载真实配置。两种方式：

1.（推荐）建 `docker-compose.override.yml`（已在 `.gitignore`，每台机器不同）把挂载指向真实配置目录：
```yaml
services:
  searxng:
    volumes:
      - /home/witcher/searxng:/etc/searxng
```
然后 `docker compose down && up -d`。

2. 或直接把 `~/searxng/settings.yml` 复制成 repo 的 `searxng/settings.yml`（注意容器以 uid 977 运行，覆盖需 sudo 或 `chown`）。

> 排查顺序：先 `docker exec ... grep formats` 确认 json 开了——这是 403 的直接原因，不是引擎反爬（反爬是「引擎」层、`unresponsive_engines` 里报 Suspended，区别于这里 SearXNG 自身返回 403 html）。
