---
name: log_analytic
description: Use when a decrypted log directory and a problem timepoint (date+time, to the minute) are in hand and the complete verbatim log context at that timepoint is needed before code analysis. Triggered by '按时间点定位日志' / '提取问题时间点日志上下文' / 'log_analytic' / having logs + a timepoint and needing the full raw context (no truncation/summary/fabrication).
---

# Log Analytic

## Overview
A disciplined method for locating the **complete verbatim log context at a problem timepoint**. Core principles: (1) **the problem timepoint is the sole anchor for log location — without it no log interval can be located**; (2) **the output is every covering log line, raw and unmodified — no deletion, no summary, no fabrication**; (3) **read the given log directory carefully and thoroughly — all output log content comes ONLY from logs within that directory; no external context (session history, other issues, other log directories, caller assumptions, or guesses in the problem description) is used as a log source.** Log analysis only (no code analysis, no symbolication).

## Input
The skill **receives three parameters**:

| Parameter | Required | Default | Description |
|---|---|---|---|
| 日志目录 (log directory) | yes | — | Directory of already-downloaded / already-decrypted logs. The skill only reads; it does not download or decrypt. |
| 问题描述 (problem description) | yes | — | One-line symptom (any type: crash / logic / protocol / UI / sync / connection / network / perf…). Guides what counts as "problem context". |
| 问题时间点 (problem timepoint) | yes | — | The time the problem occurred (date + time, to the minute; e.g. "09-05 21:13" or "2026-09-05 21:13:00"). The **sole anchor** for log location. |

**Missing-parameter handling**: any of the three missing → STOP and report which and why (the timepoint is the log-location anchor; without it no log interval can be located). Log directory missing/empty → STOP. Problem timepoint given as date only (no time) → ask for the time; fully missing → STOP.

**版本号不是输入参数**——本 skill 只接收上述 3 个参数，**不接收任何版本号作为输入**；问题时间点的 APP 版本号是 2.2 从日志中提取的**输出字段**（见 Output），由日志本身记录，不由 caller 传入。

## Output
The skill's output is **the complete log context at the problem timepoint — verbatim, with no omissions.** Every covering log line (problem-before setup + problem-moment + problem-after ripple) must be produced as the raw line exactly as it appears in the log file (timestamp / tag / payload intact); nothing may be deleted, summarized, rewritten, or fabricated.

Concretely the output comprises:
- **Problem timepoint** (the confirmed anchor) + **problem description** (one line).
- **Log app version — 必填(问题时间点正确版本号; 输出字段, 不是输入参数)** — the version marker of the app session covering the problem timepoint, **extracted verbatim from the covering file (an output field in the conclusion, NOT an input parameter — the skill takes no version as input)**; **must always be output** (explicit value X as "日志应用版本 = X", or "日志未记录应用版本" gap — the field is mandatory even when the marker is absent).
- **Log device type (设备类型信息: 产品ID / 产品模型) — 必填(输出字段)** — the device's product ID / product model of the app session covering the problem timepoint, **extracted verbatim from the covering file (an output field, NOT an input parameter)**; **must always be output** (explicit value as "日志设备类型 = <产品ID/产品模型>"（问题时间点上下文所记录的设备类型）, or "日志未记录设备类型,无法确认" gap — the field is mandatory even when the marker is absent).
- **Covering log file(s)** — path + time interval; the timepoint file primary, neighbor files as context.
- **Complete problem-context raw logs** — every relevant log line around the timepoint (default ±30min window, adjusted by problem nature), each line verbatim (含时间戳,一字不改粘贴; not truncated / summarized / rewritten).
- **Key log evidence** — error codes / exceptions / state-machine transitions / timeouts / failures / state changes, each as raw line + filename. Error strings kept verbatim; their literal meaning is NOT interpreted here (that is a code-analysis concern).
- **Crash/exception signature** — if the log or description indicates a crash (`.ips`/`.crash`/`Crashed`/`Exception Type:`/`Thread N Crashed:`/native crash signature, or 闪退/崩溃/crash/EXC_/SIGSEGV/SIGABRT/SIGKILL/ANR/Watchdog in the description), flag it. The skill does NOT symbolicate; mark "符号化主证据缺失" and note that only the crash thread's surrounding ordinary-log context is included — symbolication is out of scope.

