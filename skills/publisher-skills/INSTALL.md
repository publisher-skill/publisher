# Multi-tool Install

English | [简体中文](./INSTALL-zh.md)

This publisher capability uses one shared conversational workflow and works across
**Claude Code, Cursor, and Codex**. The capability layer goes through HTTP/curl, so
**no tool needs Python installed**. Publish HTML frontend projects to the platform,
and optionally package them into an Android APK in one step.

| Tool | Entry file | Install location |
|------|-----------|------------------|
| Claude Code | `SKILL.md` / `SKILL-zh.md` | Put the whole directory in `~/.claude/skills/publisher` |
| Cursor | `.cursor/rules/publisher.mdc` | Copy to your project's `<project>/.cursor/rules/publisher.mdc` |
| Codex | `AGENTS.md` | Copy to the project root `AGENTS.md`, or merge into `~/.codex/AGENTS.md` |

The three entry files are equivalent in content — only the per-tool format differs.

## Claude Code
```text
Unzip this directory to ~/.claude/skills/publisher
```
Triggered automatically by `description`; optionally mount `mcp-config.example.json`
as an MCP server for tool-call enhancement.

## Cursor
Drop `.cursor/rules/publisher.mdc` into your project's `.cursor/rules/` directory.
- Defaults to `alwaysApply: false`, relying on `description` so the Agent decides when to use it.
- To keep it active in every conversation, set the frontmatter to `alwaysApply: true`.
- Cursor also supports MCP — you can add the same streamable-http server in settings (optional).

## Codex
Put `AGENTS.md` in the project root (Codex reads it automatically), or merge its
content into the global `~/.codex/AGENTS.md`.
- ⚠️ Codex's MCP supports local STDIO subprocesses only and **does not support this
  platform's remote streamable-http MCP**, so on Codex use the HTTP/curl path in
  `AGENTS.md` (already the default).

## Capability Layer (common to all tools)
- HTTP API: `https://ai-pub.pushwebly.com` (see each entry file)
- MCP (optional, Claude/Cursor only): `https://ai-pub.pushwebly.com/mcp`
- Credentials are stored in `~/.publisher/config.json`, shared by all three tools without conflict.
