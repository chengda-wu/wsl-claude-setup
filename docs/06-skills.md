# Skill / Plugin 配置

Claude Code 通过 plugin marketplace 安装 skills。已启用 3 个插件，其中 2 个提供 skill、1 个提供 LSP 集成。

配置文件：`~/.claude/settings.json` 的 `enabledPlugins` + `extraKnownMarketplaces`。

## 已启用插件一览

| 插件 | 类型 | marketplace | 仓库 | 触发方式 |
|---|---|---|---|---|
| karpathy-guidelines | skill | karpathy-skills | forrestchang/andrej-karpathy-skills | 写/审/重构代码时自动激活 |
| i-have-adhd | skill | i-have-adhd | ayghri/i-have-adhd | `/i-have-adhd` 手动开，`stop adhd mode` 关 |
| rust-analyzer-lsp | LSP 集成 | claude-plugins-official | (官方) | Rust 文件自动生效 |

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

---

## Skill 详解

### 1. karpathy-guidelines

**来源**：Andrej Karpathy 对 LLM 编码常见错误的观察。

**作用**：减少 LLM 编码错误，偏向谨慎而非速度。写、审、重构代码时自动激活。

**四条准则**：
1. **先思考再编码** — 不假设、不隐藏困惑、明示权衡；多种理解时摆出来不擅自选；有更简单方案要说
2. **简单优先** — 最小代码解决问题，不要投机性功能/抽象/配置/不可能的错误处理
3. **外科手术式改动** — 只动必须动的，不"改进"相邻代码，匹配现有风格，发现无关死代码只提不删
4. **目标驱动执行** — 把任务转成可验证目标（"修 bug" → "写复现测试再让它过"），多步任务列计划+验证点

**触发**：自动。代码任务时生效，trivial 任务用判断。

### 2. i-have-adhd

**作用**：把输出塑造成 ADHD 大脑可执行的形式。

**触发**：`/i-have-adhd` 手动开启，持续到说 `stop adhd mode` / `normal mode`。

**核心规则**：
- 首行即下一个行动（不是上下文/计划）
- 多步任务用编号列表，每步一个有界动作
- 结尾给一个 2 分钟内可做的具体下一步
- 每轮重述当前状态（"第 3/5 步完成"）
- 给具体时间估计（"15 分钟"而非"一会儿"）
- 让完成的工作可见
- 错误用平实语气说原因+修法（不用"Uh oh"）
- 列表不超过 5 项
- 无开场白/无总结寒暄

**注意**：这个 skill 的规则对整个会话持续生效，直到关闭。

---

## rust-analyzer-lsp（LSP 集成，非 skill）

提供 Rust 代码智能：定义跳转、引用查找、hover 文档、符号搜索等。打开 Rust 文件时自动生效，通过 Claude Code 的 LSP 工具调用。不需要手动触发。

## 相关目录

```
~/.claude/plugins/
├── cache/              # 插件版本缓存
├── marketplaces/       # marketplace 仓库克隆
│   ├── karpathy-skills/skills/karpathy-guidelines/SKILL.md
│   ├── i-have-adhd/skills/i-have-adhd/SKILL.md
│   └── claude-plugins-official/plugins/rust-analyzer-lsp/
├── installed_plugins.json
└── known_marketplaces.json
```

## 安装新插件/skill

在 Claude Code 内用 `/plugin` 命令交互安装，或手动编辑 `settings.json` 的 `enabledPlugins` + `extraKnownMarketplaces` 后重启。
