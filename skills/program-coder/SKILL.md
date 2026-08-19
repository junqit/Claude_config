---
name: program-coder
description: Use when given a Swift source file path and asked to "整理格式/风格" / "format" / "clean up" the file — normalize blank lines, line breaks, comments, indentation, colon spacing, signature alignment, and access-control order to the project's own established conventions via add/delete/modify edits. Pure formatting only, never changes logic.
---

# Program Coder

## Overview
A file-path-driven style normalizer for any Swift codebase. Core principle: **given one file path, apply only formatting/style edits (增 add / 删 delete / 改 modify) so the file matches the measured-majority conventions of its own codebase — and never touch logic, identifiers, or behavior.**

This skill does **not** ship a fixed style sheet. Every target below is **discovered by sampling the surrounding code** (sibling `.swift` files in the same module/target) and normalizing the target file to the codebase's measured majority. When the codebase is internally inconsistent on a dimension, the rule picks the **measured majority** as the normalization target — never personal preference.

## Input
**Receives a single file path** (absolute or repo-relative `.swift` file). All work is scoped to that one file. Before editing, sample sibling `.swift` files in the same module/target to determine the dominant convention for each dimension in the Rule Table.

## When to Use
- Handed a `.swift` file path with a request to tidy / standardize / 整理 its format and style.
- Before committing a file whose formatting drifts from the project conventions.

## When NOT to Use
- No file path provided (ask for one first).
- The request is to change behavior, fix a bug, or refactor logic — this skill is formatting only.
- Non-Swift files (this skill is calibrated to Swift conventions).

## Workflow (per file)
1. **Read the whole target file** end-to-end before editing. Never edit blind.
2. **Sample the codebase** — read a few sibling `.swift` files in the same module/target to measure the dominant convention for each Rule Table dimension (indent char, blank-after-`{`, colon spacing, access-modifier order, header block shape, etc.).
3. **Classify deviations** of the target file against the measured conventions. Tag each as 增 (add) / 删 (delete) / 改 (modify).
4. **Apply edits in a safe order** — structural first, then spacing, then comments, then modifiers:
   1. File header (增/改)
   2. Blank lines & line breaks (增/删)
   3. Braces & indentation (改)
   4. Colon spacing & signature alignment (改)
   5. Comments (增/改)
   6. `self.` and access-control order (增/改)
5. **Re-read the result** and confirm no logic/identifier/literal changed.
6. Report a concise summary: what was 增/删/改 and how many lines touched.

## Rule Table (dimensions to normalize; target = measured majority of THIS codebase)

| # | Dimension | Op | Default target (override with measured majority) | How to determine |
|---|------|----|------------------------|----------|
| 1 | File header block | 增/改 | If the codebase uses a standard `//` header (FileName/TargetName/author/date), normalize to it | Sample; apply only if a header convention exists project-wide |
| 2 | Indentation | 改 | 4 spaces, never tabs | Swift standard; verify by sampling |
| 3 | Blank after `{` opening a body | 增/删 | One blank line after `{` opening a `func`/`init`/computed-`var` body | Sample; pick measured majority if split |
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
| Imposing ` : ` conformance colon against the codebase majority | Sample first; target is the **measured majority** (often no space before colon, Rule 9). |
| Reordering to `static public func` against the codebase majority | Sample first; target is the **measured majority** (often `public static func`, Rule 10). |
| Double-blank "for readability" | Forbidden (Rule 4). One blank line max. |
| Rewriting a Chinese comment into English | Preserve language; only fix `//` spacing. |
| Touching every line for "consistency" | Only touch non-conforming lines. Minimize diff. |
| Imposing a convention the codebase doesn't use | Don't. Only normalize to conventions the codebase itself exhibits. |

## Decision rule for unmapped patterns
If you encounter a style situation **not in the Rule Table**, or a dimension where the codebase has no clear majority: do nothing to it. This skill normalizes to the codebase's measured conventions only — it does not impose personal preference. Surface the unmapped pattern in the summary instead of guessing.
