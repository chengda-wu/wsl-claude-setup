# MCP 配置

两个 MCP server，都注册在 **user scope**（全局生效，所有项目可用）。

配置文件：`~/.claude.json` 的 `mcpServers` 字段。

## 1. searxng（主力搜索）

```json
{
  "searxng": {
    "type": "stdio",
    "command": "/home/witcher/.nvm/versions/node/v20.20.2/bin/node",
    "args": [
      "/home/witcher/.npm/_npx/c0fd79eb7f6ccc1e/node_modules/mcp-searxng/dist/cli.js"
    ],
    "env": {
      "SEARXNG_URL": "http://localhost:8080"
    }
  }
}
```

注册命令：
```bash
claude mcp add searxng -s user --env SEARXNG_URL=http://localhost:8080 \
  -- /home/witcher/.nvm/versions/node/v20.20.2/bin/node \
  /home/witcher/.npm/_npx/c0fd79eb7f6ccc1e/node_modules/mcp-searxng/dist/cli.js
```

> 入口路径 `_npx/c0fd79eb7f6ccc1e` 是 npx 缓存目录，重装后可能变，需重新 `find ~/.npm/_npx -path '*mcp-searxng*/dist/cli.js'` 定位。

工具：
- `searxng_web_search` — 搜索
- `web_url_read` — 读 URL 转 markdown
- `searxng_search_suggestions` — 搜索建议
- `searxng_instance_info` — 实例信息

## 2. playwright（浏览器自动化兜底）

```json
{
  "playwright": {
    "type": "stdio",
    "command": "/home/witcher/.nvm/versions/node/v20.20.2/bin/node",
    "args": [
      "/home/witcher/.npm/_npx/9833c18b2d85bc59/node_modules/@playwright/mcp/cli.js",
      "--browser", "chromium",
      "--no-sandbox"
    ],
    "env": {}
  }
}
```

注册命令：
```bash
claude mcp add playwright -s user -- \
  /home/witcher/.nvm/versions/node/v20.20.2/bin/node \
  /home/witcher/.npm/_npx/9833c18b2d85bc59/node_modules/@playwright/mcp/cli.js \
  --browser chromium --no-sandbox
```

> `cli.js` 的哈希路径 `_npx/9833c18b2d85bc59` 是 npx 缓存目录，重装后可能变，需重新 `find ~/.npm/_npx -path '*@playwright/mcp*/cli.js'` 定位。

工具（文本快照，非多模态也能用）：
- `browser_navigate` — 打开 URL
- `browser_snapshot` — 抓可访问性快照（纯文本结构）
- `browser_click` / `browser_type` — 交互
- `browser_close` — 关闭页面

## 预装浏览器（首次必须）

```bash
npx -y playwright install chromium
npx -y @playwright/mcp install-browser chrome-for-testing
```

## 关键点

- **两个 MCP 都用 `node cli.js` 直接调用，不用 npx**：npx 每次启动要检查/解析包，searxng 从 7.6s 降到 0.5s；playwright 用 npx 还会握手失败（stdout 污染）
- **用 nvm Node 20 的绝对路径**：系统 Node 18 会让 mcp-searxng 崩（`File is not defined`），必须用 nvm 的 Node 20
- **`--no-sandbox`**：WSL 下 Playwright 必需
- **`--browser chromium`**：别用 `--browser chrome`（会找系统 Chrome 失败），也别用 Windows Chrome（跨 WSL 边界不可用）
- **MCP 注册用 user scope**：`-s user`，project scope 在某些会话不加载
- **MCP_TIMEOUT 调 15s 即可**：两个 server 都 <1s 启动，默认 30s/调大的 60s 没必要，调小能让启动卡住时少等
- 改 MCP 配置后必须**重启 Claude Code**才生效

## 定位 npx 缓存入口

两个 MCP 的 `cli.js` 都在 npx 缓存目录里，哈希路径重装后会变。重新定位：

```bash
# searxng
find ~/.npm/_npx -path '*mcp-searxng*/dist/cli.js'
# playwright
find ~/.npm/_npx -path '*@playwright/mcp*/cli.js'
```
