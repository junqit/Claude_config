---
name: ips_symb_translate
description: Use when symbolicate an iOS .ips crash log against a local dSYM — given an .ips path and a dSYM directory, map binary offsets to method/file:line using Apple's CrashSymbolicator.py. Triggered by "符号化 ips" / "解析 ips" / "symbolicate .ips" / having .ips + dSYM on hand and needing the symbolicated stack.
---

# ips_symb_translate

## Overview

用苹果 Xcode 自带 `CrashSymbolicator.py`（CoreSymbolicationDT.framework，调 `libatos` 私有库）直接吃 .ips + dSYM 一步符号化全部线程。**不写 Python 符号化脚本，不手调 atos 逐帧**——苹果工具产出符号化 .ips，再用 jq 提取栈。

## When to Use

- 已有 .ips 崩溃日志 + 本地 dSYM（或 dSYM 目录），要符号化
- "符号化 ips" / "解析 ips" / "symbolicate .ips"
- 需把 .ips 二进制偏移映射到 方法名 + file:line
- **不适用**：无 dSYM（先经 mail_attachment skill 从 CI 邮件取）；旧版文本 .crash（用 `symbolicatecrash`）

## Quick Reference

| 参数 | 必填 | 说明 |
|------|------|------|
| ips_path | 是 | .ips 文件路径 |
| dsym_dir | 是 | dSYM 文件或目录（工具按 UUID 匹配） |
| output_path | 否 | 符号化后 .ips 输出路径，默认 stdout |

**工具路径**：`/Applications/Xcode.app/Contents/SharedFrameworks/CoreSymbolicationDT.framework/Resources/CrashSymbolicator.py`（`Resources` 是 symlink → `Versions/Current/Resources`，省 `Versions/A/` 也可）

## Implementation

### 1. 校验 dSYM UUID 匹配 .ips

不匹配则符号化静默失败。读 .ips header 的 `slice_uuid`，与 `dwarfdump --uuid` 对比（不区分大小写）：

```bash
dwarfdump --uuid /path/to/Foo.app.dSYM                      # 单个 dSYM
dwarfdump --uuid /path/to/dsym_dir/*.dSYM                   # 或遍历目录下所有 dSYM
jq -r '.slice_uuid' <(head -1 /path/to/crash.ips)           # 读 .ips slice_uuid（注意前导点，漏点会报 "slice_uuid/0 is not defined"）
```

### 2. 运行 CrashSymbolicator.py

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
CS="/Applications/Xcode.app/Contents/SharedFrameworks/CoreSymbolicationDT.framework/Resources/CrashSymbolicator.py"
python3 "$CS" -d <dsym_dir> -p -o <output.ips> <input.ips>
```

常用参数：
- `-d <dSYM>` dSYM 文件或目录（目录则遍历按 UUID 匹配）
- `-p` pretty print 输出
- `-o <file>` 输出文件（默认 stdout）
- `-s <path>` 额外符号搜索路径
- `--no-system-frameworks` 跳过系统框架（更快，只关心 app 帧时加）
- `--only-missing` 只补未符号化帧

工具遍历全部线程逐个符号化，stderr 打印 `Symbolicating thread <id>`。输出仍是 JSON .ips（header + body），帧新增 `symbol` / `sourceFile` / `sourceLine` 字段。

### 3. 用 jq 提取符号化栈

.ips 是两段 JSON（第一行 header + 其余 body），**必须用 `jq -s`**（slurp 成数组），`.[1]` 取 body。

主线程（faultingThread）符号化栈：

```bash
jq -s -r '
  .[1] as $b | $b.usedImages as $i |
  $b.threads[$b.faultingThread].frames |
  to_entries |
  map("[" + (.key|tostring) + "] " +
      ($i[.value.imageIndex].name // "?") + "  " +
      (.value.symbol // "(no symbol)") + "  " +
      ((.value.sourceFile // "") + ":" + ((.value.sourceLine // 0)|tostring))) | .[]
' <output.ips>
```

崩溃签名：

```bash
jq -s -r '
  .[1] as $b |
  "exception: " + ($b.exception.type // "?") + " signal=" + ($b.exception.signal // "?") + "\n" +
  "termination: " + ($b.termination.namespace // "?") + " code=0x" + (($b.termination.code // 0)|tostring) + "\n" +
  "faultingThread: " + (($b.faultingThread)|tostring)
' <output.ips>
```

### 4. 全线程扫描某代码路径（可选，验证 work item 是否在执行）

```bash
jq -s -r '
  .[1].threads[] | . as $t | .frames[]? | select(.symbol != null) |
  select(.symbol | test("关键词|Keyword")) |
  "thread " + ($t.name // "anon") + " : " + .symbol + "  " +
  (.sourceFile // "") + ":" + ((.sourceLine // 0)|tostring)
' <output.ips>
```

**空输出 = 该路径无帧 = 对应代码未运行**（可用于印证"work item 已排队但未执行"）。

## Common Mistakes

| 错误 | 现象 | 正确做法 |
|------|------|----------|
| `xcrun --find symbolicatecrash` | "unable to find utility" | 新版 Xcode（14+）移除 xcrun 暴露；用 framework 内 CrashSymbolicator.py |
| 写 Python 脚本调 atos 逐帧符号化 | 重复造轮 + baseAddress=0 易踩坑 | 用 CrashSymbolicator.py 一步到位 |
| atos 传十进制地址 | 回显数字不符号化 | 传 hex `0x...`；但优先用 CrashSymbolicator.py，不用 atos |
| `jq` 直接读 .ips | parse error（两段 JSON） | 用 `jq -s` slurp 成数组，`.[1]` 取 body |
| jq 用 `lpad` | "lpad/1 is not defined" | jq 1.7-apple 无 lpad，用 `tostring` |
| 不设 `DEVELOPER_DIR` | import libatos 失败 | `export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` |
| dSYM UUID 不校验 | 符号化静默失败（帧无 symbol） | 先 `dwarfdump --uuid` 对比 .ips `slice_uuid` |

## Output

符号化后 .ips（JSON，header + body，全部线程帧带 `symbol`/`sourceFile`/`sourceLine`）。**复制到工单附件目录归档**（如 `~/Downloads/jira-bugfix-flow/<ISSUE_KEY>/`），不要留 `/tmp`（重启丢失）。
