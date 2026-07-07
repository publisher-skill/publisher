---
name: publisher
version: 1.1.2
description: 把 HTML 前端项目发布到发布平台。支持上传 zip 项目包、获取可访问 URL、查询已发布项目列表、把项目打包成安卓 APK、修改已发布应用的公开/私密可见性。无需用户安装 Python，Claude 可直接通过 MCP 工具或 HTTP 接口完成全流程。
---

# Publisher Skill

[English](./SKILL.md) | 简体中文

把 HTML 前端项目发布到发布平台，并可一步打包成安卓 APK。

平台地址：

```text
https://pushwebly.com
```

> 说明：规范的 MCP 工具名与接口路径是 `project_*` 与 `/api/projects`。
> 旧的 `game_*` 工具名、`/api/games` 路径、`gameId` 字段**仍兼容**（后端保留别名），
> 但已废弃，新接入请一律用 `project_*` / `/api/projects` / `projectId`。
> 面向用户表达时一律说"项目"。

## 核心原则（先读这一段）

1. **对话优先**：用户通常用模糊的口语表达需求（"帮我把这个项目发出去""我要个能装手机上的"）。
   你要从对话中**推断意图**，自己补齐流程，不要让用户去记命令或参数名。
2. **无需 Python**：获取 token、保存凭证、调用接口这些事，**你（Claude）自己就能做**——
   用内置工具读写文件、用 `curl` 调接口即可。**不要要求用户安装或运行 Python。**
   `scripts/` 里的 Python 脚本只是给喜欢命令行/CI 的高级用户的**可选**项。
3. **缺什么才问什么**：只追问真正缺失的信息，已知或可推断的不要反复确认。

## 意图识别（从模糊表达映射到动作）

| 用户大致说的话 | 推断动作（工具名） | 还需要确认/补齐的 |
|----------------|--------------------|-------------------|
| "把这个项目发布 / 发出去 / 上线" | `project_publish` | zip 路径、项目名 |
| "我要个能装到手机上的 / 要 APK / 打个安卓包" | `project_publish_and_build_apk` | zip 路径、项目名 |
| "已经发过的那个项目，给我打个 APK" | `project_build_apk` | id（可先 `project_list` 找） |
| "把那个应用改成私密 / 改成公开 / 加个访问密码 / 去掉密码" | `project_update_visibility` | 应用链接、目标可见性（私密时可选密码） |
| "我都发过哪些项目 / 我的项目列表" | `project_list` | 无 |
| "登录 / 注册 / 我的账号" | 登录拿 token | 用户名、密码 |

推断不确定时，用一句话向用户确认动作即可，例如："你是想直接发布，还是发布的同时打个安卓 APK？"

## 发布对话流程

当用户表达发布、部署、上线、分享应用、生成访问链接等意图时，必须进入本流程。

<HARD-GATE>
发布流程是阻塞式状态机。只要当前步骤缺少用户输入，模型必须停止推进，只能提出当前步骤的一个问题，并等待用户回复。
禁止根据上下文猜测答案。
禁止自动选择公开/私密。
禁止自动生成访问密码，除非用户明确选择让系统生成。
禁止在未完成全部必需步骤前调用发布接口。
每次回复最多只能包含一个面向用户的问题。
</HARD-GATE>

### 状态机总则

- 进入流程先走 `S-1`（版本检查，不阻塞），再按 `S0 -> S1 -> S2 -> S3 -> S4` 顺序推进。
- 除 `S-1` 外不允许跳步。
- 不允许一次询问多个字段。
- 用户已经明确提供的信息可以记录，不重复询问。
- 用户回答含糊时，只针对当前字段追问一次。
- 当前步骤完成后，才进入下一步骤。
- 如果需要等待用户输入，回复末尾不要附加说明、建议或下一步预告。

---

### S-1：版本检查（发布流程第一个节点，不阻塞）

进入发布流程时，**先做一次版本自检**，再进入 S0。这一步**不属于 `<HARD-GATE>` 的阻塞范围**：无论检查结果如何、即使接口不可达，都要继续往下走，绝不因为版本问题中断发布。

做法：

1. 读取本地 skill 的版本号：本文件 frontmatter 里的 `version` 字段。
2. 查询平台最新版本（**无需登录**）：

   ```bash
   curl -s https://ai-pub.pushwebly.com/api/skill/latest-version
   ```

   返回体 `data` 含：`version`（最新版本）、`downloadUrl`（通用纯文档包，跨平台、解压即用）、`downloadUrlWindows`（Windows 安装工具 .exe）、`downloadUrlMac`（Mac 安装工具 .zip）。

