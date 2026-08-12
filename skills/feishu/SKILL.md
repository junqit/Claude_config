---
name: feishu
description: |-
  通过 CLI 管控飞书全量资源：文档、知识库、云盘、多维表格、表格、幻灯片、权限、日历日程、任务待办。
  触发条件（满足任一激活）：
  1. 含飞书链接：*.feishu.cn 及对应路径（wiki/docx/base/sheets/drive/slides/board/calendar/task）；
  2. 提及飞书文档 / 知识库 / 云盘 / 多维表格 / 表格 / 幻灯片 / 权限分享 / 日历会议 / 任务待办；
  3. 要求读取、创建、修改飞书相关资源。
  强制规则：带飞书 URL 时，仅用本技能feishu fetch读取，禁止直接调用 WebFetch 读取飞书内容（无权限认证）。
version: 1.3.2
---

# 飞书 CLI

所有操作格式：`feishu <模块> <子命令>`，输出为 JSON。常用入口：`feishu fetch <url>` 读取任意资源、`feishu search` 搜索文档。

模块总览：`docx` 文档 · `wiki` 知识库 · `drive` 云盘 · `bitable` 多维表格 · `sheet` 电子表格 · `slides` 幻灯片 · `perm` 权限 · `comment` 评论 · `search` 搜索 · `user` 用户 · `board` 画板 · `calendar`/`cal` 日历日程 · `task` 任务 · `tasklist` 任务清单

## 前置准备

### 安装与版本检查

**首次使用前**检查安装状态：

```bash
feishu --version
```

- **找不到命令** → 提示用户安装：
  ```bash
  npm install -g @mi/feishu@latest --registry https://pkgs.d.xiaomi.net/artifactory/api/npm/mi-npm/
  ```
- **版本号 < 本文件 frontmatter `version`** → 必须先升级（部分命令可能不存在）：
  ```bash
  feishu update    # 一键升级 + 自动同步 skill 文件到所有 AI 工具
  ```
- **版本号 ≥ frontmatter `version`** → 版本合格，继续

> 安装/升级时 CLI 会自动将 skill 文件同步到所有检测到的 AI 工具（Claude Code、Cursor、Windsurf、Codex、OpenCode、Cline、Kiro、Continue、Roo Code、Aider、Trae）。
> 日常使用中 CLI 会在后台检查更新（每 6 小时一次），如有新版会自动升级并同步 skill 文件。

### 认证

CLI 在每次调用时自动管理 access_token 刷新（30 天内 refresh_token 有效期内无需干预）。

**认证失败的 Agent 处理规范**

当任意命令返回下列错误之一时，视为需要重新授权：

- `"Not logged in. Please run: feishu auth login"`
- `"Session expired (30 days). Please run: feishu auth login"`
- 错误 JSON 中 `category` 字段为 `"token_invalid"`

Agent 应按以下步骤处理，**无需事先征询用户许可**：

1. 向用户简述当前状态及即将执行的操作。
2. 直接执行 `feishu auth login`。该命令会将授权 URL 与提示信息输出至 stderr，并持续轮询授权状态。
3. 将授权 URL 完整、原样转发给用户，说明其需在浏览器中完成授权，CLI 将自动检测授权完成状态。
4. 命令返回结果满足 `logged_in: true` 时，重新执行触发本次授权的原始命令，无需用户再次下达指令。
5. 若在授权窗口期（默认 600 秒）内出现 `expired_token`、`access_denied` 或其他非 `authorization_pending` 错误，终止流程并将错误详情报告给用户。

```bash
feishu auth login    # 通过浏览器 OAuth 授权（认证失败时 Agent 应主动执行）
feishu auth status   # 查询 token 状态（诊断用途）
feishu auth logout   # 清除已保存的 token
```

> 说明：`feishu auth login` 仅启动 OAuth Device Code 授权流程，最终授权动作由用户在浏览器中完成，Agent 代为执行该命令不构成越权。

### 环境变量

以下变量可在 shell 或 `.env` 中设置，用于覆盖 CLI 默认行为：

| 变量 | 说明 | 默认 |
|------|------|------|
| `FEISHU_APP_ID` | 飞书应用 App ID（覆盖 npm 包内置凭据，自建应用需要） | 内置 |
| `FEISHU_APP_SECRET` | 飞书应用 App Secret（与 `FEISHU_APP_ID` 成对使用） | 内置 |
| `FEISHU_AUTH_FILE` | Token 存储文件的绝对路径（多账号切换 / CI 隔离时使用） | `~/.feishu/auth.json` |
| `FEISHU_DOMAIN` | `feishu` / `lark` / 自定义 open api URL | `feishu` |

> `FEISHU_APP_ID` 和 `FEISHU_APP_SECRET` 需成对提供才会覆盖内置凭据；只设置其中一个会被忽略。
> 切换 `FEISHU_AUTH_FILE` 相当于切换登录身份，若目标文件不存在需重新执行 `feishu auth login`。

---

## 全局约定

### 企业邮箱

涉及人员的操作（权限管理、@提及、人员字段）统一使用小米企业邮箱 `xxx@xiaomi.com`。用户提及某人时也应转换为邮箱格式。

### 用户输入（人员参数）

凡是需要指定"某人"的参数，CLI 统一支持三种格式，**自动解析，无需手动获取 open_id**：

| 格式 | 示例 | 说明 |
|------|------|------|
| 姓名 | `张三` | 通过企业内部搜索自动解析 |
| 企业邮箱 | `zhangsan@xiaomi.com` | 直接解析为 open_id |
| open_id | `ou_xxx` | 已知时直接使用 |

适用范围：`calendar add-attendees --user-ids`、`calendar freebusy --user-id`、`task member add --members`、`bitable` 人员字段。

> 如果姓名匹配到多人，CLI 会列出候选并提示使用邮箱消歧义。

各模块的特殊处理：
- **权限管理（perm add/remove）**：直接传邮箱，无需转换
- **文档 @提及（mention-user）**：用 `email=` 属性，CLI 自动解析为 open_id
- **多维表格人员字段**：写入时支持 `[{"email":"xxx@xiaomi.com"}]` 或 `[{"name":"张三"}]`，CLI 自动解析为 open_id
- **search `--owner`**：仍需 open_id，使用 `feishu user resolve <email>` 获取

