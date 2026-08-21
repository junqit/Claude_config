---
name: program-coder
description: Use when given a Swift source file path + an edit requirement (改逻辑/加功能/删代码/重构/整理格式/format/clean up). Edits code logic per the request AND normalizes style to the project's measured-majority conventions. Combines code editing + style normalization.
---

# Program Coder

## Overview
A file-path-driven Swift code editor + style normalizer with two independent capabilities:

1. **编辑代码 (Edit code)** — modify logic / add new code / delete code / refactor per the requirement. Can change behavior, control flow, statements, conditions, add/remove methods and calls.
2. **代码风格 (Code style)** — normalize to the project's own conventions (Rule Table): blank lines, indentation, colon spacing, signature alignment, access-control order, comments.

## 两能力关系（独立使用 + 约束）
- 两个能力**可独立使用，不是捆绑**：
  - 只格式化（requirement = "format only" / 整理格式 / clean up）：仅做代码风格归一化，不改逻辑。
  - 只编辑代码（requirement = 改逻辑 / 加功能 / 删代码 / 重构）：做逻辑编辑。
- **硬约束：添加或修改代码逻辑时，必须同时应用代码风格归一化**。即编辑代码后必须格式化改动的代码，保证新增/修改的代码符合代码风格。不可只编辑代码不格式化。
- 单独格式化（不改逻辑）允许；单独编辑代码不格式化**禁止**。

This skill does **not** ship a fixed style sheet. Style targets are **discovered by sampling the surrounding code** (sibling `.swift` files in the same module/target) and normalizing to the measured majority. When the codebase is internally inconsistent on a dimension, pick the **measured majority** — never personal preference.

## Input
- **A single file path** (absolute or repo-relative `.swift` file).
- **An edit requirement** — what logic/feature to add/modify/delete; or "format only" if just style.

## When to Use
- Given a `.swift` file path + a code edit request (改逻辑 / 加功能 / 删代码 / 重构).
- Before committing edited code — normalize its style to project conventions.
- Pure format/clean up requests (requirement = "format only").

## When NOT to Use
- No file path provided (ask for one first).
- Non-Swift files (this skill is calibrated to Swift conventions).

## 业务日志规则（user-mandated，仅编辑代码时）

**触发条件**：仅当 requirement ≠ "format only"（编辑代码：改逻辑 / 加功能 / 删代码 / 重构）时适用。纯格式化**不**触发——添加日志属逻辑变更，禁止在 format-only 流程插入。

**规则**：在本次 requirement 涉及的代码（所编辑的方法 / 区域）内，**所有发生 error 或 return 的地方**，若无日志则补一条日志语句；已有日志不重写（遵守「String literals 不擅自改」+ minimize diff）。

**适用点**（不限于此）：
- `guard … else { return }` 的 guard / early return
- `catch { … return }` 错误分支
- `if let error = err { … return }` 失败回调
- 函数内任意显式 `return`
- `throw` / 失败分支

**日志内容：只含业务信息，不含其他信息**
- ✅ 业务信息：在做什么业务操作、涉及的业务实体（用户 / 设备 / 运动类型 / 记录 / 日期等）、业务结果或状态。例："步数记录解析失败，日期:\(dateString)"。
- ❌ 其他信息（禁止写入日志）：原始 error 对象 dump（`error.localizedDescription` / `\(error)`）、堆栈 / `Thread.callStackSymbols`、内部类名 / 内存地址 / 框架内部细节、请求 / 响应体、技术调试符号。

**与 minimize-diff / edit-scope 的关系**：本规则为 user-mandated，对"error / return 处补业务日志"这一维度**覆盖** minimize-diff 与 edit-scope 默认——编辑代码时必须给所编辑区域内的 error / return 点补齐业务日志，不得以"减少 diff / 超出请求"为由跳过。其余维度仍守 minimize-diff。

**日志方法**：用所采样代码库的实际日志用法（如多数用 `CoreLog`），不引入新日志系统。

