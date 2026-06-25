# Publisher Skill

English | [简体中文](./README-zh.md)

Publish HTML frontend projects to the publishing platform.

## Install to Claude Code

Extract this directory to:

```text
~/.claude/skills/publisher
```

Then use the Skill inside Claude Code.

## Platform URL

```text
https://pushwebly.com
```

## How to use (no Python required)

Just tell Claude what you want in plain language, for example:

- "Publish this project for me" (give it the zip path)
- "I want an APK I can install on my phone"
- "What projects have I published?"

Claude infers the action, asks only for what's missing (username/password on
first use), logs in, and completes the workflow directly via the MCP tools or
HTTP APIs. **You don't need to install or run anything.** See `SKILL.md` for the
full agent workflow.

Credentials are saved locally to `~/.publisher/config.json` so subsequent runs
refresh the token automatically.

 

## MCP Tools

> Canonical names are `project_*` (preferred). The old `game_*` names still work
> as deprecated aliases. Describe them as "project" operations to users.

- `user_login_or_register`
- `project_publish`
- `project_list`
- `project_build_apk`
- `project_publish_and_build_apk`
