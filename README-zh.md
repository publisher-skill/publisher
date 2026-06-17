# Publisher Skill

[English](./README.md) | 简体中文

将 HTML 前端游戏发布到 AI Game MCP 平台。

## 安装到 Claude Code

将此目录解压到：

```text
~/.claude/skills/publisher
```

然后在 Claude Code 中使用该 Skill。

## 平台地址

```text
https://ai-pub.pushwebly.com
```

## 保存凭据以自动获取 Token

首次使用时，在 Skill 目录下运行：

```bash
python scripts/save-credentials.py
```

根据提示输入用户名和密码。脚本将自动登录/注册，并将配置保存到：

```text
~/.ai-game-publisher/config.json
```

后续使用时，运行：

```bash
python scripts/get-token.py
```

它将使用已保存的凭据刷新 Token，并输出：

```text
Bearer <TOKEN>
```

清除本地存储的凭据：

```bash
python scripts/clear-credentials.py
```

## MCP 工具

- `user_login_or_register` — 用户登录或注册
- `game_publish` — 发布游戏
- `game_list` — 游戏列表
- `game_build_apk` — 构建 APK
- `game_publish_and_build_apk` — 发布游戏并构建 APK
