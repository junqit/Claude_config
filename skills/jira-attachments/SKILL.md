---
name: jira-attachments
description: Use when you need to read a Jira ticket's full content (summary, description, reproduction steps, firmware/APP versions, 问题时间, comments) and download all its attachments (log zips, images, videos, files) to a local per-issue directory — given a Jira URL or issue key from jira-phone.mioffice.cn or jira.n.xiaomi.com. Triggered by "下载 Jira 附件" / "读 Jira 单" / "拉 Jira 日志" / a jira-phone.mioffice.cn or jira.n.xiaomi.com URL needing full issue info.
---

# Jira Attachments & Issue Info

Read a Jira ticket's full information and download all its attachments (logs, zips, images, videos) to a clean local per-issue directory. Primary path: Jira MCP (`jira_download_attachments`). Fallback when MCP download is broken (session expired / 302 / no download tool / partial): **drive Safari** — Safari holds the live CAS-SSO session, so it fetches every attachment directly, byte-exact, to the per-issue dir. No curl, no bundled cookies, no Charles capture. Solves the real traps: **which MCP server** (two Jira hosts, different tool prefixes), **where MCP bytes actually land** (`jira_download_attachments` returns a summary; bytes land as blobs in the tool-results cache — not in the result, not base64, not CAS HTML), and **the Safari fallback** (drive Safari to blob-download each attachment via its `url` field, then move/verify/extract).

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

## Step 3 — Download attachments (primary: MCP for jira-phone)

### 3.1 Attachment directory rule (mandatory)
All attachments download/extract to **one dir per issue**: `~/Downloads/jira-bugfix-flow/<ISSUE_KEY>/`. Never use `~/Downloads/` root, `/tmp`, the tool-results cache dir, or project dir. Final dir holds only attachment files + extracted products — no blob/CAS-HTML leftovers.

### 3.2 Get attachment manifest
```
mcp__JiraMCP__jira_get_issue(issue_key=<KEY>, fields="attachment")
```
Record each attachment's `filename` + `size` (bytes) + `content_type` **and the `url` field** — `url` is the per-attachment download address `https://<host>/secure/attachment/<id>/<filename>`; the Safari fallback (Step 4) downloads via this `url`, so capture it here.

### 3.3 Call the download tool
```
mkdir -p ~/Downloads/jira-bugfix-flow/<ISSUE_KEY>
mcp__JiraMCP__jira_download_attachments(issue_key=<KEY>)
```
**Critical knowledge — do not misread the result:** the tool returns a *summary* `{"success":true,"downloaded":N,"failed":[]}` — **NOT base64, NOT file contents, NOT CAS HTML**. The real bytes land as an embedded resource that Claude Code auto-saves to the current session's tool-results cache dir, as files named `mcp-JiraMCP-blob-<ts>-<rand>.{zip,bin,mp4,txt,...}`.

**Do NOT use anonymous `curl`/PAT direct to a Jira host** — a CAS gateway sits in front and 302-redirects every unauthenticated request to `cas.mioffice.cn/login`. The returned ~4 KB HTML is the CAS login page, not a download result. When `jira_download_attachments` is broken, use the **Safari fallback (Step 4)**, which rides Safari's live CAS session — not curl.

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
`ls -la ~/Downloads/jira-bugfix-flow/<ISSUE_KEY>/` — each file's size must match the Jira metadata. If no size-matched blob was found for an attachment, report THAT attachment as missing (MCP download failed → go to Step 4) — do not silently skip, do not fabricate logs, do not read zip bytes as `.log`.

### jira.n.xiaomi.com (old-mi-jira)
No `jira_download_attachments` — there is no MCP download tool for this host, so **always** use the **Step 4 Safari fallback** to get attachments (works as long as Safari is logged into `jira.n.xiaomi.com`). Read issue info via `jira_issue_get_tool` when its session is alive; it returns 302 (`connected:false`) when expired — in that case get the manifest via Safari `do JavaScript` fetch of `https://jira.n.xiaomi.com/rest/api/2/issue/<KEY>?fields=attachment` (same-origin, session cookies). Do NOT tell the user attachments "must be placed manually".

