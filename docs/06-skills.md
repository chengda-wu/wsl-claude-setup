# Skill / Plugin 配置

Claude Code 通过 plugin marketplace 安装 skills。

## 已启用插件

| 插件 | marketplace | 仓库 |
|---|---|---|
| andrej-karpathy-skills | karpathy-skills | forrestchang/andrej-karpathy-skills |
| rust-analyzer-lsp | claude-plugins-official | (官方) |
| i-have-adhd | i-have-adhd | ayghri/i-have-adhd |

## marketplace 配置（settings.json）

```json
{
  "enabledPlugins": {
    "andrej-karpathy-skills@karpathy-skills": true,
    "rust-analyzer-lsp@claude-plugins-official": true,
    "i-have-adhd@i-have-adhd": true
  },
  "extraKnownMarketplaces": {
    "karpathy-skills": {
      "source": { "source": "github", "repo": "forrestchang/andrej-karpathy-skills" }
    },
    "i-have-adhd": {
      "source": { "source": "github", "repo": "ayghri/i-have-adhd" }
    }
  }
}
```

## 各插件说明

### andrej-karpathy-skills
编码行为准则 skill——减少 LLM 常见编码错误（过度复杂、非必要改动等）。提供 `karpathy-guidelines` skill。

### rust-analyzer-lsp
Rust 语言服务器集成，给 Claude Code 提供 Rust 代码智能（定义跳转、引用查找等）。

### i-have-adhd
输出适配 skill——让回复更易 ADHD 大脑执行（首行即行动、编号步骤、重述状态等）。

## 相关目录

```
~/.claude/plugins/
├── cache/              # 插件缓存
├── data/
├── marketplaces/       # marketplace 元数据
├── installed_plugins.json
└── known_marketplaces.json
```

## 安装新插件

通过 `/plugin` 命令在 Claude Code 内交互安装，或手动编辑 `settings.json` 的 `enabledPlugins` + `extraKnownMarketplaces`。