**No deletion / no summary / no fabrication (铁律):**
- **No deletion**: every covering log line in the problem context is output verbatim — none may be dropped, even if it seems redundant.
- **No summary**: the problem timeline may be summarized narratively, but the raw log lines themselves are never summarized — they are pasted verbatim.
- **No fabrication**: if no log covers the timepoint, or a version marker / crash signature is absent, mark the gap explicitly and take the nearest interval with a noted evidence limitation. Never invent log lines, timestamps, or signatures.

## When to Use
- A decrypted log directory + problem description + problem timepoint are in hand, and the complete raw log context at that timepoint is needed.
- Before handing log context to code analysis (this output is exactly the Input `code_analytic` now expects — the complete content of key logs / error messages).
- When you need to confirm which app version a log records, or whether a crash signature is present.

## When NOT to Use
- No problem timepoint (obtain it first — it is the sole anchor).
- Logs not yet downloaded/decrypted (obtain them first; this skill only reads).
- Pure code analysis with a known key method → use `code_analytic` directly.
- Crash symbolication needed → this skill only flags the gap; use `ips_symb_translate` or dispatch `jira-fix-single` for symbolication.

## Workflow

### Step 1 — Problem timepoint confirmation (问题时间点确认)
1. Extract the three parameters (log directory / problem description / problem timepoint).
2. **The problem timepoint is the sole anchor for Step 2 log location** — without it no log interval can be located. Date only (no time) → ask; fully missing → STOP.
3. Verify the log directory exists and is non-empty. If not → STOP and report.
4. Record parameters, enter Step 2.

### Step 2 — Log location by timepoint (按问题时间点定位日志)
Goal: locate the log file(s) covering the problem timepoint, extract the timeline (verbatim) + key evidence + recognize crash (crash needs flagging, not symbolication).

#### 2.1 Locate covering log file(s)
- `ls`/`find` the log directory; list all log files (`.log`/`.txt`/`.json`/`.gz` etc; `.gz` → `gunzip` in place first; other compression → decompress by actual format).
- Filter files **covering the problem timepoint** by filename timestamp or first/last-line timestamp (log naming varies per project — judge by actual filename/content timestamp, no preset format).
- Multiple files covering: the timepoint's file is primary; neighbor files are context (problem-before setup, problem-after ripple).
- No file covers the timepoint → mark the "问题时间点无日志覆盖" gap, take the nearest interval and analyze best-effort with a noted evidence limitation. **Never fabricate.**

