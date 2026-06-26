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

## 怎么用

直接用大白话告诉 Claude 你想做什么，例如：

- "帮我把这个项目发布出去"（给它 zip 路径）
- "我要个能装到手机上的 APK"
- "我都发过哪些项目？"

Claude 会自动推断动作、只追问缺失的信息（首次使用时问用户名/密码），登录后
直接通过 MCP 工具或 HTTP 接口完成全流程。**你不需要安装或运行任何东西。**
完整的使用说明见 `SKILL-zh.md`。

## 文档


- [中文文档](https://pushwebly.com/#/preview-docs?type=windows&lan=zh)
- [English Docs](https://pushwebly.com/#/preview-docs?type=windows&lan=en)
- [日本語ドキュメント](https://pushwebly.com/#/preview-docs?type=windows&lan=ja)
- [한국어 문서](https://pushwebly.com/#/preview-docs?type=windows&lan=ko)

## MCP 工具

> 规范名为 `project_*`（推荐）。旧 `game_*` 仍作为已废弃别名保留。面向用户描述时说"项目"。

- `user_login_or_register`
- `project_publish`
- `project_list`
- `project_update_visibility`
- `project_build_apk`
- `project_publish_and_build_apk`
