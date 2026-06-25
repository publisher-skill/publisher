# 跨工具安装指南

[English](./INSTALL.md) | 简体中文

这个 publisher 能力同一套对话式工作流，可在 **Claude Code、Cursor、Codex** 三家使用。
能力层统一走 HTTP/curl，**任何工具都无需安装 Python**。把 HTML 前端项目发布到平台，
并可一步打包成安卓 APK。

| 工具 | 入口文件 | 安装位置 |
|------|----------|----------|
| Claude Code | `SKILL.md` / `SKILL-zh.md` | 整个目录放到 `~/.claude/skills/publisher` |
| Cursor | `.cursor/rules/publisher.mdc` | 复制到你项目的 `<project>/.cursor/rules/publisher.mdc` |
| Codex | `AGENTS.md` | 复制到项目根目录 `AGENTS.md`，或合并进 `~/.codex/AGENTS.md` |

三个入口文件内容等价，只是各家格式不同。

## Claude Code
```text
解压本目录到 ~/.claude/skills/publisher
```
按 `description` 自动触发；可选地把 `mcp-config.example.json` 挂成 MCP server 获得工具调用增强。

## Cursor
把 `.cursor/rules/publisher.mdc` 放进你项目的 `.cursor/rules/` 目录即可。
- 默认 `alwaysApply: false`，靠 `description` 让 Agent 判断何时启用。
- 想让它常驻每次对话，把 frontmatter 改成 `alwaysApply: true`。
- Cursor 也支持 MCP，可在设置里加同一个 streamable-http server（可选）。

## Codex
把 `AGENTS.md` 放到项目根目录（Codex 会自动读取），或把内容合并进全局 `~/.codex/AGENTS.md`。
- ⚠️ Codex 的 MCP 仅支持本地 STDIO 子进程，**不支持本平台的远程 streamable-http MCP**，
  所以 Codex 下请走 `AGENTS.md` 里的 HTTP/curl 路径（已是默认）。

## 能力层（所有工具通用）
- HTTP 接口：`https://ai-pub.pushwebly.com`（见各入口文件）
- MCP（仅 Claude/Cursor 可选）：`https://ai-pub.pushwebly.com/mcp`
- 凭证统一存于 `~/.publisher/config.json`，三家共用，互不冲突。
