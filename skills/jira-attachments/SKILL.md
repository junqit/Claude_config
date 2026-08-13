---
name: jira-attachments
description: Use when you need to read a Jira ticket's full content (summary, description, reproduction steps, firmware/APP versions, 问题时间, comments) and download all its attachments (log zips, images, videos, files) to a local per-issue directory — given a Jira URL or issue key from jira-phone.mioffice.cn or jira.n.xiaomi.com. Triggered by "下载 Jira 附件" / "读 Jira 单" / "拉 Jira 日志" / a jira-phone.mioffice.cn or jira.n.xiaomi.com URL needing full issue info.
---

# Jira Attachments & Issue Info

Read a Jira ticket's full information and download all its attachments (logs, zips, images, videos) to a clean local per-issue directory, via Jira MCP. Solves the two real traps: **which MCP server** (two Jira hosts, different tool prefixes) and **where attachments actually land** (`jira_download_attachments` returns a summary, bytes land as blobs in a cache dir — not in the tool result, not as base64, not as CAS HTML).

## When to Use
- Given a Jira URL or issue key, need the ticket's full content + attachments locally.
- Need to download Jira log zips / images / videos for analysis.
- Another skill/agent needs Jira issue context fed into it.

**When NOT to use:** you only need to *write* a comment or transition status (use the Jira MCP tools directly). This skill is for *reading* issue info + *downloading* attachments.

## Step 1 — Parse issue key + pick MCP server by host

The Jira host decides the MCP server (different tool prefixes).

| Jira host | MCP server | prefix | attachment download? |
|---|---|---|---|
| `jira-phone.mioffice.cn` | JiraMCP | `mcp__JiraMCP__` | ✅ `jira_download_attachments`, `jira_get_issue_images` |
| `jira.n.xiaomi.com` | old-mi-jira | `mcp__old-mi-jira__` | ❌ no attachment download (read-only `jira_issue_get_tool`) |

- Extract the issue key from the URL (e.g. `Q95GTK-11303`).
- If the chosen server returns 302/redirect, fall back to the other server.
- Use the SAME server for all reads in one task.

## Step 2 — Read full issue info

```
mcp__JiraMCP__jira_get_issue(issue_key=<KEY>, fields="*all", comment_limit=10)
```
Capture: summary, description, steps, 预期结果/实际结果, 固件/APP 版本, **问题时间** (the timestamp the bug occurred), status, assignee/reporter, labels, components, comments.

For `jira.n.xiaomi.com`: `mcp__old-mi-jira__jira_issue_get_tool(issue_key=<KEY>)`.

## Step 3 — Download attachments (jira-phone.mioffice.cn only)

### 3.1 Attachment directory rule (mandatory)
All attachments download/extract to **one dir per issue**: `~/Downloads/jira-bugfix-flow/<ISSUE_KEY>/`. Never use `~/Downloads/` root, `/tmp`, the tool-results cache dir, or project dir. Final dir holds only attachment files + extracted products — no blob/CAS-HTML leftovers.

### 3.2 Get attachment manifest
```
mcp__JiraMCP__jira_get_issue(issue_key=<KEY>, fields="attachment")
```
Record each attachment's `filename` + `size` (bytes) + `content_type`.

### 3.3 Call the download tool
```
mkdir -p ~/Downloads/jira-bugfix-flow/<ISSUE_KEY>
mcp__JiraMCP__jira_download_attachments(issue_key=<KEY>)
```
**Critical knowledge — do not misread the result:** the tool returns a *summary* `{"success":true,"downloaded":N,"failed":[]}` — **NOT base64, NOT file contents, NOT CAS HTML**. The real bytes land as an embedded resource that Claude Code auto-saves to the current session's tool-results cache dir, as files named `mcp-JiraMCP-blob-<ts>-<rand>.{zip,bin,mp4,txt,...}`.

**NEVER substitute `curl`/PAT direct connection to jira-phone.mioffice.cn.** A CAS gateway sits in front and 302-redirects every unauthenticated request (including REST `/issue/` and both attachment endpoints `/secure/attachment/<id>/` and `/rest/api/2/attachment/content/<id>`) to `cas.mioffice.cn/login`. The returned 4828-byte HTML is the CAS login page — **it is an interception page, not a download result, not an MCP failure**. Mistaking it for "download failed" is the historical misjudgment root cause; do not repeat it. The MCP server downloads via its intranet backend and always succeeds when it returns `success:true`.