**示例**：
```swift
// ✅ guard return 处补业务日志（只含业务信息）
guard let record = stepRecord else {

    CoreLog("步数记录解析失败，日期:\(dateString)", level: .error)
    return
}

// ✅ catch 处补业务日志
} catch {

    CoreLog("睡眠数据同步失败，用户:\(userId)", level: .error)
    return
}

// ❌ 禁止：dump 原始 error / 堆栈等非业务信息
} catch {

    CoreLog("error:\(error) stack:\(Thread.callStackSymbols)", level: .error)
    return
}
```

## Workflow (per file)
1. **Read the whole target file** end-to-end before editing. Never edit blind.
2. **Sample the codebase** — read sibling `.swift` files in the same module/target to measure the dominant convention for each Rule Table dimension, and to learn the project's idioms (naming, patterns, API usage).
3. **Understand the edit requirement** — what logic/feature to add/modify/delete. Locate the relevant methods/lines.
4. **Edit code** (if requirement ≠ "format only"):
   1. Apply logic edits (增 add / 删 delete / 改 modify) per the requirement — statements, control flow, new methods, calls, conditions, etc.
   2. Use the project's sampled idioms for new code — naming, patterns, API.
   3. Apply the 业务日志规则 — at every error/return site in the edited code, add a business-only log if none exists (see 业务日志规则 section).
5. **Normalize style** (always, including after edits) — apply the Rule Table:
   1. File header (增/改)
   2. Blank lines & line breaks (增/删)
   3. Braces & indentation (改)
   4. Colon spacing & signature alignment (改)
   5. Comments (增/改)
   6. `self.` and access-control order (增/改)
6. **Re-read the result** — confirm edits fulfill the requirement AND style conforms.
7. Report a concise summary: logic edits (增/删/改) + style fixes, lines touched.

## Rule Table (style dimensions; target = measured majority of THIS codebase)

| # | Dimension | Op | Default target (override with measured majority) | How to determine |
|---|------|----|------------------------|----------|
| 1 | File header block | 增/改 | If the codebase uses a standard `//` header (FileName/TargetName/author/date), normalize to it | Sample; apply only if a header convention exists project-wide |
| 2 | Indentation | 改 | 4 spaces, never tabs | Swift standard; verify by sampling |
| 3 | Blank after `{` opening a body | 增/删 | One blank line after `{` opening a `func`/`init`/computed-`var` body (multi-statement; one-line trivial stubs exempt per Rule 19) | Hard rule (user-mandated); applies regardless of measured majority — see section |
| 4 | No consecutive blank lines | 删 | At most one blank line anywhere; collapse `\n\n\n` → `\n\n` | Broad convention |
| 5 | Blank before closing `}` | 删 | No blank line immediately before `}` | Broad convention |
| 6 | Blank between decls | 增 | One blank line between methods; one between top-level decls | Broad convention |
| 7 | EOF | 删/增 | Single trailing newline; no trailing blank lines | Standard |
| 8 | Colon — type annotation | 改 | `name: Type` — no space before colon, one after | Swift standard |
| 9 | Colon — conformance/inheritance | 改 | `class Name: Proto` / `extension Name: Proto` — no space before colon | Sample; pick measured majority (some codebases use ` : `) |
| 10 | Access-modifier order | 改 | modifier **before** `static` (`public static func`) | Sample; pick measured majority |
| 11 | Multi-line signature | 改 | Colon-alignment: wrapped params align the param name under the first param's colon (see example) | Sample; align only if the codebase aligns |
| 12 | `self.` | 增 | Explicit `self.` for member access; **mandatory** inside closures | Sample; pick measured majority |
| 13 | `let _ =` side-effect init | 增/删 | `let _ = X.shared` to trigger a side-effectful init | Only normalize if the codebase uses this idiom |
| 14 | Doc comments | 增 | `///` on public API with `- Parameter:` / `- Parameters:` / `- Returns:` | If the codebase documents public API |
| 15 | Descriptive comments | 改 | `// ` with one space after `//`; preserve comment language | Standard |
| 16 | Commented-out code | 改 | Match the codebase's commented-import style (e.g. `//import X`) **only if it uses one** | Sample |
| 17 | Section comments | 增 | Section header comment line before an extension **only if the codebase uses them** | Sample |
| 18 | Brace placement | 改 | Opening brace on same line; `else {` and `guard … else {` on same line | Swift standard (K&R) |
| 19 | Empty/trivial body | 改 | One-line `func foo() {}` for protocol stubs that do nothing | Sample |
| 20 | `switch` | 增/删 | One blank line after `switch x {` before the first `case` **if the codebase does so** | Sample |
| 21 | Conditional compilation | 改 | `#if`/`#else`/`#endif` un-indented at column 0; content keeps its indent | Standard |
| 22 | Blank around control-flow blocks | 增 | One blank line before & after a control-flow block (`if`/`else if`/`else`/`guard`/`for`/`while`/`switch`/`do`) when adjacent to other statements | Hard rule (user-mandated); see section + exceptions |