### 时间格式

所有时间字段（多维表格、搜索结果、任务日期等）均以 **ISO8601 字符串**返回（如 `"2024-01-26T16:00:00.000Z"`），可直接读取，无需换算时间戳。

多维表格日期字段过滤时，可直接传日期字符串，CLI 自动转换：
```bash
feishu bitable search APP TBL --filter "截止日期>=2024-01-01"
```

### 默认存储位置

`docx create` 和 `bitable create-app` 不指定位置时，自动存入个人知识库（`my_library`），无需显式传 `--wiki-space my_library`。

### 文档写入规范

所有向飞书文档写入内容的操作（`docx create`、`docx update`）执行前**必须先读取 `reference/extended-markdown.md`**，了解块类型语法、限制和 emoji 用法。

内容质量要求：
- **结构清晰**：标题层级 ≤ 4 层，用 Callout 高亮块突出关键信息
- **视觉节奏**：用分割线、分栏（Grid）、表格打破大段纯文字
- **图文交融**：流程和架构优先用 Mermaid 可视化
- **克制留白**：Callout 不过度使用、加粗只强调核心词

### URL Token 提取

| URL 格式 | Token |
|----------|-------|
| `.../docx/ABC123` | doc_token = `ABC123` |
| `.../wiki/ABC123` | wiki_token = `ABC123` |
| `.../drive/folder/ABC123` | folder_token = `ABC123` |
| `.../base/ABC123` | app_token = `ABC123` |
| `.../sheets/ABC123` | spreadsheetToken = `ABC123` |

---

## 通用操作

### 读取任意资源（fetch）

一条命令读取任意飞书资源，自动识别 URL 类型。

```bash
feishu fetch <url_or_token>
```

支持 docx、wiki、多维表格（`/base/`）、电子表格（`/sheets/`）URL 或裸 token。如果是 wiki URL，会自动解析底层资源类型：

| URL / 资源类型 | 返回内容 |
|---------------|---------|
| docx / wiki→文档 | `type`, `title`, `token`, `markdown`, `media` |
| 多维表格 / wiki→多维表格 | `type`, `app_token`, `tables`, `hint` |
| 电子表格 / wiki→电子表格 | `type`, `title`, `token`, `sheets[]`, `preview`（首个工作表前 50 行）, `hint` |
| 幻灯片 / wiki→幻灯片 | `type`, `title`, `token`, `revision_id`, `slide_count`, `slides[]`, `hint` |
| wiki→思维导图/文件 | `type`, `title`, `token`, `hint`（思维导图为只读，无法通过 CLI 创建或修改内容；如需创建思维导图，使用 Mermaid `mindmap` 代码块写入文档） |

#### 局部读取（--scope，仅 docx/wiki→文档）

对大文档按需读取部分内容，减少传输量。**推荐工作流**：先 `--scope outline` 获取大纲和 block ID，再 `--scope section` 精确读取目标章节。

```bash
feishu fetch <url> --scope outline                                 # 仅返回标题大纲（含 block ID）
feishu fetch <url> --scope keyword --keyword "搜索词"               # 返回匹配关键词的段落
feishu fetch <url> --scope section --start-block-id <block_id>     # 返回指定标题下的完整章节
feishu fetch <url> --scope range --start-block-id <id> --end-block-id <id>  # 返回区间内容
```

可选参数：`--context-before N`、`--context-after N`（keyword/section/range 模式下返回匹配点前后 N 个兄弟块）。

```bash
feishu fetch <token> --type image                     # 下载媒体（返回 base64）
feishu fetch <token> --type image --output ./img.png  # 保存到文件
feishu fetch <url> --download-images                  # 批量下载文档中所有图片到 <系统临时目录>/feishu-media/
feishu fetch <url> --download-images ./assets         # 批量下载到指定目录
```

**文档中的媒体**

`feishu fetch <doc_url>` 返回的 markdown 中，图片、白板、文件、视频以 HTML 标签形式出现：

```
<image token="Z1Fjxxx..." width="1833" height="2491"/>
<whiteboard token="Z1Fjxxx..."/>
<file token="XXX" name="video.mp4" view-type="2"/>
```

返回结果里的 `media` 数组列出了所有嵌入媒体的 token。推荐用 `--download-images` 一次性下载所有图片：

```bash
# 方式 A（推荐）：一键下载所有媒体，media 数组会包含 path 字段
feishu fetch https://mi.feishu.cn/docx/ABC123 --download-images
# → { markdown: "...", media: [{token, type, path: "<tmpdir>/feishu-media/Z1Fj.png"}] }

# 方式 B：逐个下载
feishu fetch Z1Fjxxx --type image        # 图片 → base64
feishu fetch Z1Fjxxx --type whiteboard   # 白板 → 截图
```

### 搜索（search）

```bash
feishu search [关键词] [选项]
```

| 选项 | 说明 |
|------|------|
| `--owner <open_id>` | 按创建者筛选（可重复指定多个） |
| `--sort <规则>` | `open_time`、`edit_time`、`edit_time_asc`、`create_time` |
| `--created <范围>` | `"2024-01-01,2024-03-31"` 或 `"last_30_days"` |
| `--opened <范围>` | 最近打开时间（格式同上） |
| `--size <n>` | 每页条数（默认 20，最大 20） |
| `--page-token <token>` | 翻页 |

```bash
feishu search "项目计划"
feishu search --sort open_time
feishu search --owner ou_xxx --created last_7_days
```

### 评论（comment）

适用于文档、电子表格、多维表格等各类文件。

```bash
feishu comment list <url_or_token> [--type all|whole|segment] [--page-size N]
feishu comment add <url_or_token> -c "评论内容"
```

### 用户查找（user）

```bash
feishu user resolve zhangsan@xiaomi.com                      # 邮箱 → open_id
feishu user resolve zhangsan@xiaomi.com lisi@xiaomi.com      # 批量解析
feishu user info                                              # 查看当前用户信息
feishu user info ou_xxx                                       # 查看指定用户信息
```

> 通常不需要手动调用 `resolve`。文档 @提及和表格人员字段已支持直接传邮箱（见下方各模块说明）。

---

## 文档（docx）

### 修改文档（update）