### 3.4 Archive blobs from tool-results (transparent to the user)
Match each attachment to its blob by exact byte `size`, then `mv` + rename to the original filename:
```bash
# locate current session's tool-results dir (most recently modified)
TR=$(find ~/.claude/projects -maxdepth 3 -type d -name tool-results \
     -exec stat -f '%m %N' {} \; | sort -rn | head -1 | cut -d' ' -f2-)
# for each attachment (filename, size):
#   blob=$(find "$TR" -maxdepth 1 -type f -name 'mcp-JiraMCP-blob-*' -size ${SIZE}c | head -1)
#   mv "$blob" ~/Downloads/jira-bugfix-flow/<ISSUE_KEY>/<FILENAME>
```

### 3.5 Extract + clean up
- `.zip` → `unzip -o ~/Downloads/jira-bugfix-flow/<ISSUE_KEY>/<zip> -d ~/Downloads/jira-bugfix-flow/<ISSUE_KEY>/` → read extracted `.log` text. **Never base64-decode; never read zip/blob bytes as log text.**
- Image attachments → `mcp__JiraMCP__jira_get_issue_images(issue_key=<KEY>)` (saved into the same dir).
- Clean cache: `find "$TR" -maxdepth 1 -name 'mcp-JiraMCP-blob-*' -delete`.

### 3.6 Verify
`ls -la ~/Downloads/jira-bugfix-flow/<ISSUE_KEY>/` — each file's size must match the Jira metadata. If no size-matched blob was found for an attachment, report THAT attachment as missing (MCP download failed) — do not silently skip, do not fabricate logs, do not read zip bytes as `.log`.

### jira.n.xiaomi.com (old-mi-jira)
No `jira_download_attachments`. Read issue info via `jira_issue_get_tool`; report that attachments must be placed manually into `~/Downloads/jira-bugfix-flow/<ISSUE_KEY>/` before continuing.

## Output to caller
Return a structured summary: issue key + host + full issue fields (summary/description/steps/versions/问题时间/comments) + attachment list (filename, size, content_type, local path) + path to the per-issue directory. Keep raw log analysis out of scope — this skill fetches info + files only; analysis is the caller's job.

## Common Mistakes
| Mistake | Reality |
|---|---|
| `curl`/PAT direct to jira-phone to download attachment | CAS 302 → login HTML. Use `jira_download_attachments` MCP. Always. |
| Expect `jira_download_attachments` to return file bytes/base64 | It returns a summary; bytes are in tool-results `mcp-JiraMCP-blob-*`. |
| Read the 4828-byte CAS HTML as "download failed" | It's the CAS interception page, not an MCP result. MCP backend uses intranet. |
| Leave attachments in tool-results cache | `mv` to `~/Downloads/jira-bugfix-flow/<ISSUE_KEY>/`, then `delete` blobs. |
| Multiple issues share one directory | One subdirectory per issue key. |
| Read zip/blob bytes as `.log` text | `unzip` first, read extracted `.log`. |

## Real example — Q95GTK-11303
URL `https://jira-phone.mioffice.cn/browse/Q95GTK-11303` → host `jira-phone.mioffice.cn` → JiraMCP.
- `jira_get_issue(fields="*all")` → summary/description/steps/问题时间 2026-08-04 14:39/APP 9.9.9(591)/固件 VOS4.0.10.0/comments.
- `jira_get_issue(fields="attachment")` → `MiGlasses_iOS_Log.zip` (5118210, application/zip) + `飞书20260804-152042.qt` (2495083, video/quicktime).
- `jira_download_attachments` → `{"success":true,"downloaded":2,"failed":[]}`.
- tool-results blobs: `mcp-JiraMCP-blob-*-w81c91.zip` (5118210c) + `mcp-JiraMCP-blob-*-ymk8wv.bin` (2495083c), matched by size.
- `mv` → `~/Downloads/jira-bugfix-flow/Q95GTK-11303/MiGlasses_iOS_Log.zip` + `飞书20260804-152042.qt`; `unzip` → 7 `.log` files; delete blobs.
- Verify sizes match metadata. ✅
