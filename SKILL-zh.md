---
name: publisher
description: Publish HTML frontend games to the AI Game MCP platform. Supports uploading zip game packages, obtaining accessible URLs, querying the list of published games, and packaging games into Android APKs. Covers the full workflow of MCP tools user_login_or_register, game_publish, game_list, game_build_apk, game_publish_and_build_apk.
---

# Publisher Skill

[English](./SKILL.md) | 简体中文

本 Skill 用于将 HTML 前端游戏发布到 AI Game MCP 平台，并可选择同时打包为 Android APK。

平台地址：

```text
https://ai-pub.pushwebly.com
```

## 适用场景

当用户要求你执行以下操作时使用本 Skill：

- 发布一个 HTML 游戏
- 上传包含 `index.html` 或 `index.htm` 的 zip 包
- 获取游戏访问 URL
- 查询用户已发布的游戏列表
- 将已发布的游戏打包成 Android APK
- 同时发布游戏并生成 APK（一步完成）
- 为用户配置或调用 AI Game MCP 服务

## 平台能力

后端 MCP 工具（共 5 个）：

**用户：**

1. `user_login_or_register`
   - 登录或注册用户
   - 用户不存在则注册；否则验证密码并登录
   - 返回 token

**游戏发布：**

2. `game_publish`
   - 发布 zip 游戏包
   - 参数包括 Bearer token、游戏名称、服务器端本地 zip 路径
   - 返回游戏 URL

3. `game_list`
   - 查询当前用户已发布的游戏列表

**APK 打包：**

4. `game_build_apk`
   - 将已发布的游戏打包成 Android APK
   - 参数包括 Bearer token 和 gameId
   - 返回 APK 下载链接

5. `game_publish_and_build_apk`
   - 一步完成：发布 zip + 构建 APK
   - 参数包括 Bearer token、游戏名称和 zip 路径
   - 同时返回游戏 URL 和 APK 下载链接

## 本地凭据存储与自动获取 Token

本 Skill 支持将用户名和密码保存到用户本机的私有配置文件中：

```text
~/.publisher/config.json
```

首次使用时，请用户在 Skill 目录下运行：

```bash
python scripts/save-credentials.py
```

也可以直接传参：

```bash
python scripts/save-credentials.py "用户名" "密码"
```

脚本会调用登录/注册接口自动获取 token，并保存：

```json
{
  "baseUrl": "https://ai-pub.pushwebly.com",
  "username": "alice",
  "password": "user_password",
  "authorization": "Bearer <TOKEN>",
  "userId": 1
}
```

后续使用前，如需 token，优先运行：

```bash
python scripts/get-token.py
```

它会读取本地保存的用户名/密码，自动重新登录获取最新 token，并输出：

```text
Bearer <TOKEN>
```

如果用户想清除本地凭据：

```bash
python scripts/clear-credentials.py
```

安全要求：

- 不要将用户的用户名/密码写入 Skill zip 包中。
- 仅保存到用户本地的 `~/.publisher/config.json`。
- 在 Linux/Mac 上，脚本会尝试将配置文件权限设置为 `600`。
- 如果用户在当前对话中明确提供了 token，优先使用该 token；否则使用 `scripts/get-token.py` 获取。

## MCP 集成配置

用户登录后，将以下占位符替换为实际 token：

```json
{
  "mcpServers": {
    "publisher": {
      "type": "streamable-http",
      "url": "https://ai-pub.pushwebly.com/mcp",
      "headers": {
        "Authorization": "Bearer <TOKEN>"
      }
    }
  }
}
```

## 发布前检查清单

发布前请确认：

1. 文件格式为 `.zip`。
2. zip 中包含 `index.html` 或 `index.htm`。
3. 如果 zip 有嵌套目录，能够定位到包含入口文件的目录。
4. 游戏名称不为空。
5. 用户已有 token；如果没有，先运行 `python scripts/get-token.py` 自动获取；如果本地还没有配置，引导用户运行 `python scripts/save-credentials.py` 保存凭据。

## 推荐工作流

### 1. 获取 Token

如果用户还没有 token，先尝试自动获取：

```bash
python scripts/get-token.py
```

如果提示配置不存在，引导用户保存凭据：

```bash
python scripts/save-credentials.py
```

也可以引导用户访问：

```text
https://ai-pub.pushwebly.com
```

点击右上角"登录"，输入用户名和密码。系统将自动登录或注册并返回 token。

或者使用 HTTP API：

```bash
curl -X POST https://ai-pub.pushwebly.com/api/auth/login-or-register \
  -H "Content-Type: application/json" \
  -d '{"username":"alice","password":"123456"}'
```

