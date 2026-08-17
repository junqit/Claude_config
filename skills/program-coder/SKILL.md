---
name: program-coder
description: Use when given a Swift source file path in the miwbtcore / MIWear Bluetooth SDK project and asked to "整理格式/风格" / "format" / "clean up" the file — normalize blank lines, line breaks, comments, indentation, colon spacing, signature alignment, and access-control order to the project's established conventions via add/delete/modify edits. Pure formatting only, never changes logic.
---

# Program Coder

## Overview
A file-path-driven style normalizer for the miwbtcore Swift codebase. Core principle: **given one file path, apply only formatting/style edits (增 add / 删 delete / 改 modify) so the file matches the project's measured conventions — and never touch logic, identifiers, or behavior.**

Every rule below is derived from real counts across the 148-file codebase, not generic Swift style. When the codebase is internally inconsistent, the rule picks the **measured majority** as the normalization target.

## Input
**Receives a single file path** (absolute or repo-relative `.swift` file in the miwbtcore project). All work is scoped to that one file.

## When to Use
- Handed a `.swift` file path with a request to tidy / standardize / 整理 its format and style.
- Before committing a file whose formatting drifts from the project conventions.

## When NOT to Use
- No file path provided (ask for one first).
- The request is to change behavior, fix a bug, or refactor logic — this skill is formatting only.
- Non-Swift files (this skill is calibrated to the Swift conventions below).

## Workflow (per file)
1. **Read the whole file** end-to-end before editing. Never edit blind.
2. **Classify deviations** against the Rule Table below. Tag each as 增 (add) / 删 (delete) / 改 (modify).
3. **Apply edits in a safe order** — structural first, then spacing, then comments, then modifiers:
   1. File header (增/改)
   2. Blank lines & line breaks (增/删)
   3. Braces & indentation (改)
   4. Colon spacing & signature alignment (改)
   5. Comments (增/改)
   6. `self.` and access-control order (增/改)
4. **Re-read the result** and confirm no logic/identifier/literal changed.
5. Report a concise summary: what was 增/删/改 and how many lines touched.

## Rule Table (measured conventions)

| # | Rule | Op | Target (normalize to) | Evidence |
|---|------|----|------------------------|----------|
| 1 | File header block | 增/改 | Every `.swift` starts with the `//` block (see below) | 148/148 files |
| 2 | Indentation | 改 | 4 spaces, never tabs | repo-wide |
| 3 | Blank after `{` opening a body | 增/删 | One blank line after `{` that opens a `func`/`init`/computed-`var` body | 71% (590/829) |
| 4 | No consecutive blank lines | 删 | At most one blank line anywhere; collapse `\n\n\n` → `\n\n` | only 7 violations repo-wide |
| 5 | Blank before closing `}` | 删 | No blank line immediately before `}` | dominant pattern |
| 6 | Blank between decls | 增 | One blank line between methods; one between top-level decls | dominant |
| 7 | EOF | 删/增 | Single trailing newline; no trailing blank lines | — |
| 8 | Colon — type annotation | 改 | `name: Type` — no space before colon, one after | standard |
| 9 | Colon — conformance/inheritance | 改 | `class Name: Proto` / `extension Name: Proto` — **no space before colon** | 101 vs 87 |
| 10 | Access-modifier order | 改 | `public static func` / `private static func` — modifier **before** `static` | 26 vs 6 |
| 11 | Multi-line signature | 改 | Colon-alignment: wrapped params align the param name under the first param's colon (see example) | dominant in long signatures |
| 12 | `self.` | 增 | Explicit `self.` for member access; **mandatory** inside closures | 1855 uses |
| 13 | `let _ =` | 增 | Use `let _ = X.shared` to trigger a side-effectful init | 20 uses |
| 14 | Doc comments | 增 | `///` on public API with `- Parameter:` / `- Parameters:` / `- Returns:` | public API surface |
| 15 | Descriptive comments | 改 | `// ` with one space after `//`; Chinese is normal and preserved | repo-wide |
| 16 | Commented-out code | 改 | `//` with **no** space after (e.g. `//import miwearLog`) | observed |
| 17 | Section comments | 增 | `// 扫描` / `// 连接 断开` style header line before an extension | observed |
| 18 | Brace placement | 改 | Opening brace on same line; `else {` and `guard … else {` on same line | dominant |
| 19 | Empty/trivial body | 改 | One-line `func foo() {}` for protocol stubs that do nothing | observed |
| 20 | `switch` | 增 | One blank line after `switch x {` before the first `case` | observed |
| 21 | Conditional compilation | 改 | `#if`/`#else`/`#endif` un-indented at column 0; content keeps its indent | observed |