`docx update` 是编辑既有文档的入口命令，支持完整 URL（含 wiki URL）与裸 token。

#### 操作决策规则

Agent 应严格依据下列规则确定操作方式，不得基于经验猜测：

| 意图 | 命令形式 |
|------|---------|
| 在文档末尾追加内容 | `--mode append -c "..."` |
| 仅修改文档标题 | `--title "新标题"`（不指定 `--mode`） |
| 修改文档中已存在的段落 | 先按下节"选区定位规范"确定选区，再指定 `--mode replace` / `insert-before` / `insert-after` / `delete` |

当无法在文档中定位到具体的目标片段时，应回退至 `--mode append` 追加内容；禁止在无充分依据时使用 `--mode overwrite`。

#### 命令签名

```bash
feishu docx update <url_or_token> [--mode <mode>] [选区选项] [内容选项] [--title <新标题>]
```

- **内容选项**：`-c "<markdown>"` 或 `-f <path>` 或经由管道从 stdin 读取（三者互斥）。
- **选区选项**（`replace` / `replace-all` / `insert-before` / `insert-after` / `delete` 模式必须指定其一）：
  - `--select-title "## 章节名"`：按 Markdown 标题命中整个章节，作用范围延伸至下一个同级或更高级标题之前。**首选方式。**
  - `--select "<文本片段>"`：按原文文本片段匹配，要求逐字符一致（含标点与换行）。
  - `--select "<前缀>...<后缀>"`：省略号语法，跨段落锚定首尾之间的连续内容。

#### 选区定位规范

采用 `--select` / `--select-title` 前，Agent 应通过以下方式确认目标存在：

1. 若可获取文档标题结构，优先执行 `feishu docx read <url> --scope outline` 或 `feishu fetch <url> --scope outline` 获取标题清单，从中直接选取。
2. 需要按文本内容匹配时，应使用文档中确实存在的完整片段，避免拼接、意译或跨块粘接。
3. `--select` 与 `--select-title` 不得同时指定。

#### 常见任务范例

```bash
# 1. 追加章节
feishu docx update <url> --mode append -c "## 新增章节\n\n段落内容"

# 2. 按标题替换整段
feishu docx update <url> --mode replace --select-title "## 过时章节" -c "## 过时章节\n\n新版本内容"

# 3. 按标题删除整段
feishu docx update <url> --mode delete --select-title "## 过时章节"

# 4. 在指定章节前 / 后插入内容
feishu docx update <url> --mode insert-before --select-title "## 结论" -c "## 新章节\n\n..."
feishu docx update <url> --mode insert-after  --select-title "## 引言" -c "## 补充\n\n..."

# 5. 修改文档标题
feishu docx update <url> --title "新标题"

# 6. 追加中 @ 提及用户（直接使用企业邮箱，CLI 自动解析为 open_id）
feishu docx update <url> --mode append -c '请 <mention-user email="zhangsan@xiaomi.com"/> 查看'
```

#### `--mode` 取值说明

| 模式 | 是否需要选区 | 用途 |
|------|:-----------:|------|
| `append` | 否 | 在文档末尾追加内容 |
| `replace` | 是 | 替换选中段落 |
| `delete` | 是 | 删除选中段落 |
| `insert-before` / `insert-after` | 是 | 在选中段落之前 / 之后插入内容 |
| `replace-all` | `--select` | 替换所有匹配片段（不兼容 `--select-title`） |
| `overwrite` | 否 | 清空文档后重写全部内容。**破坏性操作**，将不可逆地丢失文档中的图片与画板；非 TTY 环境须显式指定 `--force`。 |

#### 错误处理指引

命令失败时返回的 JSON 中包含 `write_error`、`category`、`hint` 三个关键字段。Agent 应依据 `write_error` 中的关键词按下表处理：

| 报错关键词 | 处理策略 |
|-----------|---------|
| `No match found for --select` | 使用 `feishu docx read <url> --scope outline` 重新确认文档结构，改用 `--select-title` 或更换为文档中实际存在的片段。 |
| `matched N locations` | 选区不唯一。仅在本地块级匹配路径下触发（`--mode replace-all` 或 docs_ai 降级场景）。补充上下文使匹配唯一，或改用 `--mode replace-all` 显式声明"替换全部"。 |
| `No heading found matching` | 参考错误信息中列出的 `Available headings` 与 `Did you mean` 建议，使用其中的标题重新调用。 |
| `overwrite ... use --force` | 仅在确认需清空整篇文档时追加 `--force`；否则应改用 `append` 或 `replace` 完成局部修改。 |

> **匹配引擎**：`--select` 在 `replace` / `insert-before` / `insert-after` / `delete` 模式下优先经由飞书 `docs_ai` 服务端匹配（原生支持 `A...B` 省略号跨段），失败时自动降级至本地块级匹配路径（响应内含 `engine: "blocks_fallback"`）。`replace-all` 始终使用本地路径。
>
> **docs_ai 匹配语义注意**：`docs_ai` 的 `str_replace` 只替换文档中**首次出现**的匹配项，且不会因存在多处匹配而报错。若目标是替换全部匹配片段，必须显式使用 `--mode replace-all`。
>
> **退出码**：
> - `0`：成功。
> - `1`：命令异常（参数错误、认证失败、未捕获异常等）。
> - `2`：写入失败。响应 JSON 携带 `write_error`（`docx update`）或 `content_write_error`（`docx create` 已创建文档但内容写入失败）字段，同时包含 `hint` 指示下一步。
> - `3`：成功但存在警告（如 mermaid 渲染失败），响应 JSON 携带 `warnings[]`；警告详情写入 stderr。

### 创建文档（create）

一步完成创建、写入内容、指定位置。不指定位置时默认存入个人知识库。

```bash
feishu docx create <标题> [-c markdown | -f file] [--folder TOKEN | --wiki-node TOKEN | --wiki-space ID]
```

`--folder`、`--wiki-node`、`--wiki-space` 三者互斥。

```bash
feishu docx create "会议记录"                                       # 默认存入个人知识库
feishu docx create "项目计划" -c "## 目标\n\n- 目标 1" --folder fldcnXXX
feishu docx create "API 设计" -f design.md --wiki-node wikcnXXX
feishu docx create "团队文档" -c "内容" --wiki-space 7542032457XXX   # 指定团队知识空间
```

