---
name: mail-attachment
description: Use when you need to search Xiaomi OWA mail (mail.xiaomi.com) by keyword and download email attachments or extract their download links — given a mail URL / search keyword, or a request like "搜邮件 Build #<N> 拿 symbol zip 下载地址 / 附件". Triggered by mail.xiaomi.com URLs, "搜索邮件 + 下载附件 / 拿下载地址", CI build-notification emails, or needing a file (dSYM / symbol / log zip) whose download link is inside a mail. Drives the logged-in Safari session; intranet-direct hosts curl, CAS-protected hosts blob-fetch.
---

# Mail Attachment Search & Download

Search Xiaomi OWA (`mail.xiaomi.com`) by keyword, open the matching emails, extract attachment / download links, and download the files to a storage path — or return the download URLs. **Safari holds the live CAS-SSO session**; OWA's React combobox ignores synthetic JS events, so the search query is typed with **real keystrokes via System Events** (trusted events). `curl` works for intranet-direct (FDS / object-storage) hosts; CAS-protected hosts need a same-origin Safari blob fetch. Solves the real traps: the `isTrusted` wall on synthetic Enter, AppleScript string-escaping breakage, the virtualized result list, OWA's loose keyword match, and the curl-vs-CAS decision.

## When to Use
- Given a mail URL or search keyword, need to download mail attachments (zips, dSYMs, logs, images, videos).
- Need the download URL of a file whose link is inside a CI / build-notification email.
- Another skill/agent needs a mail's attachments fed into it locally.

**When NOT to use:** you only need to *read* a mail's text inline. This skill is for *searching + downloading* attachments/links, not reading mail bodies.

## Inputs
- `keyword` *(required)*: OWA search query. To find an exact token like a CI build number `Build #<N>`, pass the **distinctive bare token** (the bare number) — OWA does loose keyword matching, so the skill scans each result's `innerText` for the exact string. A full phrase matches only loosely.
- `download_dir` *(optional)*: where downloaded files land. Default `~/Downloads/Skill/mail-attachment/`.
- `mail_host` *(optional)*: default `https://mail.xiaomi.com/owa/#path=/mail/search`.
- `target_filter` *(optional)*: substring to pick the right email among matches (e.g. a client/job name substring).
- `link_filter` *(optional)*: substring to select which links to download (e.g. `dSYM`, `.zip`).

## Step 0 — Prereqs (mandatory)
1. **Safari logged into the mail host** (CAS SSO complete). If a navigation yields a CAS login page, tell the user to open the mail URL in Safari and complete login first.
2. **`AllowJavaScriptFromAppleEvents` must be ON** (off by default). This is a persistent Safari pref the agent cannot self-authorize in auto mode — ask the user to run it (or approve the prompt):
   ```
   ! defaults write com.apple.Safari AllowJavaScriptFromAppleEvents -bool true
   ```
   **Restore after the task:** `defaults delete com.apple.Safari AllowJavaScriptFromAppleEvents`.
3. **Accessibility** for System Events keystrokes: the controlling app (Terminal / Claude Code) must be in *System Settings › Privacy & Security › Accessibility*, else `keystroke` errors "not allowed to send keystrokes". If it errors, tell the user to add the app and re-run.

## Step 1 — Locate / open the mail tab + drive the search (real keystrokes)
OWA hides the search input behind an `激活搜索文本框` button; the `input[role=combobox]` is revealed only after clicking it. Synthetic `value` + `Enter` is **IGNORED** (`isTrusted:false`) — you MUST type via System Events (trusted) with Safari frontmost.