## File header block (Rule 1)
Every file starts with exactly this shape, then ONE blank line, then imports:
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
- `<TargetName>`: use `MIWBTCore` unless the file's module context says otherwise.

## Imports
- `import Foundation` first, then other imports (`import CoreBluetooth`, project modules…).
- ONE blank line after the import block.
- Keep commented-out imports as `//import X` (no space, Rule 16).

## Examples (real patterns from the repo)

### Colon-alignment in wrapped signatures (Rule 11)
```swift
// ✅ target
static public func scanBTPeripheral(condition: MIWBTScanConfig?,
                                    didDiscover: @escaping MIWBTSearchPeripheralCallBack,
                                    complete: @escaping MIWBTSearcCompleteCallBack) {

    let _ = MIWBTCore.shared
    MIWBTScanManager.scanBTPeripheral(condition: condition,
                                      didDiscover: didDiscover,
                                      complete: complete)
}
```
Note the three things together: wrapped params colon-aligned; blank line after `{`; `let _ =` trigger.

### Conformance colon (Rule 9) — no space before colon
```swift
// ✅ target                    // ❌ normalize away
class MIWBTBleConnector: MIWBTConnector      //  class MIWBTBleConnector : MIWBTConnector
extension MIWBTCore: MIWBTCentralObserverInterface  //  extension MIWBTCore : MIWBTCentralObserverInterface
```

### Access-modifier order (Rule 10)
```swift
// ✅ target            // ❌ normalize away
public static func foo()    //  static public func foo()
```

### Blank line after `{` (Rule 3) + no blank before `}` (Rule 5)
```swift
// ✅ target
init() {

    let _ = MIWBTAppNotification.shared
    MIWBTCoreLog("MIWBTCore init, Version:\(MIWBTCoreVersion)", level: .info)
}

// ❌ fix: missing blank after {, or blank line right before }
init() {
    let _ = MIWBTAppNotification.shared
    MIWBTCoreLog(...)

}
```

### `self.` in closures (Rule 12)
```swift
// ✅ target
matchCBPeripheral(...) {[weak self] btPeripheral, err in

    guard let self = self else {
        return
    }

    if let error = err {
        self.connectComplete(err: error)
    }
}
```

## Hard constraints — what NEVER changes
- **Logic**: never reorder statements, never merge/split conditions, never change control flow.
- **Identifiers**: never rename types, methods, variables, or parameters (even typos — `perpheral` stays `perpheral`).
- **String literals**: never edit log strings, error descriptions, or any quoted text.
- **`#if` correctness**: only adjust indentation/spacing of compile-conditionals; never alter the condition or what's inside.
- **Comments' meaning**: preserve the wording/language (Chinese stays Chinese); only fix the `//` spacing and placement.

If a line already conforms, **leave it untouched** — minimize diff and preserve git blame.

## Common Mistakes
| Mistake | Fix |
|---|---|
| "Fixing" `perpheral` / `Connecttor` typos in names | Don't. Identifiers are out of scope. |
| Adding blank after `{` for a one-line `func foo() {}` | Rule 3 applies to multi-statement bodies; leave trivial stubs one-line (Rule 19). |
| Normalizing ` : ` conformance colon → inserting space (wrong direction) | Target is **no space before** colon (Rule 9). |
| Reordering to `static public func` (wrong direction) | Target is `public static func` (Rule 10). |
| Double-blank "for readability" | Forbidden (Rule 4). One blank line max. |
| Rewriting a Chinese comment into English | Preserve language; only fix `//` spacing. |
| Touching every line for "consistency" | Only touch non-conforming lines. Minimize diff. |

## Decision rule for unmapped patterns
If you encounter a style situation **not in the Rule Table**: do nothing to it. This skill normalizes to the codified project conventions only — it does not impose personal preference. Surface the unmapped pattern in the summary instead of guessing.
