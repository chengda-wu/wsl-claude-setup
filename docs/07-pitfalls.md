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
