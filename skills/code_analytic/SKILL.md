---
name: code_analytic
description: Use when analyzing code to locate a bug's root cause — reading a key method's full body, tracing its complete parent call-stack to entry, tracing every child callee's full sub-call-stack to the state-change root, and recording the frame-by-frame analysis. Also use when accumulating analyzed module/file/method knowledge into a shared context index for future lookups.
---

# Code Analytic

## Overview
A disciplined method for analyzing source code to locate a root cause with verifiable, gap-free evidence. Core principles: (1) **the key method is either located by byte-exact matching of the key log / error text to the code that emits it (Type 1 input) OR given directly as an accurate method name (Type 2 input) — no guessing, no inference**; (2) **no root-cause conclusion before the complete parent + child call stacks are read end-to-end**; (3) **read ALL code under `$PWD` recursively in real time — regardless of directory structure, naming, or layout; all code analysis is based ONLY on actually searching/reading the entire `$PWD` tree (`grep` / `rg` / `Read` / LSP `findReferences` / `incomingCalls` / `outgoingCalls`), **not a narrow 'project directory' or single-module subset**; no external context (session history, other issues, caller assumptions, or the `context.md` index used as a conclusion) is a code-knowledge source.** Symptom-level patches are failure.

## Input
The skill **receives one of two entry types** as its starting point:

1. **Key log / error content** (Type 1 — for the log path) — the raw log lines / error strings / exception text from the problem, pasted verbatim (byte-for-byte as they appear in the log file, with timestamps / tags / payload intact). The skill does byte-exact log→code matching to locate the key method (see Log-to-code matching). Used when the entry is a log symptom.
2. **An accurate method name** (Type 2 — for the direct-entry path, e.g. a crash with a symbolicated frame) — a method name (or the enclosing method of a `file:line`). The skill **skips log→code matching** (the key method is already given) and starts directly from Capability 1: read the method's full body, then trace call stacks.

All four capabilities work outward from the key method (located by matching OR given directly).

Obtaining the logs (downloading / decrypting) is the caller's responsibility; **the log → code matching is the skill's job — but only when the entry is Type 1 (log content)**. When the entry is Type 2 (method name), no matching is needed.

## Output
The skill's output is **the complete code of the key method + the complete code of the entire call context — with no omissions.** Every method in the key method's parent + child call stacks must be output as its **complete method code** (full method body, verbatim — every line), not just a `file:line` reference or a single invoking line. Nothing may be skipped, summarized, or dropped.

