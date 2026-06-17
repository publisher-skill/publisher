---
name: publisher
description: Publish HTML frontend games to the AI Game MCP platform. Supports uploading zip game packages, obtaining accessible URLs, querying the list of published games, and packaging games into Android APKs. Covers the full workflow of MCP tools user_login_or_register, game_publish, game_list, game_build_apk, game_publish_and_build_apk.
---

# Publisher Skill

English | [简体中文](./SKILL-zh.md)

This Skill is used to publish HTML frontend games to the AI Game MCP platform
and optionally package them as Android APKs in one step.

Platform URL:

```text
https://ai-pub.pushwebly.com
```

## Applicable Scenarios

Use this Skill when the user asks you to:

- Publish an HTML game
- Upload a zip package containing `index.html` or `index.htm`
- Obtain the game access URL
- Query the list of games already published by the user
- Package a published game into an Android APK
- Publish a game and generate the APK at the same time (one-step)
- Configure or invoke the AI Game MCP service for the user

## Platform Capabilities

Backend MCP tools (5 in total):

**User:**

1. `user_login_or_register`
   - Log in or register a user
   - Registers if the user does not exist; otherwise verifies the password and logs in
   - Returns a token

**Game Publishing:**

2. `game_publish`
   - Publish a zip game package
   - Parameters include the Bearer token, game name, and server-side local zip path
   - Returns the game URL

3. `game_list`
   - Query the list of games published by the current user

**APK Packaging:**

4. `game_build_apk`
   - Package a published game into an Android APK
   - Parameters include the Bearer token and gameId
   - Returns the APK download link

5. `game_publish_and_build_apk`
   - Publish the zip + build the APK in one step
   - Parameters include the Bearer token, game name, and zip path
   - Returns both the game URL and the APK download link

## Local Credential Storage and Automatic Token Retrieval

This Skill supports saving the username and password to a private configuration
file on the user's local machine:

```text
~/.publisher/config.json
```

On first use, ask the user to run this in the Skill directory:

```bash
python scripts/save-credentials.py
```

Arguments can also be passed directly:

```bash
python scripts/save-credentials.py "username" "password"
```

The script calls the login/register API to automatically obtain a token and saves:

```json
{
  "baseUrl": "https://ai-pub.pushwebly.com",
  "username": "alice",
  "password": "user_password",
  "authorization": "Bearer <TOKEN>",
  "userId": 1
}
```

Before subsequent uses, if a token is needed, prefer running:

```bash
python scripts/get-token.py
```

It reads the locally saved username/password, automatically re-logs in to obtain
the latest token, and outputs:

```text
Bearer <TOKEN>
```

If the user wants to clear the local credentials:

```bash
python scripts/clear-credentials.py
```

Security requirements:

- Do not write the user's username/password into the Skill zip package.
- Only save to the user's local `~/.publisher/config.json`.
- On Linux/Mac the script will try to set the config file permission to `600`.
- If the user explicitly provides a token in the current conversation, prefer
  that token; otherwise use `scripts/get-token.py` to obtain one.

## MCP Integration Configuration

After the user logs in, replace the placeholder below with the token:

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

## Pre-publish Checklist

Before publishing, confirm that:

1. The file is in `.zip` format.
2. The zip contains `index.html` or `index.htm`.
3. If the zip has nested directories, the directory containing the entry file can be located.
4. The game name is not empty.
5. The user already has a token; if not, first run `python scripts/get-token.py`
   to obtain one automatically; if there is no local configuration yet, guide
   the user to run `python scripts/save-credentials.py` to save their credentials.

## Recommended Workflow

### 1. Obtain a Token

If the user does not have a token, first try to obtain one automatically:

```bash
python scripts/get-token.py
```

If it reports that the configuration does not exist, guide the user to save their credentials:

```bash
python scripts/save-credentials.py
```

You can also guide the user to visit:

```text
https://ai-pub.pushwebly.com
```

