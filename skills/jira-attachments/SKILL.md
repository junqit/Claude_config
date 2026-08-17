---
name: jira-attachments
description: Use when you need to read a Jira ticket's full content (summary, description, reproduction steps, firmware/APP versions, 问题时间, comments) and download all its attachments (log zips, images, videos, files) to a local per-issue directory — given a Jira URL or issue key from jira-phone.mioffice.cn or jira.n.xiaomi.com. Triggered by "下载 Jira 附件" / "读 Jira 单" / "拉 Jira 日志" / a jira-phone.mioffice.cn or jira.n.xiaomi.com URL needing full issue info.
---

# Jira Attachments & Issue Info

Read a Jira ticket's full information and download all its attachments (logs, zips, images, videos) to a clean local per-issue directory, via Jira MCP — with a verified **curl + bundled-params fallback (Step 4)** that fires whenever `jira_download_attachments` fails (errors, 302, host has no download tool, or image attachments that MCP can't persist as files). Solves the real traps: **which MCP server** (two Jira hosts, different tool prefixes), **where attachment bytes actually land** (`jira_download_attachments` returns a summary, bytes land as blobs in a cache dir — not in the tool result, not as base64, not as CAS HTML), and **the curl fallback** (anonymous curl fails CAS; curl with the per-host params file bundled in this skill succeeds — params are live session cookies that expire and must be refreshed).

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

**NEVER substitute *anonymous* `curl`/PAT direct connection to jira-phone.mioffice.cn.** A CAS gateway sits in front and 302-redirects every unauthenticated request (including REST `/issue/` and both attachment endpoints `/secure/attachment/<id>/` and `/rest/api/2/attachment/content/<id>`) to `cas.mioffice.cn/login`. The returned 4828-byte HTML is the CAS login page — **it is an interception page, not a download result, not an MCP failure**. Mistaking it for "download failed" is the historical misjudgment root cause; do not repeat it. The MCP server downloads via its intranet backend and always succeeds when it returns `success:true`.

**However, `curl` WITH a captured session Cookie header is the verified fallback when MCP can't download** (see Step 4). Anonymous curl fails; cookie-authenticated curl succeeds. The two are different — do not conflate them.

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
No `jira_download_attachments` — there is no MCP download tool for this host, so **always** use the **Step 4 curl fallback with the bundled `params/jira-n-xiaomi.headers`** to get attachments. Read issue info via `jira_issue_get_tool` when its session is alive; it returns 302 (`connected:false`) when expired — in that case Step 4's params also cover reading the issue via curl (`/rest/api/2/issue/<KEY>`). Do NOT tell the user attachments "must be placed manually".

## Step 4 — curl fallback (when `jira_download_attachments` fails)

**Rule: as long as `jira_download_attachments` fails to download, use curl + the bundled params.** The auth parameters are already embedded in this skill (one file per host) — **no `.chlz` needed at download time.** Triggers:
- `mcp__JiraMCP__jira_download_attachments` errors / returns 302 / "not found" / `failed` non-empty / a size-matched blob is missing (partial failure);
- host is `jira.n.xiaomi.com` (old-mi-jira has **no** download tool — go straight to curl; there is no `jira_download_attachments` to try);
- image attachments must be saved as real files (MCP `jira_get_issue_images` returns inline vision content, not a file).

If `jira_download_attachments` succeeds and every attachment is on disk with matching size, **skip Step 4** — do not curl redundantly.

**Verified:** curl + the bundled params downloads **ALL** attachments (zip / tar.gz / image / video / log), byte-exact — including images MCP can't persist. After download + verify + extract, the per-issue dir is ready for the next step (log analysis, etc.).

### Bundled params (per host) — ⚠ live session cookies, will expire
The auth header for each host is stored next to this skill (curl `-H @file` format), captured from a browser session. They are **live session cookies** (`JSESSIONID`, `atlassian.xsrf.token`, `_aegis_cas` CAS SSO token, …) — they **expire** (hours to days). When they stop working, refresh them (4.3); the `.chlz` need not be kept afterward — only the regenerated params file persists.