## Step 4 — Safari fallback (when `jira_download_attachments` fails)

**Rule: as long as `jira_download_attachments` fails to download, drive Safari to fetch every attachment.** Safari holds the live CAS-SSO session, so it downloads where curl/MCP can't. No bundled cookies, no Charles `.chlz`, no param refresh.

Triggers:
- `mcp__JiraMCP__jira_download_attachments` errors / "session expired" / 302 / "not found" / `failed` non-empty / a size-matched blob is missing (partial failure);
- host is `jira.n.xiaomi.com` (old-mi-jira has **no** download tool — go straight to Safari);
- image/video attachments must be saved as real files (MCP `jira_get_issue_images` returns inline vision content, not a file).

If `jira_download_attachments` succeeds and every attachment is on disk with matching size, **skip Step 4**.

**Prereq:** Safari logged into the target host (CAS SSO complete). If a Safari navigation yields no file (CAS-redirect), tell the user to open `https://<host>/browse/<KEY>` in Safari and complete login first.

### 4.0 Get the manifest (filename + size + content_type + `url`)
Get it via MCP read (read works even when download is broken):
```
mcp__JiraMCP__jira_get_issue(issue_key=<KEY>, fields="attachment")   # jira-phone
mcp__old-mi-jira__jira_issue_get_tool(issue_key=<KEY>)                 # jira.n.xiaomi.com (if alive)
```
If MCP read is also dead (e.g. old-mi-jira 302), get the manifest via the Step 4.2 `do JavaScript` pattern, fetching `https://<host>/rest/api/2/issue/<KEY>?fields=attachment` and `JSON.stringify`-ing the result.

For each attachment record: `filename`, `size` (bytes), `content_type`, `url`.

### 4.1 Pick the download method
Safari downloads binary types on navigation, but **previews inline** for video/audio (no file saved). Two methods:

- **`do JavaScript` blob fetch (4.2)** — uniform, works for ALL types incl. video. Fetches the `url` as a blob (session cookies via `credentials:'include'`, same-origin) and triggers a download with the original filename → byte-exact, no inline preview. **Recommended for every attachment.**
- **Navigation `open location <url>`** — simpler, no JS — but only downloads binary types (zip/tar.gz/log/pdf/images). ⚠ Safari's "Open safe files after downloading" may auto-unzip `.zip` and move the original to `~/.Trash` (recover by byte size, 4.3); video/audio preview inline (use 4.2 instead).

### 4.2 do-JS blob download (the verified uniform method)
Requires Safari's "Allow JavaScript from Apple Events". Enable it, then restore after (the pref is **off/absent by default**). Open **one** new tab — if Safari is already open, **add a tab to the existing window** (leave the user's tabs untouched); if Safari has no window, make one. Drive all downloads inside that one tab, then close it in 4.4.

