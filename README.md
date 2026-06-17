# Publisher Skill

English | [简体中文](./README-zh.md)

Publish HTML frontend games to the AI Game MCP platform.

## Install to Claude Code

Extract this directory to:

```text
~/.claude/skills/publisher
```

Then use the Skill inside Claude Code.

## Platform URL

```text
https://ai-pub.pushwebly.com
```

## Save Credentials for Automatic Token Retrieval

On first use, run this in the Skill directory:

```bash
python scripts/save-credentials.py
```

Enter your username and password when prompted. The script will automatically
log in / register and save the configuration to:

```text
~/.ai-game-publisher/config.json
```

On subsequent uses, run:

```bash
python scripts/get-token.py
```

It will refresh the token using the saved credentials and output:

```text
Bearer <TOKEN>
```

Clear the locally stored credentials:

```bash
python scripts/clear-credentials.py
```

## MCP Tools

- `user_login_or_register`
- `game_publish`
- `game_list`
- `game_build_apk`
- `game_publish_and_build_apk`
