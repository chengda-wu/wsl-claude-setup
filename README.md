# WSL2 + Claude Code 配置记录

在 WSL2 (Ubuntu 24.04) 上搭建一套本地 Web Search 能力栈，并记录 Claude Code 的完整配置。

## 最终栈

| 层 | 组件 | 作用 |
|---|---|---|
| WSL | Ubuntu 24.04 + systemd | 运行环境 |
| Docker | Docker Desktop (WSL 集成) | 容器运行时 |
| 搜索后端 | SearXNG (Docker) | 元搜索引擎，聚合 Google/Bing/Baidu |
| 搜索 MCP | mcp-searxng | 把 SearXNG 接给 AI |
| 浏览器 MCP | Playwright MCP | 浏览器自动化兜底（动态页/反爬） |
| AI 客户端 | Claude Code 2.1.220 | MCP 客户端 |
| Node | nvm + Node 20 | MCP server 运行时 |

## 使用方式

- **普通搜索** → searxng MCP（快、结构化、无限免费）
- **SearXNG 搜不到 / 动态页面 / 需交互** → playwright MCP 开浏览器抓

## 文档目录

- [WSL 配置](docs/01-wsl.md)
- [Docker 配置](docs/02-docker.md)
- [SearXNG 配置](docs/03-searxng.md)
- [MCP 配置](docs/04-mcp.md)
- [Claude Code 配置](docs/05-claude.md)
- [Skill / Plugin 配置](docs/06-skills.md)
- [踩坑笔记](docs/07-pitfalls.md)

## 关键踩坑速查

1. Docker Desktop WSL 集成要 distro 重启才注入 socket；手改 `settings-store.json` 的 `WslIntegrations` 键不一定生效
2. SearXNG 禁用引擎用 `disabled: true`，不是 `enabled: false`
3. mcp-searxng 依赖 Node 20+（Node 18 会 `File is not defined` 崩溃）
4. Playwright MCP 用 `npx` 启动会握手失败，改用 `node cli.js` 直接调用
5. WSL 下 Playwright 必须 `--no-sandbox` + `--browser chromium`（别用 Windows Chrome）
6. Claude Code 默认 MCP 启动超时 30s 不够，需 `MCP_TIMEOUT=60000`

详见 [踩坑笔记](docs/07-pitfalls.md)。