## File header block (Rule 1)
If the codebase uses a header block, normalize to exactly this shape, then ONE blank line, then imports:
```swift
//
//  <FileName>.swift
//  <TargetName>
//
//  Created by <作者> on YYYY/M/D.
//
```
- If present but malformed (wrong slash count / spacing) → fix (改).
- If the author/date already exist → **preserve them verbatim**. Only fill in if entirely absent.
- `<TargetName>`: derive from the file's module context (Xcode target / module name). Do not invent one.

## Imports
- `import Foundation` first, then other imports (e.g. `import CoreBluetooth`, project modules…).
- ONE blank line after the import block.
- Match the codebase's commented-import style for disabled imports.

## Examples (generic patterns)

### Colon-alignment in wrapped signatures (Rule 11)
```swift
// ✅ target (when the codebase aligns wrapped params)
static public func scanPeripheral(condition: ScanConfig?,
                                  didDiscover: @escaping SearchPeripheralCallBack,
                                  complete: @escaping SearchCompleteCallBack) {

    let _ = Core.shared
    ScanManager.scanPeripheral(condition: condition,
                               didDiscover: didDiscover,
                               complete: complete)
}
```
Note the things together: wrapped params colon-aligned; blank line after `{`; `let _ =` trigger (only if the codebase uses it).

### Conformance colon (Rule 9) — no space before colon
```swift
// ✅ target                    // ❌ normalize away
class BleConnector: Connector      //  class BleConnector : Connector
extension Core: CentralObserverInterface  //  extension Core : CentralObserverInterface
```

### Access-modifier order (Rule 10)
```swift
// ✅ target            // ❌ normalize away
public static func foo()    //  static public func foo()
```

### Blank line after `{` (Rule 3) + no blank before `}` (Rule 5)
**This rule is user-mandated (hard):** always insert one blank line after `{` opening a `func`/`init`/computed-`var` body (multi-statement), regardless of the sampled codebase majority — even if every func in the file currently omits it. Exception: one-line trivial stubs `func foo() {}` (Rule 19).
```swift
// ✅ target
init() {

    let _ = AppNotification.shared
    CoreLog("Core init, Version:\(CoreVersion)", level: .info)
}

// ❌ fix: missing blank after {, or blank line right before }
init() {
    let _ = AppNotification.shared
    CoreLog(...)

}
```

### `self.` in closures (Rule 12)
```swift
// ✅ target
matchPeripheral(...) {[weak self] peripheral, err in

    guard let self = self else {
        return
    }

    if let error = err {
        self.connectComplete(err: error)
    }
}
```

### Blank around control-flow blocks (Rule 22)
Every control-flow keyword transition gets a blank line. The method-name/signature case is covered by Rule 3 (blank after `func … {`) and Rule 6 (blank between methods); this rule extends the same idea to `if` / `else if` / `else` / `guard` / `for` / `while` / `switch` / `do` blocks: separate a control-flow block from adjacent statements with one blank line — before the opening keyword when preceded by a statement, and after the closing `}` when followed by a statement.