### 读取文档（read）

```bash
feishu docx read <doc_token>    # 返回 Markdown 内容（通过 docs_ai 单次 API 调用）
```

#### 局部读取（--scope）

`docx read` 支持与 `fetch` 相同的 `--scope` 参数（outline/section/range/keyword），用法一致。适合已知 doc_token 的场景。

### 重命名文档标题（--title）

`--title` 已在上文"常见任务对照表 5"给出用法。使用注意：
- 通过 wiki URL 重命名最可靠；直接用 docx token 时若返回权限错误，请在飞书客户端中操作。
- 同一次调用中 `--title` 可与 `--mode` 组合，先改内容再改标题。

### 底层操作（高级，日常任务不需要）

> 块操作、表格操作、批量删除/更新、图片/视频上传、彩色文字等完整文档：见 `reference/docx-advanced.md`

常用入口速查：

```bash
feishu docx blocks <doc_token>                               # 列出所有块（获取 block_id）
feishu docx delete-block  <doc_token> <block_id>            # 删除单个块
feishu docx delete-blocks <doc_token> <parent_id> --start 2 --end 5   # 范围删除
feishu docx delete-blocks <doc_token> blockA,blockB,blockC  # ID 列表删除
feishu docx batch-update-blocks <doc_token> --records '[{"block_id":"xxx","content":"新文本"}]'
feishu docx upload-video <doc_token> --file ./demo.mp4       # 上传视频（展开卡片）
```

### 所需权限

`docx:document` `docx:document:create` `docx:document.block:convert` `drive:drive`

---

## 多维表格（bitable）

### 查询

```bash
feishu bitable meta <url_or_token>                            # 获取 app_token 和表列表（支持 URL 或裸 app_token）
feishu bitable fields <app_token> <table_id>                  # 列出字段（列）
feishu bitable records <app_token> <table_id> [--page-size N] [--automatic-fields] # 列出记录（行）
feishu bitable record <app_token> <table_id> <record_id>      # 单条记录
```

### 搜索记录

```bash
feishu bitable search <app_token> <table_id> [--filter "表达式"] [--sort "字段 desc"] [--fields "f1,f2"] [--automatic-fields]
```

筛选语法：`字段=值`、`字段!=值`、`字段>N`、`字段~关键词`、`字段?`（非空）、`字段!?`（为空）

`--filter` 可重复传入，多个条件自动以 AND 组合：

```bash
feishu bitable search <app_token> <table_id> --filter "系列=Claude 4" --filter "最大输出 Token>8192"
```

### 增删改

**操作前先执行 `fields` 确认字段名称。** 字段名必须完全匹配。

```bash
# 单条操作
feishu bitable create-record <app_token> <table_id> --fields '{"姓名":"小明","年龄":30}'
feishu bitable update-record <app_token> <table_id> <record_id> --fields '{"姓名":"小红"}'
feishu bitable delete-record <app_token> <table_id> <record_id>

# 人员字段：支持三种格式，CLI 自动解析为 open_id（create/update/batch-create/batch-update 均支持）
feishu bitable create-record <app_token> <table_id> --fields '{"负责人":[{"name":"张三"}]}'           # 姓名（IDM 搜索）
feishu bitable create-record <app_token> <table_id> --fields '{"负责人":[{"email":"zhangsan@xiaomi.com"}]}'  # 邮箱
feishu bitable create-record <app_token> <table_id> --fields '{"负责人":[{"id":"ou_xxx"}]}'           # open_id（已知时直接用）
# 多人：混合格式均可
feishu bitable create-record <app_token> <table_id> --fields '{"负责人":[{"name":"张三"},{"email":"lisi@xiaomi.com"}]}'

# 日期字段：支持 "YYYY-MM-DD" 字符串，CLI 自动转为毫秒时间戳
feishu bitable create-record <app_token> <table_id> --fields '{"截止日期":"2026-03-14"}'
```

**批量操作（每次最多 500 条）：**

`batch-create` 和 `batch-update` 支持 `--records` 内联 JSON 或 `-f` 文件读取（互斥）。大数据量推荐 `-f`。

```bash
# 批量创建：--records 传直接字段对象数组（CLI 内部自动封装为 {fields:...}，无需手动包裹）
feishu bitable batch-create <app_token> <table_id> --records '[{"名称":"A"},{"名称":"B"}]'
feishu bitable batch-create <app_token> <table_id> -f records.json

# 批量更新：--records 必须是 {id, fields} 结构（需要 id 来定位要更新的记录）
feishu bitable batch-update <app_token> <table_id> --records '[{"id":"recXXX","fields":{"状态":"已完成"}}]'
feishu bitable batch-update <app_token> <table_id> -f updates.json

# 批量删除（逗号分隔 ID，不是 JSON）
feishu bitable batch-delete <app_token> <table_id> recA,recB,recC
```

### 视图管理

```bash
feishu bitable views <app_token> <table_id> [--page-size N] [--page-token TOKEN]  # 列出所有视图
feishu bitable get-view <app_token> <table_id> <view_id>                          # 读取视图完整配置
feishu bitable create-view <app_token> <table_id> --name "视图名" --type grid
feishu bitable delete-view <app_token> <table_id> <view_id>
feishu bitable records ... --view-id vewXXX   # 按视图过滤记录
feishu bitable search  ... --view-id vewXXX   # 带视图条件搜索
feishu bitable search  ... --view-id vewXXX --filter "字段>值"  # 视图条件 + 额外筛选（CLI 自动合并，AND 逻辑）
```

视图类型：`grid` / `kanban` / `gallery` / `gantt` / `form`

**更新视图配置（`update-view`）：** 选项可组合使用。

```bash
feishu bitable update-view <app_token> <table_id> <view_id> \
  [--name "新名称"] \
  [--filter "字段=值" --filter "字段~关键词"] [--or] [--clear-filter] \
  [--hide-fields "f1,f2"] [--show-fields "f1"] [--clear-hidden]
```

### 结构管理

> `--fields` 均支持 `-f <path>` 文件形式（与 `--fields` 互斥）。字段较多时推荐用文件。`create-app` 和 `create-table` 会自动清理默认空行。