Concretely the output comprises:
- **Key method's complete code** — the full method body (verbatim, every line) of the key method + its file context (class properties, lifecycle, related helpers, protocol conformance); inputs / return / side effects; pre/post conditions; dependent properties/state.
- **Parent call-stack (every path → entry) — each frame's complete code** — every caller traced to its entry point; **each frame's full method code (verbatim)** + calling logic / trigger condition / passed arguments / who calls *that*.
- **Child call-stack (every callee → state-change root) — each frame's complete code** — every callee inside the key method traced to where state actually changes (property write / persistence / notification / UI refresh / task start); **each callee's full method code (verbatim)**, every branch traced independently.
- **Full sub-call-stack of each child callee** — repeated end-to-end from the key method to every leaf state-change; each frame's complete method code.
- **Per-frame record** (every frame in both stacks) — tool used (Grep / LSP `findReferences` / `incomingCalls` / `outgoingCalls`), call site `file:line`, the exact line invoking the next frame.
- **Completeness Gate result** — Self / Parent stack / Child stack self-check (see Completeness Gate).
- **Black-box boundaries** — where tracing stopped and why, per the [Stop-tracing boundary](#stop-tracing-boundary).
- **Context Knowledge Index update** — `$HOME/WorkSpace/<project-hash>/context.md` path.

**No omissions (铁律):** the key method's complete code + every call-stack frame's complete method code must appear in the output — **not `file:line`-only, not invoking-line-only, not summarized**. Every line of every relevant method's body must be output verbatim. If a frame's code cannot be read (black-box per the Stop-tracing boundary, or missing), the gap is marked explicitly with its impact on the conclusion — never silently dropped, never filled with speculation.

## Log-to-code matching (byte-exact, no guessing) — Type 1 input only (log content)
**This section applies ONLY when the input is Type 1 (key log / error content).** When the input is Type 2 (an accurate method name), **skip this entire section** — the key method is already given; go directly to The Four Capabilities.

When the input is log content, the key method is located **from the key log / error text**, not handed in. The skill performs this matching itself:

1. Take the key log lines / error strings from the Input verbatim.
2. `grep` / `rg` ALL of `$PWD` for the log text (all of `$PWD` recursively, regardless of directory structure — not a narrow 'project directory' or single-module subset) — the literal string passed to the `log(...)` / `print(...)` / `NSLog` / `os_log` / `Logger` / project-logger call that emits it.
3. The call site that emits the matched log = the entry point; its enclosing method = the key method for the Four Capabilities.

**Byte-exact verification (铁律, no guessing):**
- Every byte of the matched log string in the code must correspond to the problem log — the code's emitted text and the problem log must **completely coincide**, not "close enough".
- If the log text carries runtime values (timestamps, IDs, payloads, formatted args), match only the **static template portions** (format strings, tags, fixed prefixes); confirm the runtime portions are produced by the matched call site's format args — do not invent a match for parts you cannot verify.
- A log string that cannot be located in the codebase, or whose located call site does not byte-exactly account for the problem log, is an **unresolved gap** — mark it explicitly and state its impact. **Never guess a method, never infer a call site from similarity, never skip the byte-exact check.** No verified match → no key method → no root-cause conclusion.

## When to Use
- Key log lines / error messages are in hand and need log-to-code matching + full context analysis (Type 1)
- An accurate method name / `file:line` is already known (e.g. crash with a symbolicated frame) and needs full call-stack analysis (Type 2)
- Before proposing or applying any fix
- When you need to record analyzed code structure into a shared knowledge index for future analyses

## When NOT to Use
- No key log/error text AND no method name in hand (obtain one of them first, then use this skill)
- Pure config/typo fix where the offending line is obvious and self-contained

## Stop-tracing boundary
**Stop tracing at system methods, binary libraries, or any third-party code whose source cannot be read.** Mark these as "black box" and infer behavior from observable evidence (logs / docs / runtime behavior). Do not speculate about internal implementation.

Concretely stop when the next frame is:
- A platform system-framework method (e.g. on iOS: UIKit / Foundation / CoreMedia / AVFoundation / Photos / …; on Android: `android.*` framework; etc.)
- A precompiled binary library / closed-source SDK (e.g. iOS Pods without source, `.framework` / `.a` binaries; Android `.aar` / third-party modules; binary packages on other platforms)
- Any code not present in the current working directory's source tree

Do NOT stop at:
- First-party source anywhere in the working directory (read it — do not stop at nested first-party code, regardless of where it lives in the tree)
- Open-source dependencies whose source is checked out in the working directory (read the source)

## Real-time read & independent analysis (实时读取 / 独立分析铁律)
**All code analysis is based ONLY on real-time reads of ALL code under the current working directory (`$PWD`) — the entire `$PWD` tree recursively, regardless of directory structure, naming, or layout.** The search (`grep`/`rg` for log strings, LSP `findReferences`/`incomingCalls`/`outgoingCalls` for callers/callees) spans the whole `$PWD` tree — **do NOT narrow it to a 'project directory' or a single module.** Every method body, caller, callee, and state-change point must be read fresh from disk (`Read` / `grep` / LSP) at analysis time — not from memory, not from a summary, not from a stale earlier read.

**No external context (铁律):** the code-knowledge source is `$PWD`'s files and nothing else. Do NOT use as a code-knowledge source:
- session history / memory of previous analyses;
- other issues' conclusions, call chains, or fix directions;
- caller-supplied assumptions about what the code "should" do;
- the `context.md` index entries **as conclusions** — the index is a locator ("which file/method does what"), not the answer; a root cause / call chain / fix must still be derived independently from the real-time code read of the current issue.

If a frame cannot be read from `$PWD` (per the [Stop-tracing boundary](#stop-tracing-boundary)) → mark it black-box; never substitute memory or external context for the missing read.

## The Four Capabilities

### 1. Read the key method's full body (自身上下文)
Given the key method (located by Log-to-code matching for Type 1 input, OR given directly as a method name for Type 2 input), read its **entire enclosing method (complete code — every line, verbatim)**, not just the matched call site / named entry. Plus the relevant parts of its file: class properties, lifecycle methods, related private/helper methods, protocol conformance.

Confirm before moving on:
- Method inputs / return / side effects
- Pre / post conditions
- Which properties or state it depends on, which state affects it
- If it's an extension/override — read the parent class / protocol declaration too

### 2. Parent call-stack (所有调用方 → entry)
Trace who calls the method, and who calls that, up to the entry point (VC lifecycle / event callback / BLE callback / app launch). Use Grep / LSP `findReferences` + `incomingCalls`.

Rules:
- **Read each caller's context**, not just `file:line` — the calling logic, trigger condition, passed arguments, and who calls *that* method.
- **Cover every entry path**: if the method is called from multiple places, trace each path independently to entry.

### 3. Child call-stack (方法内所有被调用方 → 状态变更根点)
Trace every callee inside the method (sub-method / function / closure / property setter / notification post), down to where state actually changes (property write / persistence / notification / UI refresh / task start). Use LSP `outgoingCalls` + **read each callee's full implementation**, not just its signature.

Rules:
- **Cover every branch**: if the method has multiple state-change points, trace each independently to the root.
- **No skipped frames**: any unknown frame → read it. Stop only at the [Stop-tracing boundary](#stop-tracing-boundary) — mark as "black box", infer from observable behavior / docs / logs. **Never skip a first-party frame, never assume a black-box's internal implementation as known.**

### 4. Full sub-call-stack of each child callee
For each child method discovered in capability 3, repeat: read its full body + trace *its* callees down to state-change root. The stack must be complete end-to-end from the key method to every leaf state-change.

## Completeness Gate (mandatory before any conclusion)
All three must be satisfied. Otherwise keep gathering — **no root-cause hypothesis, no Edit, no branch creation** until gate passes:
- [ ] **Self**: target method full body + file context read; inputs/side-effects/dependencies clear.
- [ ] **Parent stack**: every call path traced to entry; each frame's caller context read (not just file:line).
- [ ] **Child stack**: every callee implementation read; every path traced to a state-change root (or marked black-box).

If something can't be obtained (closed-source SDK / binary library / system method per the [Stop-tracing boundary](#stop-tracing-boundary), or missing logs): mark the gap explicitly and state its impact on the conclusion. **Never fill gaps with speculation.**

## Record the Analysis Process
For every frame in both stacks, record verifiable detail — not just a final stack list:
- Tool used (Grep / LSP `findReferences` / `incomingCalls` / `outgoingCalls`)
- Call site `file:line`
- The exact line that invokes the next frame

A reader must be able to follow how each frame was found.

## Context Knowledge Index (`$HOME/WorkSpace/<project-hash>/context.md`)

After analysis, update the shared index at `$HOME/WorkSpace/<project-hash>/context.md` — **outside the git repo**, keyed by the current project so it is shared across worktrees and never committed. This ONE file accumulates structural code knowledge across ALL analyses — it is NOT per-issue.

### Resolving `<project-hash>`
`<project-hash>` is the **MD5 hex digest of the current working directory's absolute path**. Compute it once at the start of the index-update step and reuse it:

```bash
# macOS
echo -n "$PWD" | md5
# Linux
echo -n "$PWD" | md5sum | awk '{print $1}'
```

The full 32-char hex digest is the folder name — do not truncate it (avoids collisions across project paths).

### What to record
Structural code knowledge only (module / file path + purpose / method name + owning file + purpose). **Never** record root causes / logs / fix diffs / call-stack narratives / issue keys here — those belong in the analysis report.

**Scope: current working directory only.** Record only files/methods that live inside the current working directory's source tree. Every `<path>` and `<file:line>` written into the index MUST resolve under `$PWD`. Do NOT record references to other projects, repositories, sibling directories, or cross-platform/foreign-tree counterparts. When analysis spans multiple projects (e.g., cross-platform porting, comparing Android vs iOS), each project's `context.md` holds ONLY that project's own code; foreign-project paths/names belong in the analysis report, never in the index.

### Strict deduplication — four dimensions
Before writing, read existing entries and check each dimension. Only append genuinely new items; never add duplicates:
- **Module**: module name exists → don't create a duplicate module section; merge new files/methods into the existing section.
- **File path**: file path exists → don't add a duplicate file row (may update purpose if more accurate, but no duplicate row).
- **Method name + owning file**: same `method name` + `owning file` (file:line) exists → don't add a duplicate method row.
- **Method purpose**: purpose description semantically duplicates an existing entry (same method, same purpose, different wording only) → don't add; only update the existing row if the purpose is genuinely new/more accurate.

### Structure (organized by module, shared across all analyses)
```markdown
# Context 知识库（所有分析共享）

## 模块: <模块/功能域>
### 文件
| 文件路径 | 功能 |
|---|---|
| <path> | <一句话职责> |
### 方法
| 方法名 | 所属文件 | 功能 |
|---|---|---|
| <method> | <file:line> | <一句话职责> |
```

### Rules
- `mkdir -p "$HOME/WorkSpace/<project-hash>"` (compute `<project-hash>` per the section above).
- Deduplicate across all four dimensions before appending.
- Only structural code knowledge — no root cause / logs / fix diff / call-stack narrative / issue key.
- **Current-working-directory scope only** — every recorded file path / method owner must resolve under `$PWD`. No other-project / other-repo / sibling-directory / cross-platform-counterpart references; those go in the analysis report, not the index.
- The index lives outside the project repo; it is never `git add`-ed / committed / pushed.

## How the index is used in future analyses
The index is a **file/method capability index, consulted on demand by relevance**:
- If a future analysis touches a module/method that has index entries → may reference the index to locate code faster.
- If no relevance → don't force-associate, don't quote its description as a conclusion.
- The index is "which file/method does what" — not the answer to any problem. Root cause / call chain / fix must still be derived independently from the current issue's evidence + code logic.

## Quick Reference

| Capability | Tool | Depth |
|---|---|---|
| Self context | Read | full method + file context |
| Parent stack | Grep / LSP `findReferences` + `incomingCalls` | every path → entry, read each caller |
| Child stack | LSP `outgoingCalls` + Read | every callee → state-change root |
| Sub-call-stack | repeat child-stack for each callee | end-to-end to every leaf |
| Index update | Read + Edit `$HOME/WorkSpace/<project-hash>/context.md` | dedup 4 dimensions |

## Common Mistakes
- Reading only the matched call site, not the full method → misses real cause in another branch of the method
- Recording `file:line` without reading the caller's context → can't verify the call actually triggers the problem path
- Stopping at the first state-change point → misses other branches that are the real cause
- Skipping SDK/closed-source calls without marking black-box → hides the actual boundary
- Adding duplicate index entries (same module/file/method/purpose) → bloats the index
- Recording root cause / logs / fix in `context.md` → pollutes the structural index with per-issue data
- Recording other-project / cross-platform / sibling-directory paths in `context.md` (e.g., writing Android file paths into an iOS project's index during a port) → pollutes a per-project index with foreign-tree content; record only `$PWD` files here, put foreign references in the analysis report
- Relying on session history / other issues / caller assumptions / `context.md`-as-conclusion instead of real-time reading `$PWD` code → analysis built on non-evidence; read the code fresh from disk each analysis.
- Treating the `context.md` index as the answer → it is a locator; root cause / call chain / fix must be re-derived from the real-time code read, not quoted from the index.
- Narrowing the search to a 'project directory' or single-module subset instead of ALL code under `$PWD` recursively (regardless of directory structure) → misses callers, callees, or log-emitters elsewhere in the tree.