| Target host | Params file (under this skill's base dir) |
|---|---|
| `jira-phone.mioffice.cn` | `params/jira-phone.headers` |
| `jira.n.xiaomi.com` | `params/jira-n-xiaomi.headers` |

**Two domains → two different param sets, NOT interchangeable.** Cookies are host-scoped: jira-phone params → jira.n.xiaomi.com returns the CAS login page (~2 KB HTML, final URL `cas.mioffice.cn/login?…followup=<host>…`). Always use the file matching the target host.

### 4.1 Download with bundled params (no .chlz needed)
```python
import json, os, subprocess, zipfile, tarfile
KEY="<ISSUE_KEY>"; HOST="<jira-phone.mioffice.cn or jira.n.xiaomi.com>"
BASE="<this skill's base dir>"   # provided at skill load
PARAMS=f"{BASE}/params/" + ("jira-phone.headers" if HOST=="jira-phone.mioffice.cn" else "jira-n-xiaomi.headers")
DEST=os.path.expanduser(f"~/Downloads/jira-bugfix-flow/{KEY}"); os.makedirs(DEST, exist_ok=True)
# manifest (lists every attachment without MCP)
subprocess.run(["curl","-sS","--compressed","-H",f"@{PARAMS}",
    f"https://{HOST}/rest/api/2/issue/{KEY}?fields=attachment",
    "-o",f"{DEST}/_manifest.json"], check=True)
d=json.load(open(f"{DEST}/_manifest.json"))
if "errorMessages" in d or "fields" not in d:
    raise SystemExit(f"params likely EXPIRED or wrong host: {d}\n→ refresh per 4.3")
atts=d["fields"]["attachment"]
# download every attachment, verify exact byte size
for a in atts:
    out=f"{DEST}/{a['filename']}"
    subprocess.run(["curl","-sS","--compressed","-H",f"@{PARAMS}",
        "-o",out,"-w","%{http_code}|%{size_download}|%{url_effective}",a["content"]], check=True)
    got=os.path.getsize(out)
    assert got==a["size"], f"size mismatch {a['filename']}: exp {a['size']} got {got}"
# extract .zip and .tar.gz (tar.gz may contain absolute paths like /data/... — sanitize)
def safe(tar):
    for m in tar.getmembers():
        p=m.name.lstrip("/").lstrip("\\")
        if ".." in p.split("/"): continue
        m.name=p; yield m
for fn in sorted(os.listdir(DEST)):
    p=f"{DEST}/{fn}"; low=fn.lower()
    if low.endswith(".zip"): zipfile.ZipFile(p).extractall(DEST)
    elif low.endswith((".tar.gz",".tgz")):
        with tarfile.open(p,"r:gz") as t: t.extractall(DEST, members=list(safe(t)))
```

### 4.2 Verify + proceed to next step
- Each file's `os.path.getsize` MUST equal the manifest `size`. All-match ⇒ attachments complete and trustworthy; never fabricate.
- **Expired-params signature:** manifest curl returns `errorMessages`/non-JSON, OR a download's final URL is `cas.mioffice.cn/login?…followup=<host>…` with ~2 KB HTML. ⇒ refresh per 4.3.
- **Wrong-host signature:** same CAS login page but params work for the other host ⇒ you used the wrong params file; re-pick per the table above.
- Once verified + extracted, the per-issue dir is ready for the next step (read `.log` text, analyze, feed another skill/agent). Do not block on MCP — proceed.
- Keep `_manifest.json` as a record (or delete for a clean dir).

### 4.3 Refresh params when they expire
When 4.2 reports the expired-params signature, regenerate the params file from a fresh Charles capture of **THAT host** (the `.chlz` is only needed during refresh, then can be deleted):
1. Ask the user to capture: Charles Recording → open `https://<host>/browse/<KEY>` in a browser, log in (let CAS SSO complete), click each attachment → File → Save Session → `.chlz`. Confirm the file exists on disk.
2. Extract the Cookie header from the `.chlz` and **overwrite** the params file, then verify before trusting:
```python
import json, glob, os, subprocess
HOST="<host>"; CHLZ="<path-to-.chlz>"; BASE="<this skill's base dir>"; KEY="<ISSUE_KEY>"
WORK=f"/tmp/chls_refresh"; os.makedirs(WORK, exist_ok=True)
subprocess.run(["unzip","-o","-q",CHLZ,"-d",WORK], check=True)   # .chlz is a zip; may have no extension
def load(p): return json.load(open(p))
pick=None
for f in glob.glob(f"{WORK}/*-meta.json"):
    m=load(f)
    if m.get("host")==HOST and str(m.get("path","")).startswith("/secure/attachment/"): pick=f; break
if not pick:
    for f in glob.glob(f"{WORK}/*-meta.json"):
        if load(f).get("host")==HOST: pick=f; break
assert pick, f"no {HOST} traffic in this .chlz — wrong host"
m=load(pick); hdrs=m["request"]["header"]["headers"]
cookies=[h["value"] for h in hdrs if h.get("name")=="cookie"]   # Charles stores each cookie as its own header
out=[(h["name"],h["value"]) for h in hdrs
     if not h.get("name","").startswith(":")
     and h.get("name") not in ("cookie","accept-encoding","content-length")]
if cookies: out.append(("Cookie","; ".join(cookies)))            # join into one Cookie header
PARAMS=f"{BASE}/params/" + ("jira-phone.headers" if HOST=="jira-phone.mioffice.cn" else "jira-n-xiaomi.headers")
open(PARAMS,"w").write("".join(f"{n}: {v}\n" for n,v in out))
subprocess.run(["curl","-sS","--compressed","-H",f"@{PARAMS}",
    f"https://{HOST}/rest/api/2/issue/{KEY}?fields=attachment","-o",f"{WORK}/check.json"], check=True)
print("refreshed + verified ✅" if "fields" in load(f"{WORK}/check.json") else "STILL FAILS — re-capture")
```

## Output to caller
Return a structured summary: issue key + host + full issue fields (summary/description/steps/versions/问题时间/comments) + attachment list (filename, size, content_type, local path) + path to the per-issue directory. Keep raw log analysis out of scope — this skill fetches info + files only; analysis is the caller's job.

## Common Mistakes
| Mistake | Reality |
|---|---|
| *Anonymous* `curl`/PAT direct to a Jira host to download attachment | CAS 302 → login HTML. But `curl -H @params/<host>.headers` (Step 4) works. Anonymous ≠ bundled-params-authenticated. |
| Use the wrong host's params file (jira-phone params for jira.n.xiaomi.com) | Cookies are domain-scoped → CAS login page. Pick the file matching the target host (table in Step 4). |
| Expect `jira_download_attachments` to return file bytes/base64 | It returns a summary; bytes are in tool-results `mcp-JiraMCP-blob-*`. |
| Read the 4828-byte CAS HTML as "download failed" | It's the CAS interception page, not an MCP result. MCP backend uses intranet. (Same ~2 KB HTML via curl = expired or wrong-host params — see Step 4.2.) |
| Assume bundled params never go stale | They are live session cookies — they expire (hours–days). On the expired-params signature, refresh per 4.3. |
| Leave attachments in tool-results cache | `mv` to `~/Downloads/jira-bugfix-flow/<ISSUE_KEY>/`, then `delete` blobs. |
| Multiple issues share one directory | One subdirectory per issue key. |
| Read zip/blob bytes as `.log` text | `unzip` first, read extracted `.log`. |
| Treat curl fallback as inferior / last resort | Verified MORE complete than MCP: saves image attachments as real files (MCP `jira_get_issue_images` only returns inline vision content). Use it whenever `jira_download_attachments` fails OR images are missing. |

## Real example — Q95GTK-11303
URL `https://jira-phone.mioffice.cn/browse/Q95GTK-11303` → host `jira-phone.mioffice.cn` → JiraMCP.
- `jira_get_issue(fields="*all")` → summary/description/steps/问题时间 2026-08-04 14:39/APP 9.9.9(591)/固件 VOS4.0.10.0/comments.
- `jira_get_issue(fields="attachment")` → 2 attachments (archive + video).
- `jira_download_attachments` → `{"success":true,"downloaded":2,"failed":[]}`.
- tool-results blobs matched by size → `mv` to `~/Downloads/jira-bugfix-flow/Q95GTK-11303/`; `unzip` → `.log` files; delete blobs.
- Verify sizes match metadata. ✅

## Real example — curl fallback (both domains, bundled params)

**Case A — jira-phone.mioffice.cn (MCP partial failure):** `jira_download_attachments` returned `success:true` and saved the archive blob, but the **image** attachment never persisted to a file (`jira_get_issue_images` returned inline vision content only). Fell back to Step 4 using the bundled `params/jira-phone.headers`.
- Manifest via `curl -H @params/jira-phone.headers /rest/api/2/issue/<KEY>?fields=attachment` → N attachments.
- Downloaded each via `curl -H @params/jira-phone.headers -o … <content url>` → all HTTP 200, `os.path.getsize` == manifest `size` exactly (image included, which MCP had missed).
- Archive extracted (incl. nested) → `.log` files. Dir ready for analysis. ✅

**Case B — jira.n.xiaomi.com (MCP cannot download at all):** old-mi-jira has no download tool and its session returned 302 (`connected:false`). Used Step 4 with the bundled `params/jira-n-xiaomi.headers`.
- Manifest via curl → N attachments (logs, images, `.tar.gz`, video). Downloaded each → all HTTP 200, every `os.path.getsize` == manifest `size`.
- `.tar.gz` members had absolute paths (`/data/...`) → sanitized via the `safe()` helper in 4.1, extracted under the issue dir. `.log`/image/video all on disk. Dir ready for analysis. ✅

(Both params files were verified end-to-end against live issues before being bundled; refresh per 4.3 when they expire.)