3. 比对本地 `version` 与返回的 `version`。

   **比对规则**：版本号形如 `主.次.修订`（`major.minor.patch`），**每段当整数、从左到右依次比较**——先比主版本，相等再比次版本，再相等才比修订号；段数不齐时缺的段补 0（如 `1.1` 视作 `1.1.0`）。注意是按整数比，不是按字符串比：`1.10.0` **大于** `1.9.0`（第二段 `10 > 9`），若按字符串会误判。从小到大示例：`1.0.0 < 1.0.9 < 1.1.0 < 1.2.0 < 1.10.0 < 2.0.0`。

   - 本地 **低于** 最新版（本地三段整数序列小于返回值）：**必须**在继续发布前向用户输出一条更新提示，**且提示中必须包含可点击的下载地址**（不打断流程，但不可省略这条提示）。**按用户操作系统给对应下载地址**：

     - Windows 用户 → 用 `downloadUrlWindows`
     - macOS 用户 → 用 `downloadUrlMac`
     - 无法判断系统、或对应字段为空 → 回退用通用的 `downloadUrl`

     提示文案（**必须用与用户对话相同的语言输出**——用户说中文就用中文，说英文就用英文，不要固定用某种语言；把下载地址替换成上面选定的真实 URL；**下载地址要写成可点击的 Markdown 链接 `[URL](URL)`，不要用反引号包成行内代码，否则用户点不动**；不能留占位符、不能只说“有新版本”而不给地址）：

     > 提示：检测到 Publisher skill 有新版本 `<version>`，你当前为 `<本地 version>`，下载地址：[https://ai-pub.pushwebly.com/downloads/AI_Publisher_skill.exe](https://ai-pub.pushwebly.com/downloads/AI_Publisher_skill.exe)（下载更新不影响本次发布）。

   - 本地等于或高于最新版：不提示，静默继续。
   - 接口请求失败/超时/无法解析：**静默跳过**，直接进入 S0，不要向用户报错。

4. 无论上述哪种情况，紧接着进入 `S0`。

> 这一步是“发布流程的第一个节点”，但它只做提示、不收集输入、不阻塞，所以每次回复“只能有一个面向用户的问题”的限制对它不适用——版本提示可以与 S0 的第一个问题放在同一条回复里。

---

### S0：检查账号状态

先检查是否已有可用 token / 本地凭证。

- 如果已有账号凭证：进入 `S2`。
- 如果没有账号凭证：进入 `S1_USERNAME`。
- 如果无法检查账号状态：询问用户是否已有发布账号。

向用户提问：

> 我需要先确认发布账号：你现在已经有可用账号或 token 吗？

用户回答：
- 有：要求用户提供或确认 token / 登录凭证，然后进入 `S2`。
- 没有：进入 `S1_USERNAME`。

---

### S1：注册登录流程

#### S1_USERNAME：采集注册用户名

如果没有用户名，只问：

> 请提供要注册的用户名。

收到用户名后，记录为 `username`，进入 `S1_PASSWORD`。

#### S1_PASSWORD：采集注册密码

如果没有密码，只问：

> 请提供注册密码。

收到密码后，记录为 `password`，进入 `S1_VALIDATE`。

#### S1_VALIDATE：联合校验

只有同时拥有 `username` 和 `password` 后，才调用后端接口进行联合校验。

校验通过：
- 创建账号
- 完成登录
- 提示：`注册登录成功`
- 进入 `S2`

校验失败：
- 展示后端返回的具体错误原因
- 只询问需要修正的那一项
- 不终止注册流程

---

### S2：询问应用可见性

如果尚未明确公开或私密，只问：

> 这个应用是否公开？公开表示任何人凭链接可访问；私密则需要 6 位访问密码。

用户回答：
- 公开 / 是 / public：记录 `visibility=public`，进入 `S4`
- 私密 / 否 / private：记录 `visibility=private`，进入 `S3`
- 不明确：继续只问这一项

---

### S3：私密访问密码

如果 `visibility=private`，必须询问是否自定义密码，只问：

> 是否要自定义 6 位访问密码？也可以回复“系统生成”。

用户回答：
- 给出密码：校验必须为 6 位数字或字母；通过后记录 `accessPassword=<用户密码>`，进入 `S4`
- 回复系统生成 / 不需要 / 随机：不传 `accessPassword`，由后端生成，进入 `S4`
- 密码格式错误：只提示格式要求，并重新询问密码

---

### S4：执行发布

只有满足以下条件之一，才允许调用发布接口：

- `visibility=public`
- `visibility=private` 且用户已选择自定义密码或系统生成密码

发布参数：

公开应用：

```json
{
  "visibility": "public"
}

私密应用，自定义密码：
{
  "visibility": "private",
  "accessPassword": "<6位数字或字母>"
}

私密应用，系统生成密码：

{
  "visibility": "private"
}

返回结果格式

发布成功后回复：
  公开应用：
  - 发布成功。
  - 访问链接：<url>

  私密应用：
  - 发布成功。
  - 访问链接：<url>
  - 访问密码：<password>

  访问方式：
  - 打开链接后，在页面弹出的输入框里输入访问密码即可。
  - 把链接和密码分别告诉对方，不要把密码拼接到链接里。

发布失败时：
  展示失败原因
  保持在当前发布流程中
  只询问修复当前失败所需的一个信息

> 默认值：用户没明确回答是否公开时，**默认公开**。访问密码为 **6 位数字或字母**；用户提供时校验格式，不满足要提示重输；用户不提供则由后端自动生成。

## 凭证与 Token（无需 Python）

token 是调用所有发布接口的前提。获取顺序如下：

1. **当前对话里用户已直接给了 token** → 直接用。
2. **本地已保存凭证** → 读取 `~/.publisher/config.json`，用里面的用户名/密码重新登录刷新 token。
3. **都没有** → 直接问用户："请告诉我用户名和密码，没有账号会自动注册。"拿到后登录并保存。

### 登录 / 注册拿 token（你直接用 curl 调）

为避免不同系统下的引号转义问题，**先把请求体写成临时文件再用 `@` 引用**：

把下面内容写入临时文件 `login.json`（用文件写入工具，不要用 echo）：

```json
{"username":"用户名","password":"密码"}
```

然后：

```bash
curl -s -X POST https://ai-pub.pushwebly.com/api/auth/login-or-register \
  -H "Content-Type: application/json" \
  -d @login.json
```

返回体中的 `data.token` 即 token，最终的 Authorization 头是 `Bearer <token>`。
用完删除临时文件。

### 保存凭证（你直接写文件，不经过 Python）

征得用户同意后，用文件写入工具把凭证写到用户主目录下的 `~/.publisher/config.json`：

```json
{
  "baseUrl": "https://ai-pub.pushwebly.com",
  "username": "alice",
  "password": "用户的明文密码",
  "authorization": "Bearer <TOKEN>",
  "userId": 1
}
```

- Linux/Mac 上写完可执行 `chmod 600 ~/.publisher/config.json` 收紧权限。
- 下次需要 token 时，读这个文件拿到用户名/密码，重新登录刷新即可。
- 清除凭证：删除 `~/.publisher/config.json` 这个文件即可。

### 校验 token 是否有效

```bash
curl -s https://ai-pub.pushwebly.com/api/auth/verify-token \
  -H "Authorization: Bearer <TOKEN>"
```

失效或过期会返回 401，并带有 `Invalid or expired token` 之类的明确信息。
遇到 401 就用本地凭证重新登录刷新一次再重试。

### 安全要求

- 不要把用户名/密码写进 Skill 的 zip 包，只写到用户本地 `~/.publisher/config.json`。
- token 只用于 `Authorization: Bearer`，不要泄露给无关第三方。
- 除明文密码外，不要向用户索取其他敏感信息。

## 平台能力（后端 MCP 工具，共 6 个）

> 规范工具名为 `project_*`；旧 `game_*` 仍兼容但已废弃。面向用户描述时说"项目"。

**用户：**

1. `user_login_or_register` —— 登录或注册，不存在则注册、存在则校验密码登录，返回 token。

**项目发布：**

2. `project_publish` —— 发布 zip 项目包，参数含 Bearer token、项目名、服务端本地 zip 路径，返回项目 URL。
3. `project_list` —— 查询当前用户已发布的项目列表。
4. `project_update_visibility` —— 修改已发布应用的可见性（公开↔私密），参数含 Bearer token、应用链接、目标可见性、可选访问密码；仅能改本人应用。

**APK 打包：**

5. `project_build_apk` —— 把已发布的项目打包成安卓 APK，参数含 Bearer token、projectId，返回 APK 下载链接。
6. `project_publish_and_build_apk` —— 一步完成"发布 zip + 打 APK"，返回项目 URL 和 APK 下载链接（**最常用，推荐**）。

> 优先调用 MCP 工具；若当前环境没有挂载 MCP 工具，则改用下文的 HTTP 接口（curl），效果等价。

## 发布前检查清单

发布前确认：

1. 文件是 `.zip` 格式。
2. zip 内包含 `index.html` 或 `index.htm`。
3. 若 zip 内有嵌套目录，能定位到包含入口文件的目录。
4. 项目名不为空。
5. 已拿到有效 token（参见上面的"凭证与 Token"，无需 Python）。

## 操作流程

### 1. 发布项目

有 MCP 工具时调用 `project_publish`，参数：

```json
{
  "authorization": "Bearer <TOKEN>",
  "projectName": "项目名",
  "zipFilePath": "服务端本地 zip 路径",
  "visibility": "public",
  "accessPassword": ""
}
```

- `visibility`：`public`（默认，公开）或 `private`（私密）。
- `accessPassword`：仅 `private` 时有意义，**6 位数字或字母**；**留空/省略时后端自动生成**，并在返回结果的 `accessPassword` 字段给出。

私密示例（自定义密码）：

```json
{
  "authorization": "Bearer <TOKEN>",
  "projectName": "项目名",
  "zipFilePath": "服务端本地 zip 路径",
  "visibility": "private",
  "accessPassword": "a1b2c3"
}
```

私密示例（不填密码，后端自动生成）：

```json
{
  "authorization": "Bearer <TOKEN>",
  "projectName": "项目名",
  "zipFilePath": "服务端本地 zip 路径",
  "visibility": "private"
}
```

返回体里 `accessPassword` 即最终密码（自动生成时由后端给出），务必转告用户。

只能用 HTTP 时（公开）：

```bash
curl -s -X POST https://ai-pub.pushwebly.com/api/projects/publish \
  -H "Authorization: Bearer <TOKEN>" \
  -F "project_name=demo" \
  -F "file=@demo.zip"
```

HTTP 私密发布（加 visibility；access_password 可选，不填后端自动生成）：

```bash
curl -s -X POST https://ai-pub.pushwebly.com/api/projects/publish \
  -H "Authorization: Bearer <TOKEN>" \
  -F "project_name=demo" \
  -F "file=@demo.zip" \
  -F "visibility=private" \
  -F "access_password=a1b2c3"
```

私密应用的访问方式：把干净的访问链接（`https://.../play/<token>/`）和访问密码**分别**告诉对方，
对方打开链接后在自动弹出的页面里输入密码即可；首次输对后浏览器会种 Cookie，子资源免再带参数。
**不要把密码拼接进链接**。（注：后端仍兼容 `?pwd=密码` 形式，但不再向用户主推这种带后缀的链接。）

### 2. 查询项目列表

MCP 工具 `project_list`，参数 `{"authorization": "Bearer <TOKEN>"}`。

HTTP：

```bash
curl -s https://ai-pub.pushwebly.com/api/projects/my \
  -H "Authorization: Bearer <TOKEN>"
```

### 2.5 修改应用可见性（公开↔私密）

把已发布的应用在公开和私密之间互转。**以应用链接为输入**，后端从链接里解析出应用标识，
并校验该应用必须属于当前登录用户——**只能改自己发布的应用，改不了别人的**。

MCP 工具 `project_update_visibility`，参数：

```json
{
  "authorization": "Bearer <TOKEN>",
  "url": "https://ai-pub.pushwebly.com/play/aB3xYz/",
  "visibility": "private",
  "accessPassword": "a1b2c3"
}
```

- `url`：应用访问链接（也兼容直接传 playToken 或带 `?pwd=` 的链接，后端会自行解析）。
- `visibility`：目标可见性，`public`（公开）或 `private`（私密）。
- `accessPassword`：**仅转私密时可选**，6 位数字或字母；不填则后端自动生成并在返回里给出。转公开时无需此字段，原密码会被清除。

转公开示例：

```json
{
  "authorization": "Bearer <TOKEN>",
  "url": "https://ai-pub.pushwebly.com/play/aB3xYz/",
  "visibility": "public"
}
```

HTTP：

```bash
curl -s -X PATCH https://ai-pub.pushwebly.com/api/projects/visibility \
  -H "Authorization: Bearer <TOKEN>" \
  -H "Content-Type: application/json" \
  -d @visibility.json
```

（`visibility.json` 内容即上面的 JSON body，用文件写入工具生成，避免引号转义问题。）

返回体 `data` 含最终的 `visibility`、`url`，以及转私密时的 `accessPassword`（含自动生成的）。
转私密后，按"私密应用"的方式把链接和密码分别转告用户，不要拼接 `?pwd=`。

常见错误：
- 链接对应的应用不存在 / 已删除 → 提示用户核对链接是否复制完整。
- 该应用属于其他用户 → 明确告知"只能修改自己发布的应用"，无法代改他人应用。
- 转私密时自定义密码格式非法（须 6 位数字或字母）→ 提示重输或改用系统生成。

### 3. 给已发布项目打 APK

MCP 工具 `project_build_apk`，参数：

```json
{
  "authorization": "Bearer <TOKEN>",
  "projectId": 12
}
```

HTTP：

```bash
curl -s -X POST https://ai-pub.pushwebly.com/api/apk/build \
  -H "Authorization: Bearer <TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{"projectId": 12}'
```

返回里的 `data.apkUrl` 即下载链接。

### 4. 发布并打包（一步，推荐）

最常用：发布 zip 的同时生成 APK。MCP 工具 `project_publish_and_build_apk`，参数：

```json
{
  "authorization": "Bearer <TOKEN>",
  "projectName": "airplane-war",
  "zipFilePath": "/opt/project/my-project.zip",
  "visibility": "public",
  "accessPassword": ""
}
```

> 同样支持 `visibility=private`（可选 `accessPassword`，6 位数字或字母，不填自动生成），规则与"发布项目"一致。

返回同时含项目 URL 与 APK 下载链接：

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

> 注：响应体里的 `gameId` 字段名暂未改动（属于后端 DTO，改动影响面更大），
> 它就是项目 id，按 `projectId` 理解即可。

HTTP（multipart 上传 + 打包）：

```bash
curl -s -X POST https://ai-pub.pushwebly.com/api/apk/publish-and-build \
  -H "Authorization: Bearer <TOKEN>" \
  -F "project_name=airplane-war" \
  -F "file=@project.zip"
```

## 给用户的回复格式

### 仅发布（公开）

```
项目发布成功！

项目名：<projectName>
访问地址：<url>
可见性：公开
状态：已启用
```

### 仅发布（私密）

```
私密项目发布成功！

项目名：<projectName>
访问地址：<url>
访问密码：<accessPassword>（6 位数字或字母；若未自定义则为系统生成）
可见性：私密

把访问地址和访问密码分别发给对方；对方打开链接后在页面输入密码即可访问。不要把密码拼接到链接里。
```

### 发布 + 打包

```
项目发布成功！

项目名：<projectName>
访问地址：<playUrl>
APK 下载：<apkUrl>

把 APK 传到手机即可安装运行，每个 APK 包名唯一，不会互相覆盖。
```

### 仅给已有项目打 APK

```
APK 打包完成！

项目名：<projectName>
APK 下载：<apkUrl>
```

### 失败时

明确说明原因，例如：

- zip 内没有 index.html 或 index.htm
- token 无效或已过期（可重新登录刷新后重试）
- zip 文件路径不存在
- 项目名为空
- 私密应用自定义的访问密码格式非法（须为 6 位数字或字母；不提供则后端自动生成）
- APK 打包超时（打包约 2-3 分钟，稍后重试）
- 服务端未配置 Android SDK（请联系管理员）

## MCP 集成配置（可选）

若用户想长期挂载 MCP 工具，登录拿到 token 后替换占位符：

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

## 附：可选的 Python 脚本（高级用户）

`scripts/` 下提供了三个 Python 脚本，**仅供愿意用命令行/CI 的用户**，**普通用户无需用到，也不必安装 Python**：

- `scripts/save-credentials.py` —— 交互式保存用户名/密码并拿 token。
- `scripts/get-token.py` —— 读本地凭证刷新并打印 `Bearer <TOKEN>`。
- `scripts/clear-credentials.py` —— 删除本地凭证。

它们做的事和上文"凭证与 Token"完全等价。**默认路径请用 curl + 文件工具，不要主动让用户跑这些脚本。**

## 备注

- 项目访问 URL 可公开分享；后台禁用某项目后访问会返回 403。
- APK 打包约 1-3 分钟，打包中重复请求会自动去重。
- 每个 APK 包名唯一（`com.pushwebly.g{playToken}`），安装不会互相覆盖。
- `project_publish_and_build_apk` 是推荐用法：一步发布并打包。