验证 token 是否有效：

```bash
curl https://ai-pub.pushwebly.com/api/auth/verify-token \
  -H "Authorization: Bearer <TOKEN>"
```

如果 token 无效或已过期，API 返回 401 并附带明确的错误信息，如 `Invalid or expired token`。

### 2. 发布游戏

如果 MCP 工具可用，调用：

```text
game_publish
```

参数：

```json
{
  "authorization": "Bearer <TOKEN>",
  "projectName": "游戏名称",
  "zipFilePath": "服务器端本地 zip 路径"
}
```

如果只有 HTTP API 可用：

```bash
curl -X POST https://ai-pub.pushwebly.com/api/games/publish \
  -H "Authorization: Bearer <TOKEN>" \
  -F "project_name=demo" \
  -F "file=@demo.zip"
```

### 3. 查询游戏列表

如果 MCP 工具可用，调用：

```text
game_list
```

参数：

```json
{
  "authorization": "Bearer <TOKEN>"
}
```

HTTP API：

```bash
curl https://ai-pub.pushwebly.com/api/games/my \
  -H "Authorization: Bearer <TOKEN>"
```

### 4. 构建 APK

如果用户想将已发布的游戏打包成 Android APK：

```text
game_build_apk
```

参数：

```json
{
  "authorization": "Bearer <TOKEN>",
  "gameId": 12
}
```

HTTP API：

```bash
curl -X POST https://ai-pub.pushwebly.com/api/apk/build \
  -H "Authorization: Bearer <TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{"gameId": 12}'
```

响应示例：

```json
{
  "code": 0,
  "message": "ok",
  "data": {
    "gameId": 12,
    "projectName": "airplane-war",
    "apkUrl": "https://ai-pub.pushwebly.com/api/apk/download/airplane-war_aB3xYz.apk",
    "fileName": "airplane-war_aB3xYz.apk",
    "fileSize": 2300000
  }
}
```

下载 APK：

```bash
curl -O "https://ai-pub.pushwebly.com/api/apk/download/airplane-war_aB3xYz.apk"
```

### 5. 发布并构建（一步完成）

最常用的方式——同时发布 zip 并生成 APK：

```text
game_publish_and_build_apk
```

参数：

```json
{
  "authorization": "Bearer <TOKEN>",
  "projectName": "airplane-war",
  "zipFilePath": "/opt/game/my-game.zip"
}
```

响应中包含游戏 URL 和 APK 下载链接：

```json
{
  "gameId": 12,
  "projectName": "airplane-war",
  "playUrl": "https://ai-pub.pushwebly.com/play/aB3xYz/",
  "status": "enabled",
  "apkUrl": "https://ai-pub.pushwebly.com/api/apk/download/airplane-war_aB3xYz.apk",
  "apkFileName": "airplane-war_aB3xYz.apk",
  "apkFileSize": 2300000
}
```

HTTP API（multipart 上传 + 构建）：

```bash
curl -X POST https://ai-pub.pushwebly.com/api/apk/publish-and-build \
  -H "Authorization: Bearer <TOKEN>" \
  -F "project_name=airplane-war" \
  -F "file=@game.zip"
```

## 回复用户的格式

### 仅发布

```
游戏发布成功！

游戏名称：<projectName>
访问地址：<url>
状态：enabled
```

### 发布 + 构建

```
游戏发布成功！

游戏名称：<projectName>
访问地址：<playUrl>
APK 下载：<apkUrl>

将 APK 传输到手机即可安装游玩。每个 APK 拥有唯一的包名，不会覆盖其他游戏。
```

### 仅为已有游戏构建 APK

```
APK 构建完成！

游戏名称：<projectName>
APK 下载：<apkUrl>
```

### 失败

明确说明失败原因，例如：

- zip 中不包含 index.html 或 index.htm
- token 无效或已过期
- zip 文件路径不存在
- 游戏名称为空
- APK 构建超时（构建大约需要 2-3 分钟，请稍后重试）
- 服务器未配置 Android SDK（联系管理员）

## 注意事项

- 除了明文密码外，不要向用户索要其他敏感信息。
- token 仅用于 `Authorization: Bearer`，不得泄露给无关第三方。
- 游戏访问 URL 可以公开分享。
- 如果游戏在后端被禁用，访问 URL 将返回 403。
- APK 构建需要 1-3 分钟；构建期间的重复请求会自动去重。
- 每个 APK 拥有唯一的包名（`com.pushwebly.g{playToken}`），因此安装不会相互覆盖。
- 推荐使用 `game_publish_and_build_apk`：一步完成发布和构建。