```bash
# 创建应用（--folder / --wiki-node / --wiki-space 三选一，不填默认个人知识库）
feishu bitable create-app "项目追踪" [--folder fldcnXXX | --wiki-node wikcnXXX]
feishu bitable create-app "客户表" -f fields.json --wiki-node wikcnXXX  # 创建时附带字段定义

# 建表：先一次性定义字段（推荐），或先建表再逐步 create-field
feishu bitable create-table <app_token> --name "客户表" -f fields.json
feishu bitable create-field <app_token> <table_id> --name "状态" --type 3 \
  --property '{"options":[{"name":"进行中"},{"name":"已完成"}]}'
feishu bitable batch-create-fields <app_token> <table_id> -f fields.json

# 管理：改名、删除、字段、应用
feishu bitable rename-table <app_token> <table_id> --name "Q2 OKR"
feishu bitable delete-table <app_token> <table_id>
feishu bitable update-field <app_token> <table_id> <field_id> --name "新名称"
feishu bitable delete-field <app_token> <table_id> <field_id>
feishu bitable update-app <app_token> --name "产品需求池"
feishu bitable copy-app <app_token> --name "Q3 追踪" --folder fldcnXXX  # 只复制结构
```

> 数字字段 formatter、Progress/Currency/Rating 变体：见 `reference/bitable-reference.md`（字段创建变体）

**附件上传：** 附件字段必须先上传获取 `file_token`，再写入记录。

```bash
feishu bitable upload-attachment <app_token> <table_id> --file ./report.pdf   # → { file_token }
feishu bitable create-record <app_token> <table_id> --fields '{"附件":[{"file_token":"DRiFbxxx"}]}'
```

> 筛选语法、字段类型与 Property、错误码、并发限制：见 `reference/bitable-reference.md`
> 字段值写入/返回格式详解：见 `reference/bitable-record-values.md`
> 已知 API 行为与注意事项：见 `reference/api-behaviors.md`

### 批量按 ID 读取

```bash
feishu bitable batch-get <app_token> <table_id> recA,recB,recC [--fields "Name,Status"]
```

当已知 record_id 时，比 `records` 列表或 `search` 更高效。返回：`{ records: [...] }`

> 批量表管理、仪表盘、角色权限、表单、自动化工作流命令：见 `reference/bitable-reference.md`

### 所需权限

`bitable:app`

---

## 电子表格（sheet）

> **性能提示**：对同一张电子表格执行多次操作时，先调 `feishu sheet sheets <token>` 获取 sheetId，后续 range 全部用 `<sheetId>!A1:D10` 格式。用 sheetId 可直接跳过工作表名查询，显著减少 API 调用。

### 创建

不指定位置时默认存入个人知识库（`my_library`），与 `docx create` / `bitable create-app` 行为一致。`--folder`、`--wiki-node`、`--wiki-space` 三者互斥。

```bash
feishu sheet create "季度数据"                                      # 默认存入个人知识库
feishu sheet create "季度数据" --folder fldcnXXX                    # 指定云盘文件夹
feishu sheet create "季度数据" --wiki-node wikcnXXX                 # 在知识库节点下创建
feishu sheet create "季度数据" --wiki-space 7542032457XXX           # 指定团队知识空间
```

返回：`{ spreadsheetToken, title, url, wikiToken? }`

### 读取

```bash
feishu sheet meta   <url_or_token>           # 获取电子表格基本信息 + 工作表列表
feishu sheet sheets <url_or_token>           # 仅列出工作表（含 sheetId、行列数、是否隐藏）
feishu sheet read   <url_or_token> <range>   # 读取单元格数据
```

**range 格式**：`<工作表>!<起始>:<结尾>`，工作表可用名称或 sheetId：

```bash
feishu sheet read TOKEN "Sheet1!A1:D10"      # 按工作表名
feishu sheet read TOKEN "abc123!A1:D10"      # 按 sheetId（更快，跳过名称查询）
feishu sheet read TOKEN "Sheet1!A:C"         # 整列
feishu sheet read TOKEN "Sheet1!A1:Z50" --csv > data.csv   # 导出为 CSV 文件
feishu sheet read TOKEN "Sheet1!A1:B5" --render Formula    # 读取公式字符串
```

`--render` 选项：`FormattedValue`（默认）· `UnformattedValue`（原始值）· `Formula`（公式）

返回：`{ spreadsheetToken, range, values: [[...], ...] }`

### 写入

```bash
feishu sheet write  <url_or_token> <range> --values <json>     # 覆盖写入
feishu sheet write  <url_or_token> <range> -f data.json        # 从文件读取
feishu sheet append <url_or_token> <工作表> --values <json>    # 追加到末尾
feishu sheet append <url_or_token> <工作表> -f rows.json
```

`--values` 格式：二维 JSON 数组，每行一个子数组：

```bash
feishu sheet write TOKEN "Sheet1!A1:B3" --values '[["Name","Score"],["Alice",95],["Bob",88]]'
feishu sheet write TOKEN "Sheet1!A1" --values '[["Name","Score"],["Alice",95]]'  # 起始格自动推算结束位置
feishu sheet append TOKEN Sheet1 --values '[["Carol",91],["Dave",77]]'
```

**公式写入**：以 `=` 开头的字符串会自动识别为公式（包装成 `{type:"formula", text:"=..."}` 对象再发送给飞书）。也可以显式传对象。

```bash
feishu sheet write TOKEN "Sheet1!C1:C3" --values '[["=SUM(A1:A10)"],["=A1*2"],["=AVERAGE(B1:B5)"]]'
feishu sheet write TOKEN "Sheet1!C1" --values '[[{"type":"formula","text":"=SUM(A1:A10)"}]]'  # 等价显式写法
```

`write` 返回：`{ spreadsheetToken, updatedRange, updatedRows, updatedColumns, updatedCells }`
`append` 返回：`{ spreadsheetToken, tableRange, updates: { updatedRange, updatedRows, ... } }`

### 查找 / 替换

```bash
feishu sheet find    <url_or_token> <工作表> <关键词> [--match-case] [--whole-cell]
feishu sheet replace <url_or_token> <工作表> --find <文本> --replace-with <文本> [--match-case]
```

