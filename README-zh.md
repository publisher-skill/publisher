# Publisher Skill

[English](./README.md) | 简体中文

把 HTML 前端项目发布到发布平台。

## 安装到 Claude Code

把本目录解压到：

```text
~/.claude/skills/publisher
```

然后在 Claude Code 里使用本 Skill。

## 平台地址

```text
https://pushwebly.com
```

## 怎么用（无需 Python）

直接用大白话告诉 Claude 你想做什么，例如：

- "帮我把这个项目发布出去"（给它 zip 路径）
- "我要个能装到手机上的 APK"
- "我都发过哪些项目？"

Claude 会自动推断动作、只追问缺失的信息（首次使用时问用户名/密码），登录后
直接通过 MCP 工具或 HTTP 接口完成全流程。**你不需要安装或运行任何东西。**
完整的 Agent 流程见 `SKILL-zh.md`。

凭证会保存到本地 `~/.publisher/config.json`，之后会自动刷新 token。

## 可选：Python 脚本（高级 / CI 用户）

如果你偏好命令行，`scripts/` 提供了等价路径。大多数用户可忽略。

```bash
python scripts/save-credentials.py   # 保存用户名/密码并拿 token
python scripts/get-token.py          # 刷新并打印 "Bearer <TOKEN>"
python scripts/clear-credentials.py  # 删除本地凭证
```

保存位置：`~/.publisher/config.json`。

## MCP 工具

> 规范名为 `project_*`（推荐）。旧 `game_*` 仍作为已废弃别名保留。面向用户描述时说"项目"。

- `user_login_or_register`
- `project_publish`
- `project_list`
- `project_build_apk`
- `project_publish_and_build_apk`