Build `ITEMS_JSON` = a JSON array of `{"u": <url-field>, "f": <filename>}` per attachment from the manifest (4.0). Then one `do JavaScript` blob-fetches every attachment sequentially (2 s stagger so the browser saves each):
```bash
# enable (record current first if you want to restore to a non-default value)
defaults write com.apple.Safari AllowJavaScriptFromAppleEvents -bool true
# ITEMS_JSON e.g.: [{"u":"https://<HOST>/secure/attachment/<id>/<filename>","f":"<filename>"}, ...]
# use the `url` field, NOT /rest/api/2/attachment/content/<id> (404s)
osascript <<'OASCRIPT'
tell application "Safari"
  activate
  if (count of windows) = 0 then
    make new document
    set theTab to tab 1 of window 1
  else
    tell window 1
      set theTab to make new tab
    end tell
  end if
  set URL of theTab to "https://<HOST>/browse/<KEY>"
  delay 6
  do JavaScript "var items=<ITEMS_JSON>;(function next(i){if(i>=items.length)return;fetch(items[i].u,{credentials:'include'}).then(function(r){return r.blob();}).then(function(b){var a=document.createElement('a');a.href=URL.createObjectURL(b);a.download=items[i].f;document.body.appendChild(a);a.click();setTimeout(function(){next(i+1);},2000);});})(0);0" in theTab
end tell
OASCRIPT
# after 4.3 has confirmed all files landed:
defaults delete com.apple.Safari AllowJavaScriptFromAppleEvents 2>/dev/null
```
- One tab, one `do JavaScript`; keep the tab open while 4.3 polls, then close it in 4.4.
- The fetch is **same-origin** (the tab is on `<host>`), `credentials:'include'` sends the CAS/Jira session cookies, the server serves the real bytes (the same GET the browser does to preview/download), and the blob+`anchor.click()` forces a save with the chosen filename to `~/Downloads/`.

⚠ **Use the `url` field** (`/secure/attachment/<id>/<filename>`), **NOT** `/rest/api/2/attachment/content/<id>` — the content endpoint returns `HTTP 404` (an XML `<status><status-code>404</status-code>…</status>` body, ~139 B) for some attachments. The `url` field always serves the bytes.

### 4.3 Poll + collect into the per-issue dir
Safari saves to `~/Downloads/`. Poll for each file by **exact byte size** (handles Safari renaming and confirms completeness — a partial download won't match):
```bash
DEST=~/Downloads/jira-bugfix-flow/<KEY>
# for each expected (filename, size):
for i in $(seq 1 90); do
  f=$(find ~/Downloads ~/.Trash -maxdepth 2 -type f -size <SIZE>c 2>/dev/null | head -1)
  [ -n "$f" ] && { mv "$f" "$DEST/<FILENAME>"; break; }
  sleep 2
done
```
- `.zip` auto-unzipped by Safari → original moved to `~/.Trash`; the poll checks `~/.Trash` too. Remove the auto-extract folder Safari leaves in `~/Downloads` (`rm -rf ~/Downloads/<zip-basename-without-.zip>`).
- Verify each file: `wc -c "$DEST/<FILENAME>"` == manifest `size`. A ~139-B file ⇒ you hit the content-endpoint 404 — re-download that one via its `url` field (4.2).

### 4.4 Extract + close the tab you added
- `unzip -o` zips (incl. nested) into the per-issue dir; never read zip bytes as `.log`.
- Close **the one tab you added in 4.2** (matched by URL containing `browse/<KEY>`) — leave the user's other tabs/windows untouched:
```bash
osascript -e 'tell application "Safari"
  set toClose to {}
  repeat with w in windows
    repeat with t in tabs of w
      try
        set u to URL of t
        if u contains "browse/<KEY>" then set end of toClose to t
      end try
    end repeat
  end repeat
  repeat with t in toClose
    try
      close t
    end try
  end repeat
end tell'
```

## Output to caller
Return a structured summary: issue key + host + full issue fields (summary/description/steps/versions/问题时间/comments) + attachment list (filename, size, content_type, local path) + path to the per-issue directory. Keep raw log analysis out of scope — this skill fetches info + files only; analysis is the caller's job.

## Common Mistakes
| Mistake | Reality |
|---|---|
| Anonymous `curl`/PAT direct to a Jira host to download attachment | CAS 302 → login HTML. Use the Safari fallback (Step 4) — Safari rides its live CAS session. |
| Download via `/rest/api/2/attachment/content/<id>` | Can return `HTTP 404` (XML ~139 B) for some attachments. Use the **`url` field** (`/secure/attachment/<id>/<filename>`) — it always serves the bytes. |
| Safari previews a video inline (no file lands) | `open location` only saves binary types. Use the `do JavaScript` blob fetch (4.2) to force-save video/audio. |
| `do JavaScript` errors: "enable Allow JavaScript from Apple Events" | The pref is off by default. `defaults write com.apple.Safari AllowJavaScriptFromAppleEvents -bool true` before, `defaults delete` after. |
| Safari auto-unzips a downloaded `.zip` (original moved to Trash) | Poll `~/.Trash` too by byte size; recover the `.zip`; remove the auto-extract folder in `~/Downloads`. |
| Expect `jira_download_attachments` to return file bytes/base64 | It returns a summary; bytes are in tool-results `mcp-JiraMCP-blob-*`. |
| Read the ~4 KB CAS HTML as "download failed" (MCP path) | It's the CAS interception page; MCP backend uses intranet. (If Safari navigation yields no file, Safari isn't logged in — log in first.) |
| Leave attachments in tool-results cache (MCP path) | `mv` to `~/Downloads/jira-bugfix-flow/<ISSUE_KEY>/`, then delete blobs. |
| Multiple issues share one directory | One subdirectory per issue key. |
| Read zip/blob bytes as `.log` text | `unzip` first, read extracted `.log`. |
| Treat Safari fallback as inferior | Verified MORE complete than MCP: saves video/image attachments as real files (MCP `jira_get_issue_images` only returns inline vision content). Use it whenever `jira_download_attachments` fails OR images/video are missing. |