```bash
feishu sheet find TOKEN Sheet1 "budget"
feishu sheet find TOKEN Sheet1 "Budget" --match-case
feishu sheet find TOKEN Sheet1 "100" --whole-cell        # 仅精确匹配整个单元格
feishu sheet replace TOKEN Sheet1 --find "旧值" --replace-with "新值"
```

`find` 返回：`{ matchedCount, matchedCells: [{row, col, value}] }`
`replace` 返回：`{ replacedCount }`

### 工作表管理

```bash
feishu sheet rename     <url_or_token> --title "新标题"            # 重命名电子表格
feishu sheet add-sheet  <url_or_token> [--title <名称>] [--index N] # 新增工作表
feishu sheet delete-sheet <url_or_token> <工作表>                  # 删除工作表（不可逆）
feishu sheet copy-sheet <url_or_token> <工作表> [--title <名称>]   # 复制工作表
```

### 行列操作

索引均为 **0-based**。

```bash
feishu sheet add-rows  <url_or_token> <工作表> [--count N]          # 末尾追加 N 行
feishu sheet add-cols  <url_or_token> <工作表> [--count N]          # 末尾追加 N 列
feishu sheet insert-rows <url_or_token> <工作表> --start N [--end N] [--inherit-style BEFORE|AFTER]
feishu sheet insert-cols <url_or_token> <工作表> --start N [--end N] [--inherit-style BEFORE|AFTER]
feishu sheet delete-rows <url_or_token> <工作表> --start N [--end N]  # 删除 [start,end) 范围的行
feishu sheet delete-cols <url_or_token> <工作表> --start N [--end N]
```

`--end` 默认为 `--start + 1`（即操作一行/列）。

### 单元格操作

```bash
# 清除内容（保留样式，V3 API，最多 10 个范围）
feishu sheet clear <url_or_token> <工作表> <range...>

# 合并 / 取消合并
feishu sheet merge   <url_or_token> <range> [--type MERGE_ALL|MERGE_ROWS|MERGE_COLUMNS]
feishu sheet unmerge <url_or_token> <range>

# 设置样式
feishu sheet style <url_or_token> <range> [--bold] [--italic] [--font-size <pt>] \
  [--h-align LEFT|CENTER|RIGHT] [--v-align TOP|MIDDLE|BOTTOM] \
  [--bg-color <#hex>] [--fore-color <#hex>] [--formatter <pattern>] [--clean] \
  [--json <raw_style_json>]
```

`style` 示例：
```bash
feishu sheet style TOKEN "Sheet1!A1:C1" --bold --bg-color "#FFD700" --h-align CENTER
feishu sheet style TOKEN "Sheet1!B2:B50" --formatter "#,##0.00"   # 千分位两位小数
feishu sheet style TOKEN "Sheet1!A1:Z100" --clean                 # 清除样式（必须指定行范围，不支持 A:Z 整列）
feishu sheet style TOKEN "Sheet1!A1:C1" --json '{"borderType":"full","wrapStrategy":1}'  # JSON 直传（覆盖所有样式属性）

# 批量样式（多区域一次调用）
feishu sheet batch-set-style TOKEN --data '[{"ranges":["sheetId!A1:C1"],"style":{"font":{"bold":true}}}]'

# 下拉菜单/数据验证
feishu sheet dropdown set TOKEN Sheet1 --range A1:A100 --values '["高","中","低"]'
feishu sheet dropdown set TOKEN Sheet1 --range B1:B100 --values '["是","否"]' --multi-select
feishu sheet dropdown get TOKEN Sheet1 --range A1:A100
feishu sheet dropdown delete TOKEN Sheet1 --range A1:A100

# 移动行列 / 行列属性
feishu sheet move-dimension TOKEN Sheet1 --dimension ROWS --source-start 2 --source-end 5 --dest 10
feishu sheet update-dimension TOKEN Sheet1 --dimension COLUMNS --start 0 --end 3 --size 200  # 设置列宽
feishu sheet update-dimension TOKEN Sheet1 --dimension ROWS --start 5 --end 10 --visible false  # 隐藏行

# 单元格内图片
feishu sheet write-image TOKEN Sheet1 --range A1 --image-token img_v3_xxx
```

> 批量读写、筛选/保护范围/浮动图片、Windows Git Bash 引号转义：见 `reference/sheet.md`

### 工作表名称 vs sheetId

所有命令的 `<工作表>` 参数均支持**名称**（如 `Sheet1`）或 **sheetId**（如 `abc123`）。CLI 自动解析，优先按 sheetId 匹配，再按名称匹配。

用 `feishu sheet sheets TOKEN` 查看所有工作表的 sheetId 和名称。

### 所需权限

`sheets:spreadsheet`

---

## 知识库（wiki）

知识库是一个组织容器，节点可以是文档、电子表格、多维表格等任意类型。用 `feishu fetch <wiki_url>` 自动识别类型并读取内容，用 `wiki` 命令管理目录结构。

### 浏览

```bash
feishu wiki spaces                                    # 列出所有知识空间
feishu wiki nodes <space_id> [--parent wikcnXXX]      # 列出子节点
feishu wiki get <wiki_url_or_token>                   # 获取节点详情（space_id、obj_token、obj_type 等）
```

`wiki get` 支持完整 URL 或裸 token，两者等效：
```bash
feishu wiki get https://xxx.feishu.cn/wiki/wikcnABC123
feishu wiki get wikcnABC123
```

返回字段：`node_token`、`space_id`、`obj_token`、`obj_type`、`title`、`parent_node_token`、`create_time`

### 创建

```bash
feishu wiki create <space_id> "标题" [--type docx] [--parent wikcnXXX]
```

`wiki create` 支持的类型：`docx`（默认）、`sheet`、`bitable`、`mindnote`、`file`、`doc`、`slides`

如果要创建**带内容**的知识库页面，改用 `feishu docx create --wiki-node`（仅限文档类型）。

### 管理

`wiki move/rename/copy` 需要 `space_id` 和 `node_token`，**必须先调 `wiki get` 获取**：