```swift
// ✅ target
let x = compute()

if x > 0 {
    handle(x)
}

let y = x + 1
```

Adjacent control-flow blocks merge their before/after blanks into ONE (Rule 4 — never two):
```swift
// ✅ target
if a {
    foo()
}

if b {
    bar()
}
```

Exceptions:
- **`if` / `else if` / `else` chain stays tight** — no blank between a branch's `}` and the next `else` / `else if`; they are one construct:
```swift
// ✅ target
if x > 0 {
    a()
} else if x < 0 {
    b()
} else {
    c()
}
```
- **No blank before the enclosing `}`** (Rule 5 wins): if the block is the last statement in a body, do not blank between its `}` and the scope's closing `}`.
- **No double blank** (Rule 4 wins): merge into one.
- This rule is **user-mandated**; it applies even when the sampled codebase does not exhibit the pattern, overriding the "measured majority" default for this dimension only.

## Hard constraints — what NEVER changes without explicit request
- **Edit scope**: logic edits must fulfill the stated requirement; don't add unrelated changes beyond the request. Keep diff focused.
- **业务日志 override**: the 业务日志规则 (user-mandated) requires adding business-only logs at every error/return site in the edited code; this overrides "Edit scope / minimize diff" for that dimension only — such logs are in-scope, not unrelated changes.
- **Identifiers**: don't rename types/methods/variables/parameters unless the requirement explicitly asks (even typos — `perpheral` stays `perpheral` unless told to fix).
- **String literals**: don't edit log strings / error descriptions / quoted text unless the requirement asks.
- **`#if` correctness**: only adjust indentation/spacing of compile-conditionals; never alter the condition or what's inside unless the requirement asks.
- **Comments' meaning**: preserve the wording/language (Chinese stays Chinese); only fix `//` spacing/placement unless the requirement asks to change wording.
- **Minimize diff**: if a line already conforms, leave it untouched — preserve git blame.

## Common Mistakes
| Mistake | Fix |
|---|---|
| Adding unrelated logic changes beyond the request | Edit only what the requirement asks; keep diff focused. |
| Renaming `perpheral`/`Connecttor` typos without being asked | Don't. Identifiers unchanged unless requirement says. |
| Adding blank after `{` for a one-line `func foo() {}` | Rule 3 applies to multi-statement bodies; leave trivial stubs one-line (Rule 19). |
| Imposing ` : ` conformance colon against the codebase majority | Sample first; target is the **measured majority** (often no space before colon, Rule 9). |
| Reordering to `static public func` against the codebase majority | Sample first; target is the **measured majority** (often `public static func`, Rule 10). |
| Double-blank "for readability" | Forbidden (Rule 4). One blank line max. |
| Rewriting a Chinese comment into English | Preserve language; only fix `//` spacing. |
| Touching every line for "consistency" | Only touch non-conforming lines. Minimize diff. |
| Imposing a convention the codebase doesn't use | Don't. Only normalize to conventions the codebase itself exhibits — **except rules marked "user-mandated" in the Rule Table** (e.g. Rule 22), which apply regardless. |
| Inserting a blank inside an `if`/`else if`/`else` chain (`}` then blank then `else {`) | The chain is one construct; keep `} else {` / `} else if {` tight. Blank only *around* the whole chain, not between its branches. |
| Skipping error/return logging to "minimize diff" | 业务日志规则 is user-mandated and overrides minimize-diff/edit-scope for this dimension; when editing code, add a business-only log at every error/return site in the edited region (not on format-only runs). |
| Putting raw `error` / stack / class names in the log | Log must contain business info only (operation + business entity + outcome). No `\(error)` / `error.localizedDescription` / `Thread.callStackSymbols` / internal class names / addresses / framework internals. |

## Decision rule for unmapped patterns
If you encounter a style situation **not in the Rule Table**, or a dimension where the codebase has no clear majority: do nothing to it. This skill normalizes to the codebase's measured conventions only — it does not impose personal preference. Surface the unmapped pattern in the summary instead of guessing.