#### 2.2 Log app-version confirmation (must do before analysis; must explicitly output the recorded app version)
Extract the app/version marker **of the app session covering the problem timepoint** from the log (version-marker format varies per project — grep by the project's actual marker: `App version =`/`APPV/<ver>`/`version:`/`CFBundleShortVersionString`/startup banner line/filename version segment). multi-file → use the covering file (the file covering the problem timepoint); **if that file spans multiple app launches/sessions (e.g. multi-day log, app updated mid-file), locate the version marker of the session whose time range contains the problem timepoint — not just any marker in the file**; cross-check. **First confirm what version the log itself records at the problem timepoint (explicit value, verbatim full version string, not just "无法校验"):**
- **Log has version marker** → extract value X (the exact full version string, verbatim from the covering file's problem-timepoint session); output states "日志应用版本 = X"（问题时间点上下文所记录的应用版本）.
- **Log has no version marker** → "日志未记录应用版本,无法确认". Continue; flag the version gap.

#### 2.2b Log device-type confirmation (must do before analysis; must explicitly output the recorded device type)
Extract the device's product ID / product model **of the app session covering the problem timepoint** from the log (device-marker format varies per project — grep by the project's actual marker: `device model`/`product`/`productId`/`model`/device-name in startup banner / BLE-connect line / filename segment; same extraction rules as 2.2 app-version: covering file, the session whose time range contains the problem timepoint, verbatim full string, cross-check). First confirm what device the log itself records at the problem timepoint:
- **Log has device marker** → extract value verbatim from the covering file's problem-timepoint session; output states "日志设备类型 = <产品ID/产品模型>"（问题时间点上下文所记录的设备类型）.
- **Log has no device marker** → "日志未记录设备类型,无法确认". Continue; flag the gap.

#### 2.3 Crash/exception recognition (for output flagging, not symbolication)
Recognize by log signature + problem description whether this is a crash/exception (only this category needs special flagging):
- **Crash/exception**: description contains 闪退/崩溃/crash/Exception/EXC_/SIGSEGV/SIGABRT/SIGKILL/卡死重启/ANR/Watchdog etc, or log contains `.ips`/`.crash`/`Crashed`/`Exception Type:`/`Thread \d+ Crashed:`/native crash signature → **this skill does NOT symbolicate** (no dSYM/symbol capability), flag "疑似崩溃,符号化主证据缺失,本 skill 仅含崩溃前后普通日志上下文;建议派 `jira-fix-single` 完整模式符号化". Best-effort locate crash-before/after state from ordinary logs; flag the evidence gap.
- **Non-crash** (logic/protocol/UI/sync/connection/network/perf/data/permission… any type) → normal flow, no branching by type.

#### 2.4 Extract timeline + key log evidence
- `rg`/`grep` the log around the problem timepoint (±reasonable window, default ±30min, adjusted by problem nature); extract **every line verbatim (不截断/总结/改写/重写)** with timestamp → this is the timeline.
- Key logs: error codes / exceptions / state-machine transitions / timeouts / failures / state-change lines, raw line + filename. Error codes/strings kept verbatim; **do not interpret their literal meaning before code analysis confirms it** (placeholder/misleading text is a code-analysis concern).
- If logs or the timepoint are missing (2.1 found no coverage and no nearest interval) → STOP and report.

## Record the location process
For reproducibility, record how each step was performed — not just a final context dump:
- Tool used (`ls`/`find`/`gunzip`/`grep`/`rg`/`Read`).
- Covering file path(s) + how the timepoint coverage was determined (filename timestamp or first/last-line timestamp).
- The ±window chosen and why.

A reader must be able to re-locate the same context.

## Stop / boundary
- **Log analysis only**: no code analysis (that's `code_analytic`), no symbolication (flag gap → `ips_symb_translate` / `jira-fix-single`), no `Edit`/`Write`, no commit, no Jira comment, no Feishu.
- **Does not download/decrypt logs**: the log directory is supplied already decrypted. For downloading → `jira_attachments` skill / `jira-fix-single` / `ufi-analytic` agent / `ufi-miwear-analytic` agent.
- **Does not fabricate**: missing log / missing version / missing crash signature → mark the gap explicitly, never fill with speculation.
- **Does not interpret error-string meaning**: error strings are output verbatim; whether they reflect real runtime state is a `code_analytic` concern.
- **只依赖日志目录内的日志(独立分析铁律)**:**所有输出日志内容只取自给定日志目录内的日志文件**——认真仔细读取覆盖文件,逐行读,不 skim/跳读/挑选。**不参考任何外部上下文**:session 历史、其他问题结论、其他日志目录、caller 对日志内容的假设、问题描述里的猜测,一律不作为日志内容来源。问题描述仅用于判定「什么算问题上下文」(找哪类错误 / 哪个时间窗),不作为日志内容来源;日志原文只从目录内的文件 `Read`/`grep` 取。

## Quick Reference

| Step | Tool | Output |
|---|---|---|
| 1. Timepoint confirmation | param extraction + `ls`/`find` dir | confirmed anchor + dir valid |
| 2.1 Covering file | `ls`/`find`/`gunzip`/`Read` | covering file(s) + interval |
| 2.2 App version | `grep`/`rg` version marker | "日志应用版本 = X" or gap |
| 2.2b Device type | `grep`/`rg` device marker | "日志设备类型 = <ID/模型>" or gap |
| 2.3 Crash recognition | signature grep | crash flag or non-crash |
| 2.4 Timeline + evidence | `rg`/`grep` ±window | verbatim timeline + key evidence |

## Common Mistakes
- Summarizing log lines instead of pasting verbatim → loses the actual evidence.
- Dropping "redundant" lines → the dropped line is often the real signal.
- Interpreting an error string's meaning before code analysis → placeholder/misleading text gets treated as real state.
- Inventing log lines/timestamps when no coverage exists → fabricates evidence; must mark gap + take nearest with limitation.
- Skipping app-version confirmation → can't tell which build's logs are being read.
- Skipping device-type confirmation → can't tell which device's logs are being read (ticket-stated device may differ from the log's actual device).
- Doing code analysis / symbolication here → scope creep; this skill is log-context only.
- Relying on external context (session history, other issues, caller assumptions, guesses in the problem description) instead of only the given log directory → pollutes the log context with non-evidence; the directory's logs are the sole source.
- Skimming/skipping covering files instead of reading them carefully line by line → misses the actual problem-timepoint lines.