Click "Login" in the upper-right corner and enter the username and password.
The system will automatically log in or register and return a token.

Alternatively, use the HTTP API:

```bash
curl -X POST https://ai-pub.pushwebly.com/api/auth/login-or-register \
  -H "Content-Type: application/json" \
  -d '{"username":"alice","password":"123456"}'
```

Verify whether the token is valid:

```bash
curl https://ai-pub.pushwebly.com/api/auth/verify-token \
  -H "Authorization: Bearer <TOKEN>"
```

If the token is invalid or expired, the API returns 401 with a clear error
message such as `Invalid or expired token`.

### 2. Publish a Game

If MCP tools are available, call:

```text
game_publish
```

Parameters:

```json
{
  "authorization": "Bearer <TOKEN>",
  "projectName": "game-name",
  "zipFilePath": "server-side local zip path"
}
```

If only the HTTP API is available:

```bash
curl -X POST https://ai-pub.pushwebly.com/api/games/publish \
  -H "Authorization: Bearer <TOKEN>" \
  -F "project_name=demo" \
  -F "file=@demo.zip"
```

### 3. Query the Game List

If MCP tools are available, call:

```text
game_list
```

Parameters:

```json
{
  "authorization": "Bearer <TOKEN>"
}
```

HTTP API:

```bash
curl https://ai-pub.pushwebly.com/api/games/my \
  -H "Authorization: Bearer <TOKEN>"
```

### 4. Build an APK

If the user wants to package a published game into an Android APK:

```text
game_build_apk
```

Parameters:

```json
{
  "authorization": "Bearer <TOKEN>",
  "gameId": 12
}
```

HTTP API:

```bash
curl -X POST https://ai-pub.pushwebly.com/api/apk/build \
  -H "Authorization: Bearer <TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{"gameId": 12}'
```

Response:

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

Download the APK:

```bash
curl -O "https://ai-pub.pushwebly.com/api/apk/download/airplane-war_aB3xYz.apk"
```

### 5. Publish and Build (One-step)

The most common approach — publish the zip and generate the APK at the same time:

```text
game_publish_and_build_apk
```

Parameters:

```json
{
  "authorization": "Bearer <TOKEN>",
  "projectName": "airplane-war",
  "zipFilePath": "/opt/game/my-game.zip"
}
```

The response contains both the game URL and the APK download link:

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

HTTP API (multipart upload + build):

```bash
curl -X POST https://ai-pub.pushwebly.com/api/apk/publish-and-build \
  -H "Authorization: Bearer <TOKEN>" \
  -F "project_name=airplane-war" \
  -F "file=@game.zip"
```

## Reply Format to Users

### Publish Only

```
Game published successfully!

Game name: <projectName>
Access URL: <url>
Status: enabled
```

### Publish + Build

```
Game published successfully!

Game name: <projectName>
Access URL: <playUrl>
APK download: <apkUrl>

Transfer the APK to your phone to install and play. Each APK has a unique
package name and will not overwrite other games.
```

### Build APK for an Existing Game Only

```
APK build complete!

Game name: <projectName>
APK download: <apkUrl>
```

### Failure

Clearly state the failure reason, for example:

- The zip does not contain index.html or index.htm
- The token is invalid or expired
- The zip file path does not exist
- The game name is empty
- APK build timed out (the build takes about 2-3 minutes, please retry later)
- The server is not configured with the Android SDK (contact the administrator)

## Notes

- Do not ask the user for any sensitive information other than the plaintext password.
- The token is only used for `Authorization: Bearer` and must not be leaked to unrelated third parties.
- The game access URL can be shared publicly.
- If a game is disabled in the backend, the access URL returns 403.
- APK builds take 1-3 minutes; duplicate requests during a build are automatically deduplicated.
- Each APK has a unique package name (`com.pushwebly.g{playToken}`) so installations do not overwrite each other.
- `game_publish_and_build_apk` is the recommended usage: publish and build in one step.
