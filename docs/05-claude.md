# Claude Code 配置

版本：2.1.220

配置文件：`~/.claude/settings.json`

## settings.json（脱敏）

```json
{
  "env": {
    "ANTHROPIC_BASE_URL": "<你的 API 端点>",
    "ANTHROPIC_API_KEY": "<REDACTED>",
    "ANTHROPIC_MODEL": "glm52",
    "ANTHROPIC_SMALL_FAST_MODEL": "glm52",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "glm52",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "glm52",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "glm52",
    "API_TIMEOUT_MS": "600000",
    "MCP_TIMEOUT": "60000",
    "MCP_TOOL_TIMEOUT": "600000"
  },
  "alwaysThinkingEnabled": true,
  "autoCompactWindow": 262144,
  "autoCompactEnabled": true,
  "autoUpdates": false,
  "skipLogin": true,
  "skipDangerousModePermissionPrompt": true,
  "hasTrustDialogAccepted": true,
  "theme": "dark"
}
```

## 关键 env 变量

| 变量 | 值 | 作用 |
|---|---|---|
| `MCP_TIMEOUT` | 60000 | MCP server 启动超时，默认 30s 对 Playwright 不够 |
| `MCP_TOOL_TIMEOUT` | 600000 | 单次 MCP 工具调用超时（浏览器操作慢） |
| `API_TIMEOUT_MS` | 600000 | API 请求超时 |

## 其他配置项

| 项 | 作用 |
|---|---|
| `hasTrustDialogAccepted: true` | 跳过进入目录时的"是否信任此文件夹"提示 |
| `skipDangerousModePermissionPrompt: true` | 跳过危险模式权限提示 |
| `skipLogin: true` | 跳过登录（用自建端点时） |
| `alwaysThinkingEnabled: true` | 默认开启思考模式 |
| `autoUpdates: false` | 关闭自动更新 |

## 安装

```bash
curl -fsSL https://claude.ai/install.sh | sh
```

## 常用命令

```bash
claude                          # 启动
claude mcp list                 # 看 MCP 状态
claude mcp add <name> -s user -- <cmd>   # 注册 MCP（user scope）
claude mcp remove <name>        # 删除 MCP
claude doctor                   # 体检
```

## 注意

- settings.json 的 `env` 块里的变量会注入到 MCP 子进程环境
- **API key 不要提交到仓库**，本仓库已脱敏
- 改 MCP 配置后必须重启 Claude Code（MCP 只在会话启动时加载）