```bash
osascript <<'OASC'
tell application "Safari"
  activate
  set theTab to missing value
  set theWin to missing value
  repeat with w in windows
    repeat with t in tabs of w
      try
        if (URL of t) contains "mail.xiaomi.com" then
          set theTab to t
          set theWin to w
          exit repeat
        end if
      end try
    end repeat
    if theTab is not missing value then exit repeat
  end repeat
  if theTab is missing value then
    if (count of windows) = 0 then
      make new document
      set theTab to tab 1 of window 1
      set theWin to window 1
    else
      tell window 1
        set theTab to make new tab
      end tell
      set theWin to window 1
    end if
    set URL of theTab to "https://mail.xiaomi.com/owa/#path=/mail/search"
    delay 8
  else
    set current tab of theWin to theTab
    set index of theWin to 1
    delay 1
  end if
  -- reveal + focus + select-all the search combobox (no backslash, no double-quote, no regex in the JS)
  set prep to (do JavaScript "(function(){var inp=document.querySelector('input[role=combobox]');if(!inp){var b=Array.from(document.querySelectorAll('button')).find(function(x){return (x.getAttribute('aria-label')||'').indexOf('激活搜索')>=0;});if(b)b.click();inp=document.querySelector('input[role=combobox]');}if(inp){inp.focus();inp.select();}return JSON.stringify({ready:!!inp});})()" in theTab)
  delay 0.6
end tell
tell application "System Events"
  keystroke "KEYWORD_HERE"
  delay 0.4
  key code 36
end tell
delay 6
```
Replace `KEYWORD_HERE` with the `keyword`. `delay 6` lets OWA fetch results; re-probe if still loading.

> **AppleScript escaping rule:** inside a `do JavaScript "..."` string, NEVER use a backslash, a regex (`/\s/`), or a double-quote `"` — they break AppleScript parsing (`-2741`). Use single-quoted JS strings only.

## Step 2 — Parse results (center pane only; virtualized)
Result rows are `[role=option]` in the **center pane** (`getBoundingClientRect().left ≥ ~215`); the left folder nav is also `[role=option]` at `x≈0` — **filter by x≥215** or you'll grab the nav tree. The list is **virtualized** (~22 rows/viewport): if the target isn't in the first probe, scroll the scroll container and re-probe, OR narrow the keyword. For an exact token, scan each row's `innerText`.

```bash
osascript <<'OASC'
tell application "Safari"
  set theTab to missing value
  repeat with w in windows
    repeat with t in tabs of w
      try
        if (URL of t) contains "mail.xiaomi.com" then set theTab to t
      end try
    end repeat
    if theTab is not missing value then exit repeat
  end repeat
  set r to (do JavaScript "(function(){
    var opts=Array.from(document.querySelectorAll('[role=option]'));
    var main=opts.map(function(e){var rc=e.getBoundingClientRect();return {x:Math.round(rc.left),vis:(rc.width>0&&rc.height>0),t:(e.innerText||'').slice(0,260)};}).filter(function(o){return o.x>=215&&o.vis;});
    var hit=main.filter(function(o){return o.t.indexOf('EXACT_TOKEN')>=0;});
    return JSON.stringify({u:location.href, visible:main.length, hits:hit});
  })()" in theTab)
  return r
end tell
OASC
```
Replace `EXACT_TOKEN` with the exact string to match (e.g. `Build #<N>`). If `hits` is empty and `visible` is large, the target is below the viewport — scroll and re-probe:

```bash
# scroll the result-list container to the bottom, then re-probe (one do-JS call)
osascript <<'OASC'
tell application "Safari"
  set theTab to missing value
  repeat with w in windows
    repeat with t in tabs of w
      try
        if (URL of t) contains "mail.xiaomi.com" then set theTab to t
      end try
    end repeat
    if theTab is not missing value then exit repeat
  end repeat
  set r to (do JavaScript "(function(){
    var rows=Array.from(document.querySelectorAll('[role=option]')).filter(function(e){var rc=e.getBoundingClientRect();return rc.left>=215;});
    if(!rows.length) return JSON.stringify({err:'no rows'});
    var p=rows[0].parentElement; var sc=null;
    while(p && p!==document.body){var cs=getComputedStyle(p);if((cs.overflowY==='auto'||cs.overflowY==='scroll')&&p.scrollHeight>p.clientHeight+10){sc=p;}p=p.parentElement;}
    if(!sc) return JSON.stringify({err:'no scroll container'});
    sc.scrollTop=sc.scrollHeight;
    return JSON.stringify({scrolled:true, sh:sc.scrollHeight, st:sc.scrollTop});
  })()" in theTab)
  return r
end tell
OASC
```
After scrolling, `delay 1.5` then re-run the parse probe. Repeat until the target appears or the list is exhausted.