```bash
# 标准工作流：先获取节点信息
feishu wiki get <wiki_url>
# 返回 { space_id: "7xxx", node_token: "wikcnABC", obj_token: "...", ... }

# 再用 space_id + node_token 执行管理操作
feishu wiki move <space_id> <node_token> --target-space <id> --target-parent wikcnYYY
feishu wiki rename <space_id> <node_token> "新标题"
feishu wiki copy <space_id> <node_token> [--target-space <id>] [--target-parent wikcnYYY] [--title "副本"]
```

### 所需权限

`wiki:wiki` `wiki:wiki:readonly` `wiki:node:read`

---

## 云盘（drive）

```bash
feishu drive list [--folder fldcnXXX]                # 列出文件
feishu drive info <file_token> --type docx           # 文件详情（推荐：--type 可查任意位置）
feishu drive info <file_token> --folder fldcnXXX     # 旧方式：仅限已知父目录（不传则查根目录）
feishu drive mkdir "文件夹名" [--folder fldcnXXX]      # 创建文件夹（不传 --folder 则创建在根目录）
feishu drive move <file_token> --type docx --folder fldcnDEST       # 移动到云盘文件夹
feishu drive move <file_token> --type bitable --wiki-space my_library  # 迁移到个人知识库
feishu drive move <file_token> --type docx --wiki-space 7542XXX --parent wikcnXXX  # 迁移到指定知识空间节点下
feishu drive copy <file_token> --type docx [--name "副本"] [--folder fldcnXXX]  # 复制文件
feishu drive delete <file_token> --type docx
```

`drive copy` 支持所有文件类型（docx, sheet, bitable 等），不支持 folder 类型。不传 `--folder` 时复制到根目录。

`drive move` 的 `--folder` 和 `--wiki-space` 互斥。`--wiki-space` 将文件从云盘迁移到知识库（文件从云盘消失，出现在 wiki 中）。`--parent` 可选，指定 wiki 中的父节点。

### 所需权限

`drive:drive`

---

## 画板（board）

直接操作飞书白板（Whiteboard）。向**文档内嵌**的画板写入 Mermaid 用 `feishu docx create/update`，无需手动操作画板。

```bash
# 导入图表（--syntax: mermaid（默认）/ plantuml）
feishu board import <whiteboard_id> --file diagram.mmd [--syntax plantuml]
feishu board import <whiteboard_id> --content "graph TD\nA-->B" \
  [--diagram-type sequence|class|er|flowchart|state|mindmap|component] [--style board|classic]

# 读取节点 / 创建节点 / 下载为 PNG
feishu board nodes <whiteboard_id>
feishu board create-notes <whiteboard_id> -f nodes.json [--client-token <幂等token>]
feishu board image <whiteboard_id> ./board.png

# 下载也可用 feishu fetch <whiteboard_token> --type whiteboard（返回 base64）
```

> 可创建节点类型、节点字段格式：见 `reference/api-behaviors.md`（Board 章节）

### 所需权限

`board:whiteboard:node:create` · `board:whiteboard:node:read` · `board:whiteboard:node:update` · `board:whiteboard:node:delete`

---

## 日历（calendar）

别名：`cal`。所有时间参数使用 **RFC3339** 格式：`2024-01-21T14:00:00+08:00`。

### 日历操作

```bash
feishu calendar list [--page-size N]                        # 列出所有日历
feishu calendar get --calendar-id <id>                      # 获取日历详情
feishu calendar primary                                     # 获取主日历
```

### 日程 CRUD

```bash
# 创建日程（--calendar-id --summary --start --end 为必填）
feishu calendar create-event \
  --calendar-id <id> --summary "周会" \
  --start "2024-01-21T14:00:00+08:00" --end "2024-01-21T15:00:00+08:00" \
  [--description "议程"] [--location "会议室 A"]

feishu calendar get-event --calendar-id <id> --event-id <eid>

feishu calendar list-events --calendar-id <id> \
  [--start-time "2024-01-01T00:00:00+08:00"] [--end-time "2024-01-31T23:59:59+08:00"] \
  [--page-size N] [--page-token TOKEN]

feishu calendar update-event --calendar-id <id> --event-id <eid> \
  [--summary "新标题"] [--description "新描述"] \
  [--start "..."] [--end "..."] [--location "新地点"]

feishu calendar delete-event --calendar-id <id> --event-id <eid>
```

### 搜索日程

```bash
feishu calendar search-events --calendar-id <id> --query "会议" \
  [--start "2024-01-01T00:00:00+08:00"] [--end "2024-12-31T23:59:59+08:00"] \
  [--page-size N] [--page-token TOKEN]
```

### 回复邀请 / 参与人 / 忙闲

```bash
# 回复邀请（status: accept | decline | tentative）
feishu calendar reply-event --calendar-id <id> --event-id <eid> --status accept

# 参与人管理
# --user-ids 支持姓名、邮箱、open_id，逗号分隔，混合格式均可，CLI 自动解析
feishu calendar add-attendees --calendar-id <id> --event-id <eid> \
  --user-ids "张三"                                    # 姓名（IDM 搜索）
feishu calendar add-attendees --calendar-id <id> --event-id <eid> \
  --user-ids "zhangsan@xiaomi.com,lisi@xiaomi.com"     # 邮箱
feishu calendar add-attendees --calendar-id <id> --event-id <eid> \
  --user-ids "张三,lisi@xiaomi.com,ou_xxx"             # 混合
feishu calendar add-attendees --calendar-id <id> --event-id <eid> \
  [--user-ids uid1,uid2] [--chat-ids oc_xxx]          # 至少提供其中一个
feishu calendar list-attendees --calendar-id <id> --event-id <eid> [--page-size N]

# 忙闲查询（--user-id 同样支持姓名/邮箱/open_id）
feishu calendar freebusy \
  --start "2024-01-21T00:00:00+08:00" --end "2024-01-22T00:00:00+08:00" \
  --user-id <姓名|邮箱|open_id>
```

### 所需权限

`calendar:calendar`（读取 + 创建/修改/删除，含 readonly 全部能力）

---

## 任务（task / tasklist）

使用飞书 Task V2 API。任务 ID 为 UUID 格式（`d300a75f-c56a-4be9-80d6-e47653f6xxxx`）。

### 任务 CRUD

