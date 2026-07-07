# AGENTS.md — Publisher (publish HTML projects & build APKs)

Instructions for Codex (and any AGENTS.md-aware agent) to publish HTML frontend
projects to the publishing platform and optionally build Android APKs.

Platform: `https://ai-pub.pushwebly.com`

Skill version: see the `version` field in SKILL.md / SKILL-zh.md frontmatter (single source: the `VERSION` file).

> Note for Codex: its MCP support is local STDIO only and does NOT support this
> platform's remote streamable-http MCP. So **use the HTTP APIs via `curl`** below
> — that is the reliable path here. No Python is required.
>
> The canonical tool names / API paths are `project_*` and `/api/projects`. The
> old `game_*` names, `/api/games` paths, and `gameId` field still work (backend
> keeps aliases) but are deprecated — use the `project_*` forms. Always say
> "project" to the user.

## Principles
- **Conversation first.** Users phrase requests vaguely ("publish this", "I want
  an APK for my phone"). Infer intent, complete the flow, ask only for what's
  genuinely missing.
- **No Python.** Get tokens, save credentials, and call APIs yourself with `curl`
  and file tools. Never ask the user to install or run Python.

## Intent → action
| User roughly says | Action | Ask only if missing |
|---|---|---|
| publish / ship / put online | publish | zip path, project name |
| want an APK / installable on phone | publish + build | zip path, project name |
| build APK for a project I already published | build APK | id (find via list) |
| make an app private/public, add/remove password | change visibility | app URL, target visibility (optional password if private) |
| what have I published / my projects | list | — |
| log in / register | get token | username, password |

When unsure: "Just publish, or publish and build an Android APK too?"

## Version check (first, non-blocking)
Before the publish flow, self-check the skill version, then continue regardless of the result
(never block publishing on this). Read the local `version` from SKILL frontmatter, then:
```bash
curl -s https://ai-pub.pushwebly.com/api/skill/latest-version
```
If the response `data.version` is newer than local, you MUST output an update notice that
INCLUDES the actual download URL (do not omit it, do not leave a placeholder) — pick the link
by the user's OS: Windows → `data.downloadUrlWindows`, macOS → `data.downloadUrlMac`, otherwise
fall back to the generic `data.downloadUrl`. Write the URL as a clickable Markdown link
`[URL](URL)` — do NOT wrap it in backticks/inline code, or it won't be clickable. Output the
notice in the SAME language the user is conversing in (Chinese if they write Chinese, English if
English) — do not hard-code English. If equal/newer, stay silent. If the request fails, silently
skip. Always proceed to the publish flow next.

Comparison: a version is `major.minor.patch`; compare segment by segment as integers, left to
right (pad missing segments with 0). Compare as integers, not strings — `1.10.0` > `1.9.0`.

## Publish flow (in order)
1. **Account**: have token/local creds → next. None → ask username+password, login/register
   (auto-registers; on invalid creds tell the backend reason and let them retry).
2. **Public or private?** Ask: "public (anyone with the link) or private (needs a 6-character password)?"
3. **Branch**: public → publish (`visibility=public`), return link. private → ask whether
   the user wants a custom password; if yes publish with `visibility=private` +
   `access_password=<6 digits or letters>`, if no publish with only `visibility=private`
   and the backend auto-generates a 6-char password (returned in the response). Relay the
   clean URL and the final password separately; tell the user to type the password on the page.
   Do not append the password to the URL.
4. Default to public if unspecified. Password is 6 digits or letters; validate a custom one, otherwise the backend generates it.

## Token (no Python)
A Bearer token is required for every publishing call. Order:
1. Token already given in chat → use it.
2. `~/.publisher/config.json` exists → read username/password and re-login to refresh.
3. Neither → ask for username + password (auto-registers if new), then login & save.

Login — write the body to a temp `login.json` first (avoids shell quote-escaping):
```bash
curl -s -X POST https://ai-pub.pushwebly.com/api/auth/login-or-register \
  -H "Content-Type: application/json" -d @login.json
```
`data.token` in the response → header `Authorization: Bearer <token>`. Delete temp file.

Save credentials by writing `~/.publisher/config.json` yourself:
```json
{"baseUrl":"https://ai-pub.pushwebly.com","username":"alice","password":"...","authorization":"Bearer <TOKEN>","userId":1}
```
On Linux/Mac `chmod 600` it. Clear = delete the file. On HTTP 401, re-login once and retry.
Never commit credentials anywhere except `~/.publisher`.

## Operations (HTTP)
Publish (public):
```bash
curl -s -X POST https://ai-pub.pushwebly.com/api/projects/publish \
  -H "Authorization: Bearer <TOKEN>" -F "project_name=demo" -F "file=@demo.zip"
```
Publish (private; access_password optional, 6 digits or letters, auto-generated if omitted):
```bash
curl -s -X POST https://ai-pub.pushwebly.com/api/projects/publish \
  -H "Authorization: Bearer <TOKEN>" -F "project_name=demo" -F "file=@demo.zip" \
  -F "visibility=private" -F "access_password=a1b2c3"
```
List my projects:
```bash
curl -s https://ai-pub.pushwebly.com/api/projects/my -H "Authorization: Bearer <TOKEN>"
```
Change visibility (public <-> private; URL in, backend parses the id and checks ownership — you
can only change your own apps). `access_password` optional, only when switching to private:
```bash
curl -s -X PATCH https://ai-pub.pushwebly.com/api/projects/visibility \
  -H "Authorization: Bearer <TOKEN>" -H "Content-Type: application/json" \
  -d '{"url":"https://ai-pub.pushwebly.com/play/aB3xYz/","visibility":"private","accessPassword":"a1b2c3"}'
```
Build APK for an existing project:
```bash
curl -s -X POST https://ai-pub.pushwebly.com/api/apk/build \
  -H "Authorization: Bearer <TOKEN>" -H "Content-Type: application/json" -d '{"projectId":12}'
```
Publish + build in one step (recommended; add visibility/access_password for private):
```bash
curl -s -X POST https://ai-pub.pushwebly.com/api/apk/publish-and-build \
  -H "Authorization: Bearer <TOKEN>" -F "project_name=airplane-war" -F "file=@project.zip"
```

## Pre-publish checks
`.zip` format; contains `index.html` or `index.htm`; project name non-empty; valid token.

## Report back
On success report: project name, access URL (for private apps give the clean URL and state the
access password separately — do not append `?pwd=` to the URL), and APK download link if built
("transfer the APK to
your phone to install; each APK has a unique package name"). On failure state the reason:
no index.html, token invalid/expired, bad zip path, empty project name, private app's
custom password invalid (6 digits or letters; auto-generated if omitted), APK build
timeout (~2-3 min, retry), or server missing Android SDK.