## Step 3 — Open the target email + extract download links
Click the matching `[role=option]` (innerText contains `keyword` + `target_filter`), wait ~4s for the reading pane, then dump `a[href]` and filter candidates.

```bash
# Call 1 — click the target row (EXACT_TOKEN = exact string, e.g. Build #<N>)
osascript <<'OASC'
tell application "Safari"
  set theTab to missing value
  repeat with w in windows
    repeat with t in tabs of w
      try
        if (URL of t) contains "mail.xiaomi.com" then set theTab to t
      end try
    end repeat
    if theTab is not missing value then exit repeat
  end repeat
  set clk to (do JavaScript "(function(){var rows=Array.from(document.querySelectorAll('[role=option]'));var hit=rows.find(function(e){var t=e.innerText||'';return t.indexOf('EXACT_TOKEN')>=0;});if(!hit) return JSON.stringify({err:'no row'});hit.click();return JSON.stringify({clicked:true});})()" in theTab)
  return clk
end tell
OASC

# Call 2 — wait for the reading pane, then extract ALL links + candidate subset.
# IMPORTANT: run click + read as TWO separate osascript calls (one do-JS each),
# and do NOT name the result var `rd` — AppleScript tokenizes `rd` specially → -2741.
# Use `r` / `clk` / `res`.
osascript <<'OASC'
tell application "Safari"
  set theTab to missing value
  repeat with w in windows
    repeat with t in tabs of w
      try
        if (URL of t) contains "mail.xiaomi.com" then set theTab to t
      end try
    end repeat
    if theTab is not missing value then exit repeat
  end repeat
  delay 4
  set r to (do JavaScript "(function(){var links=Array.from(document.querySelectorAll('a[href]')).map(function(a){var rc=a.getBoundingClientRect();return {t:(a.innerText||'').slice(0,90), h:a.href, vis:(rc.width>0||rc.height>0)};});var cand=links.filter(function(o){var s=(o.h+' '+o.t).toLowerCase();return s.indexOf('.zip')>=0||s.indexOf('.ipa')>=0||s.indexOf('.apk')>=0||s.indexOf('symbol')>=0||s.indexOf('dsym')>=0||s.indexOf('artifact')>=0||s.indexOf('download')>=0;});return JSON.stringify({linkCount:links.length, candidates:cand, allLinks:links});})()" in theTab)
  return r
end tell
OASC
```
`candidates` = links matching archive/package/symbol/dSYM/artifact/download extensions (`.zip .ipa .apk` …). `allLinks` = every `a[href]` — **use `allLinks` when the caller asked for ALL attachments/addresses**, since the candidate filter may miss an extension (e.g. `.ipa` was missed before the filter was widened). Each link is `{t: linkText, h: url}`. Apply `link_filter` to pick which to download.

## Step 4 — Download (curl first, Safari blob-fetch on CAS)
1. **Try `curl -sSL` first** — FDS / intranet-direct object-storage hosts return `200` + real bytes, no CAS:
   ```bash
   mkdir -p "DOWNLOAD_DIR"
   curl -sSL --connect-timeout 15 -o "DOWNLOAD_DIR/FILENAME" \
     -w "http=%{http_code} size=%{size_download} type=%{content_type}\n" "URL"
   file "DOWNLOAD_DIR/FILENAME"   # must be the real archive, not ~4KB HTML
   ```
   If `http=200`, `size>0`, and `file` reports the expected archive type → done. A ~4KB `HTML document` = CAS interception → fall back to step 2.
