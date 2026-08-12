---
name: code-analytic
description: Use when analyzing code to locate a bug's root cause — reading a key method's full body, tracing its complete parent call-stack to entry, tracing every child callee's full sub-call-stack to the state-change root, and recording the frame-by-frame analysis. Also use when accumulating analyzed module/file/method knowledge into a shared context index for future lookups.
---

# Code Analytic

## Overview
A disciplined method for analyzing source code to locate a root cause with verifiable, gap-free evidence. Core principle: **no root-cause conclusion before the complete parent + child call stacks are read end-to-end.** Symptom-level patches are failure.

## When to Use
- Need to find why a bug happens, based on a key code line / log line / symptom
- Before proposing or applying any fix
- When you need to record analyzed code structure into a shared knowledge index for future analyses

## When NOT to Use
- Pure config/typo fix where the offending line is obvious and self-contained
- Research/exploration with no specific symptom to trace

## The Four Capabilities

### 1. Read the key method's full body (自身上下文)
Given a key code line (from a log, a symptom, or a suspect), read the **entire enclosing method**, not just the suspect line. Plus the relevant parts of its file: class properties, lifecycle methods, related private/helper methods, protocol conformance.

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
- **No skipped frames**: any unknown frame → read it. Third-party / SDK calls that can't be read → mark "black box" and infer from observable behavior / docs / logs. **Never skip, never assume internal implementation as known.**

### 4. Full sub-call-stack of each child callee
For each child method discovered in capability 3, repeat: read its full body + trace *its* callees down to state-change root. The stack must be complete end-to-end from the key method to every leaf state-change.

## Completeness Gate (mandatory before any conclusion)
All three must be satisfied. Otherwise keep gathering — **no root-cause hypothesis, no Edit, no branch creation** until gate passes:
- [ ] **Self**: target method full body + file context read; inputs/side-effects/dependencies clear.
- [ ] **Parent stack**: every call path traced to entry; each frame's caller context read (not just file:line).
- [ ] **Child stack**: every callee implementation read; every path traced to a state-change root (or marked black-box).

If something can't be obtained (closed-source SDK, missing logs): mark the gap explicitly and state its impact on the conclusion. **Never fill gaps with speculation.**

## Record the Analysis Process
For every frame in both stacks, record verifiable detail — not just a final stack list:
- Tool used (Grep / LSP `findReferences` / `incomingCalls` / `outgoingCalls`)
- Call site `file:line`
- The exact line that invokes the next frame

A reader must be able to follow how each frame was found.

## Context Knowledge Index (`.claude/workspace/context.md`)

After analysis, update the shared index at `<current working directory>/.claude/workspace/context.md`. This ONE file accumulates structural code knowledge across ALL analyses — it is NOT per-issue.

### What to record
Structural code knowledge only (module / file path + purpose / method name + owning file + purpose). **Never** record root causes / logs / fix diffs / call-stack narratives / issue keys here — those belong in the analysis report.

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
- `mkdir -p .claude/workspace`
- Deduplicate across all four dimensions before appending.
- Only structural code knowledge — no root cause / logs / fix diff / call-stack narrative / issue key.
- Do NOT `git add` / commit / push — workspace only.

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
| Index update | Read + Edit `context.md` | dedup 4 dimensions |

## Common Mistakes
- Reading only the suspect line, not the full method → misses real cause in another branch of the method
- Recording `file:line` without reading the caller's context → can't verify the call actually triggers the problem path
- Stopping at the first state-change point → misses other branches that are the real cause
- Skipping SDK/closed-source calls without marking black-box → hides the actual boundary
- Adding duplicate index entries (same module/file/method/purpose) → bloats the index
- Recording root cause / logs / fix in `context.md` → pollutes the structural index with per-issue data