```bash
# 截止时间格式："YYYY-MM-DD" 或 "YYYY-MM-DD HH:mm:ss"
feishu task create --summary "写报告" [--description "详情"] [--due "2024-02-01"] \
  [--members uid1,uid2] [--role assignee|follower] \
  [--tasklist-guid <guid>]

feishu task get <guid>
feishu task list [--completed | --uncompleted] [--page-size N] [--page-token TOKEN]
feishu task update <guid> [--summary "新标题"] [--description "新描述"] [--due "2024-03-01"]
feishu task complete <guid>
feishu task delete <guid>
feishu task add-to-tasklist <guid> --tasklist-guid <tl_guid>   # 将任务加入指定清单
```

### 子任务 / 成员 / 提醒

```bash
# 子任务
feishu task subtask create <guid> --summary "子项"
feishu task subtask list <guid> [--page-size N]

# 成员（角色：assignee 执行者 / follower 关注者，默认 assignee）
feishu task member add    <guid> --members uid1,uid2 [--role assignee]
feishu task member remove <guid> --members uid1,uid2 [--role assignee]

# 提醒（--minutes：提前分钟数，0 = 在截止时间时提醒）
feishu task reminder add    <guid> --minutes 30
feishu task reminder remove <guid> --ids rid1,rid2
```

### 任务清单（tasklist）

任务清单是任务的分组容器，一个任务可属于多个清单。

```bash
feishu tasklist create --name "Sprint 1"
feishu tasklist get <guid>
feishu tasklist list [--page-size N] [--page-token TOKEN]
feishu tasklist delete <guid>
```

### 所需权限

`task:task:read` · `task:task:write` · `task:tasklist:read` · `task:tasklist:write`

---

## 幻灯片（slides）

创建、读取和编辑飞书演示文稿，使用 SML 2.0 XML 协议。支持 `/slides/` URL 和 wiki 节点（`obj_type=slides`）。

### 创建演示文稿

```bash
# 创建空演示文稿
feishu slides create "周报"

# 使用内置模板创建（自动添加一页封面）
feishu slides create "季度汇报" --template title

# 创建并添加多页自定义幻灯片（JSON 数组，每项为 slide XML）
feishu slides create "方案" --slides '["<slide xmlns=\"http://www.larkoffice.com/sml/2.0\"><data>...</data></slide>"]'

# 模板 + 自定义混合（模板封面在前）
feishu slides create "报告" --template title --slides '[...]'
```

返回：`{ presentation_id, revision_id, slides_added, url }`

### 读取

```bash
# 读取完整演示文稿 XML
feishu slides get <url_or_token> [--revision-id N]

# 读取单页 slide XML（需要 slide_id，可从 get 结果的 XML 中提取）
feishu slides get-slide <url_or_token> --slide-id <id> [--revision-id N]
```

### 编辑幻灯片

```bash
# 添加一页（内容来自 --content / --file / --template / stdin）
feishu slides add-slide <url_or_token> --template content
feishu slides add-slide <url_or_token> -c "<slide>...</slide>" [--before <slide_id>]
feishu slides add-slide <url_or_token> -f slide.xml

# 删除一页
feishu slides delete-slide <url_or_token> --slide-id <id>

# 块级替换/插入（精确修改页面元素）
feishu slides replace <url_or_token> --slide-id <id> --parts '<JSON>'
feishu slides replace <url_or_token> --slide-id <id> --parts-file parts.json
```

parts 格式（JSON 数组，最多 200 项）：

| action | 必填字段 | 说明 |
|--------|---------|------|
| `block_replace` | `block_id`, `replacement`（XML） | 替换指定元素，自动注入 `id` 和 `<content/>` |
| `block_insert` | `insertion`（XML）, `insert_before_block_id` | 在指定元素前插入 |

### 图片上传

```bash
# 上传本地图片到演示文稿（单文件最大 20MB）
feishu slides upload-image <url_or_token> --file ./chart.png
feishu slides upload-image <url_or_token> --file https://example.com/img.png
```

返回 `{ file_token }` 用于 `<img src="file_token"/>` 引用。

> ⚠️ slide XML 中 `<img src>` **只能**使用上传后的 `file_token`，不支持外部 HTTP URL。创建时可用 `@./path` 占位符自动上传。

### 内置模板

```bash
# 查看所有模板
feishu slides templates

# 查看指定模板 XML
feishu slides templates --name title
```

| 模板名 | 说明 |
|--------|------|
| `title` | 深色封面页（居中标题+副标题+底部信息） |
| `content` | 浅色内容页（标题+正文+列表） |
| `image-right` | 左字右图封面（暗色渐变） |
| `two-column` | 左图右文分栏（白色背景） |
| `data-cards` | 数据卡片页（横排 3 个 KPI 指标） |
| `three-cards` | 三卡片带图（上图下文） |
| `closing` | 深色结尾页（感谢/CTA） |

### XML 协议要点

- 命名空间：`xmlns="http://www.larkoffice.com/sml/2.0"`
- 画布固定 960×540（16:9）
- `<slide>` 子元素：`<style>?`（背景）、`<data>?`（内容容器）、`<note>?`（备注）
- `<data>` 可包含：`<shape>`（文本框/形状）、`<img>`（图片）、`<line>`（线条）、`<table>`（表格）
- `<shape>` **必须**包含 `<content/>` 子元素（即使为空）
- 渐变色必须用 `rgba()` 格式带百分比 stop：`linear-gradient(135deg,rgba(15,23,42,1) 0%,rgba(56,97,140,1) 100%)`

> 详见 `reference/slides-xml.md`

### 所需权限

`slides:presentation:read` · `slides:presentation:create` · `slides:presentation:update` · `slides:presentation:write_only` · `docs:document.media:upload`

---

## 权限管理（perm）

```bash
feishu perm list <token> --type docx
feishu perm add <token> --type docx --member-id zhangsan@xiaomi.com --perm edit
feishu perm remove <token> --type docx --member-id zhangsan@xiaomi.com
```

`list` 资源类型：`doc` `docx` `sheet` `bitable` `file` `wiki` `mindnote` `minutes` `slides`（不支持 `folder`）
`add`/`remove` 资源类型：以上类型 + `folder`
成员类型：`email`（默认）· `openid` · `userid` · 其他（`unionid` `openchat` `opendepartmentid` `groupid` `wikispaceid`）
权限级别：`view` · `edit` · `full_access`

### 所需权限

`drive:drive`