2. **CAS-protected host → Safari same-origin blob fetch** (the tab is on `mail.xiaomi.com`, so `credentials:'include'` sends the session cookies; `anchor.download` forces a save with the chosen filename):
   ```bash
   osascript <<'OASC'
   tell application "Safari"
     set theTab to missing value
     repeat with w in windows
       repeat with t in tabs of w
         try
           if (URL of t) contains "mail.xiaomi.com" then set theTab to t
         end try
       end repeat
       if theTab is not missing value then exit repeat
     end repeat
     do JavaScript "var u='URL';var f='FILENAME';fetch(u,{credentials:'include'}).then(function(r){return r.blob();}).then(function(b){var a=document.createElement('a');a.href=URL.createObjectURL(b);a.download=f;document.body.appendChild(a);a.click();});0" in theTab
   end tell
   OASC
   ```
   Safari saves to `~/Downloads/`; poll by byte size, then `mv` to `DOWNLOAD_DIR/FILENAME`. Verify `wc -c` matches any known size.

## Step 5 — Output to caller
- Downloaded files in `download_dir` (default `~/Downloads/Skill/mail-attachment/`).
- A manifest: `[{filename, url, local_path, size}]`.
- Report any attachment/link that failed to download **explicitly** — never silently skip, never fabricate a download.

## Common Mistakes
| Mistake | Reality |
|---|---|
| Synthetic JS `value` + `new KeyboardEvent('Enter')` to run the OWA search | Ignored — `isTrusted:false`. Use System Events real `keystroke` + `key code 36` (Safari frontmost). |
| Regex (`/\s/`), backslash, or `"` inside a `do JavaScript "..."` string | AppleScript syntax error `-2741`. No backslash, no regex; single-quoted JS; no `"` in the JS. |
| Grabbing every `[role=option]` without an x-filter | Mixes in the left folder nav (`x≈0`). Filter `getBoundingClientRect().left ≥ 215`. |
| Expecting all results in the first probe | Virtualized (~22 rows/viewport). Scroll the `_lvv_W1 … scrollContainer` (`scrollTop=scrollHeight`) + re-probe, or narrow the keyword. |
| Search `Build #<N>` and expect only that email | OWA loose-matches `Build`. Search the bare token (the number) and scan each row's `innerText` for the exact string. |
| `curl` a CAS-protected attachment URL | ~4KB CAS login HTML. Use the Safari same-origin blob fetch. |
| `AllowJavaScriptFromAppleEvents` is off | `do JavaScript` errors. Caller must enable (Step 0); `defaults delete` to restore after. |
| `keystroke` errors "not allowed to send keystrokes" | Controlling app lacks Accessibility permission — add it in System Settings › Accessibility. |
| Leave the pref ON after the task | Restore: `defaults delete com.apple.Safari AllowJavaScriptFromAppleEvents`. |
| Read a ~4KB CAS HTML as "download failed" | It's the CAS interception page. Use the Safari blob fetch, not curl. |
| Name the `do JavaScript` result var `rd` | AppleScript tokenizes `rd` specially → `-2741` at that var. Use `r` / `clk` / `res`. (`r`/`clk`/`prep` are fine; only `rd` is cursed — verified in practice.) |
| Candidate filter misses a package link (`.ipa`/`.apk`) | The `candidates` filter targets archive/symbol/dSYM/artifact/download. For "ALL attachments/addresses" use `allLinks`; the filter now also includes `.ipa`/`.apk`. |
| Click + read in ONE osascript block (two `do JavaScript`) | If it errors, split into two osascript calls (one `do JavaScript` each) — proven reliable. Step 3 is already written that way. |

## Worked example — dSYM via intranet-direct host (curl path)
Inputs: `keyword=<build_number>`, `target_filter=<client/job substring>`, `link_filter=dSYM`. `download_dir` defaulted to `~/Downloads/Skill/mail-attachment/`.
- OWA returned CI build-notification emails; the row `<client> - Build #<N> - Successful!` matched (bare `<N>` + `<client>`).
- Reading-pane link `SYMBOLS-…build<N>` → an intranet-direct object-storage (FDS) URL, e.g. `https://<fds-host>/<bucket>/<path>/App-…-build<N>.dSYM.zip`.
- `curl -sSL` → `http=200 size=<bytes> type=application/octet-stream`; `file` = `Zip archive data`. FDS direct, no CAS → done.
- Saved to `~/Downloads/Skill/mail-attachment/App-build<N>.dSYM.zip`. ✅
- Lesson: the symbol email's download host was intranet-direct (FDS), so curl sufficed; no blob-fetch needed.
