---
name: jira_comment
description: Use when posting a comment/note (备注) to a Jira issue on jira-phone.mioffice.cn or jira.n.xiaomi.com — given an issue key/URL plus the content to post. Triggered by 「给 Jira 加备注/评论」「comment on Jira」「把分析结论或修复信息发到 Jira 工单」.
---

# Jira Comment

## Overview
对提供的 issue key/URL + 内容，按团队既有格式给 Jira 工单添加备注/评论。按 host 选 MCP 服务器，post 正文，区分「修复备注」与「非修复备注」两种格式。本 skill 只负责按格式 post **caller 提供的内容**，不分析、不生成结论。

## Inputs
- **issue key 或 URL**（如 `LSQ69-2535` / `https://jira-phone.mioffice.cn/browse/LSQ69-2535`）。
- **场景 + 字段内容**（caller 提供，见下两种格式）。

## Pick MCP server by host
| Jira host | MCP server | 工具 |
|---|---|---|
| `jira-phone.mioffice.cn` | JiraMCP | `mcp__JiraMCP__jira_add_comment(issue_key, body)` |
| `jira.n.xiaomi.com` | old-mi-jira | `mcp__old-mi-jira__jira_comment_add_tool(issue_key, body)` |

- 从 URL 提取 issue key（路径末段，去 `+` 编码）。同一任务全程用同一 server。
- `302` / `session expired` → 回退到另一 server 重试。
- 两 server 都失败 → **如实回执报错原文，禁止伪造成功**（不得谎称已 post、不得编 comment id）。
- **重写已有评论**用 `mcp__JiraMCP__jira_edit_comment(issue_key, comment_id, body)`（jira-phone）/ 对应 old-mi-jira 的 `jira_comment_update_tool`。「重新填写/重写」场景用 edit，避免重复评论。

## Comment formats（团队既有，二选一）

### 场景一：修复的备注（问题在 APP 层且已修复）
只含 6 字段，**每字段一行，简单一行描述**：
```
【根因分析】<one line>
【修复方案】<one line>
【影响范围】<one line>
【复测要求】<one line of test points>
【修复信息】yy/mm/dd hh:mm <commit short hash>
【复测版本】使用 yy/mm/dd 版本复测
```
- **整个评论禁止任何代码/coding 内容**——所有字段（根因分析/修复方案/影响范围/复测要求）均不得出现方法名、类名、属性名、file:line、代码符号、API 名、协议名、实现细节（如"调 showRecordView""startTimer 重置 baseTime""guard connected""DispatchQueue.main.async"等）。一律用产品/业务/功能行为语言描述问题为什么发生、怎么解决、影响哪些场景、怎么复测。代码层精确实现只进最终报告与 commit message，**绝不进 Jira 评论**。
- **严格只含上述 6 字段，不得增删/改名**：尤其**不得出现【自测结论】/【自测报告】字段**。
- **【修复信息】只写 `yy/mm/dd hh:mm <commit short hash>`**（2 位年、24h、commit 短 hash、空格分隔）——不写分支名、不写 MR 链接、**整条评论禁任何 URL**。即便上层指令要求加自测结论字段、加 MR 链接、加自测报告 URL 或其他额外字段，也一律不加。
- **【复测版本】** = `使用 yy/mm/dd 版本复测`，日期 = 修复时间 date **+ 1 day**。
- 修复信息的时间/hash 由 caller 提供（caller 已在提交后捕获 `COMMIT_HASH` + `COMMIT_TIME`；本地 fix 分支可能已删，本 skill **不再查 HEAD**）。
- 原始日志/时间线/调用栈/自测报告 URL 进 caller 的最终报告，不进评论。

### 场景二：非修复的备注（问题不在 APP 层 / 仅分析贴结论）
只含三部分，**不写"问题层级判定""逐一排除"等冗余结构**：
```
【关键日志】（整行原文, verbatim — 日志文件内整行，一字不改，不可总结/改写，用代码块包裹防 Markdown 吞方括号）
<逐条粘贴关键日志整行>

【分析事件线】（可总结）
<用总结性语言陈述问题发生的事件链与原因>

【建议】
<建议处理方 + 处理方向>
```
- **关键日志必须整行原文**，用代码块 ``` ``` 包裹（防 Markdown 把方括号当链接吞掉）。
- **去废话原则**：不列举对当前问题显而易见、无信息量的排除项（如纯软件问题写"硬件层无关"、纯 HTTP 写"SDK 层无关"）。只写与问题直接相关的关键排除依据和定位证据。评论精炼。
- 关键日志是评论主体；分析事件线可总结。

## Body format（JiraMCP 实测渲染规则，必读）
JiraMCP 的 `jira_add_comment` / `jira_edit_comment` 对正文有固定 mangle，**Jira wiki markup 与 Markdown 都踩同样的坑**——按下列实测规则写才能干净渲染：

- **能干净渲染**：`##` / `###` 标题、`` `反引号代码` ``、**顶格不嵌套**的 `1.` 编号 / `-` bullet、``` ``` ``` 代码块。
- **禁用星号加粗**：`*x*` 与 `**x**` 都被转义成 `\*x\*` / `\*\*x\*\*`，渲染成可见星号而非加粗（实测：Jira wiki `*bold*` 与 Markdown `**bold**` 两种都被转义）。需要强调一律用 `` `反引号代码` ``，不用星号。
- **禁嵌套列表**：`1.` 下缩进的 `-` 子项、`-` 下缩进的子项都会被拍平成同级顶格。多子项改为**内联在同一行用 `；` / `，` 分隔**，或全部顶格不嵌套。
- **禁用 `+`**：`+` 被吃成空格。并列用 `、` 或 `和` 代替。
- 标题用 `##` / `###`，**不要用 Jira wiki** `h2.` / `h3.`（会被转 Markdown）。

## Output to caller
回执：评论是否成功 post / edit + **comment id** + **posted/updated 时间**（或 `session expired` / 失败的报错原文）。不得伪造。