## Real example — Q95GTK-11303 (MCP success)
URL `https://jira-phone.mioffice.cn/browse/Q95GTK-11303` → host `jira-phone.mioffice.cn` → JiraMCP.
- `jira_get_issue(fields="*all")` → summary/description/steps/问题时间 2026-08-04 14:39/APP 9.9.9(591)/固件 VOS4.0.10.0/comments.
- `jira_get_issue(fields="attachment")` → 2 attachments (archive + video).
- `jira_download_attachments` → `{"success":true,"downloaded":2,"failed":[]}`.
- tool-results blobs matched by size → `mv` to `~/Downloads/jira-bugfix-flow/Q95GTK-11303/`; `unzip` → `.log` files; delete blobs.
- Verify sizes match metadata. ✅

## Real example — NEWMIWEAR-5679 (Safari fallback)

`jira_download_attachments` → `MCP server "JiraMCP" session expired` (read API `jira_get_issue` still worked — so it was the download-side auth that was stale, not the PAT).
- Manifest via `jira_get_issue(fields="attachment")` → 2 attachments: `miWearDebug_log(11).zip` (10493004 B) + `飞书20260817-105934.MP4` (5212968 B); captured both `url` fields.
- Tried `/rest/api/2/attachment/content/<id>` first → returned `HTTP 404` (XML ~139 B). **Switched to the `url` field** (`/secure/attachment/<id>/<filename>`).
- Enabled `AllowJavaScriptFromAppleEvents` via `defaults write`; opened a Safari tab on `https://jira-phone.mioffice.cn/browse/NEWMIWEAR-5679` (same-origin + session); `do JavaScript` blob-fetched each `url` with `credentials:'include'` → `anchor.download=<filename>` → both files byte-exact in `~/Downloads/`.
- `.zip` was also auto-unzipped by Safari (original moved to `~/.Trash`) — recovered from `~/.Trash` by byte size; removed the auto-extract folder.
- Moved both into `~/Downloads/jira-bugfix-flow/NEWMIWEAR-5679/` with original filenames; `wc -c` == manifest sizes (10493004 / 5212968) ✅; `unzip` (incl. nested zips); closed the Safari tab; `defaults delete AllowJavaScriptFromAppleEvents`. Dir ready for analysis. ✅

Lesson: the content endpoint 404s on some attachments — always use the `url` field. And `do JavaScript` blob fetch is the one method that reliably saves video (which Safari otherwise previews inline).
