---
name: log_decryption
description: Use when needing to decrypt Xiaomi wear/phone encrypted feedback logs (files prefixed `encrypt_` — encrypt_*.log / encrypt_*.zip / encrypt_*.tar.gz downloaded from feedback.pt.xiaomi.com) into readable plaintext. Given a directory of encrypted logs, produces a `decryption/` subdirectory with decrypted output. Triggered by "解密日志" / "decrypt encrypt_ logs" / "反馈日志解密" / having encrypt_* files and needing plaintext logs.
---

# log_decryption

## Overview

解密 `feedback.pt.xiaomi.com` 反馈平台下载的加密日志（`encrypt_` 前缀）。客户端 AES-256-CBC，key 经服务端同源 POST 换取，本地 node 解密，递归处理嵌套压缩包内的加密日志至不动点。**接收原始目录，在该目录下创建 `decryption/` 子目录，解密后日志放进去。**

## When to Use

- 给定一个含 `encrypt_*` 加密日志的目录，要解密成可读明文
- 触发词：解密日志 / decrypt encrypt_ logs / 反馈日志解密
- 文件前缀 `encrypt_` 的 `.log`/`.zip`/`.tar.gz`（来自 feedback.pt.xiaomi.com 下载）

**When NOT to use:**
- 还没下载日志 → 先 `miwear-ufi-anaylytic` agent 下载
- 要分析日志内容 → 交给 `log-code-anylytic` / `ufi-analytic`

## 前置（mandatory；缺则停步报 caller）

1. **Safari 已登录 `feedback.pt.xiaomi.com`**（CAS SSO 完成）——取 key 的 POST 是同源 + `credentials:'include'`，需登录态 cookie。
2. **`AllowJavaScriptFromAppleEvents` ON**（auto-mode classifier 可能拦 `defaults write`，需 caller 手动 `!` 前缀执行）：
   ```
   ! defaults write com.apple.Safari AllowJavaScriptFromAppleEvents -bool true
   ```
   任务后还原：`defaults delete com.apple.Safari AllowJavaScriptFromAppleEvents`（Safari 运行中删立即生效，无需重启；任务未完前不要删）。
3. **Safari 有一个 `feedback.pt.xiaomi.com` 的 tab**（任意页面即可，同源就能发 POST 取 key）。
4. **node 可用**（`crypto` 内置模块，无需装包）。

## 加密格式（逆向自 `/utils/logDecryptUtil` 内联 Vue 脚本）

- **文件格式**：`[128 字节密钥材料][2 字节小端 length + length 字节 AES 密文 group]…` 循环到文件尾。
- **AES key 不在 JS**：每文件前 128 字节 base64 后，POST `{"<uid>":"<b64>"}` 到 `/log/decrypt/wear/decryptLogKeys`（同源，`credentials:'include'`，`Content-Type: application/json`），服务端回 `{"<uid>":"<base64AesKey>"}`（key 多为 32 字节 → AES-256）。
- **解密**：`key=Buffer.from(b64Key,'base64')`，`iv=Buffer.from('A-16-Byte-String','utf8')`（16 字节固定），`aes-<keylen*8>-cbc`，Pkcs7，**每个 group 新建 decipher（IV 重置）**。从 `pos=128` 循环：读 2 字节 LE length → 读 length 字节 ct → `decipher.update(ct)+decipher.final()`（final 自动去 Pkcs7）→ 拼接。
- **解密产物落位**：每个 `encrypt_` 所在目录下创建 `decryption/`，解密产物（明文 + 解压内容）放进去。加密源 `encrypt_*` 保留不删。
- **解密后若是压缩包**：按 magic 解压到 `decryption/`：`PK\x03\x04`(zip)→`unzip -o -q -d`；`1f 8b`(gzip/tar.gz)→`tar -xf -C`；否则当明文写文件（文件名去 `encrypt_` 前缀）。
- **嵌套不动点**：有的 `encrypt_*.zip`/`encrypt_*.tar.gz` 解密后是**打包的更多 `encrypt_*` 日志**，解压出来还要再解密。递归循环直到 `encrypt_` 文件数不再增长。

## 流程

```bash
# 解密循环（推荐，处理嵌套）——接收原始目录
bash <skill_dir>/run_decrypt_loop.sh <LOG_DIR>

# 单文件验证（需先有 base64 key）：
node <skill_dir>/decrypt.js <encFile> <base64Key> [outFile]
```

`run_decrypt_loop.sh` 内部循环（最多 6 轮）：
1. `prep.js` 递归扫 `<LOG_DIR>` 下所有 `encrypt_*` → `filemap.json` + `batch_N.jsobj`（每 20 文件一批，JS 对象字面量 `{uid:'b64',...}`，单引号——base64 无 `'`/`\`，安全）。
2. 每批 inline 进 Safari `do JavaScript`，POST `/log/decrypt/wear/decryptLogKeys` 取 key → `keys_batch_N.json`。
3. `finish.js` 合并 keys + 逐文件 AES 解密 + 按 magic 解压到 `<dir>/decryption/`。
4. count `encrypt_` 文件，`after <= before` → 不动点 break。

## do-JavaScript 转义铁律（AppleScript `do JavaScript "..."` 内）

- **禁反斜杠**（`\n`/`\s`/`\d` 全不行——AppleScript `-2741`）。
- **禁双引号** `"`（会终结 AppleScript 字符串）——JS 字符串全用单引号，对象 key 用无引号标识符，要 JSON 就 `JSON.stringify({k:'v'})`。
- **禁正则字面量** `/\s/`（含反斜杠）。
- 换行用 `String.fromCharCode(10)`，双引号用 `String.fromCharCode(34)`。
- 结果变量名别用 `rd`（AppleScript 特殊分词 `-2741`），用 `r`/`clk`/`res`。

## 取 key 不能走 localhost

解密工具页是 HTTPS，`fetch('http://127.0.0.1:...')` 被 mixed-content 拦（`TypeError: Load failed`）。改为**每批 ~20 个文件 inline 进 `do JavaScript`** 同源 POST（携带 feedback.pt session cookie）。

## 输出结构

```
<LOG_DIR>/                              # 接收的原始目录
├── encrypt_*.log / encrypt_*.zip       # 加密源（保留，不删）
├── decryption/                         # ← 本 skill 创建
│   ├── com.xiaomi.miwatch.pro YYYY-MM-DD HH-MM.log   # 明文（去 encrypt_ 前缀）
│   ├── pro_YYYY-MM-DD--HH-MM-SS-XXX.log
│   └── data/                           # 压缩包解压产物（若有）
```

## Common Mistakes

| 错误 | 后果 | 正解 |
|---|---|---|
| 走 localhost server 取 key | HTTPS 页 `fetch http://127.0.0.1` 被 mixed-content 拦 | inline `do JavaScript` 同源 POST |
| `do JavaScript` 里用 `\n` / `"` / `/\s/` | AppleScript `-2741` 解析错 | 单引号 + `String.fromCharCode(10)` |
| 一个 decipher 处理所有 group | IV 连续，解密错 | 每 group 新建 decipher（IV 重置） |
| 删 `encrypt_` 源文件 | 嵌套循环无法重扫 | 保留 `encrypt_`，只输出到 `decryption/` |
| 轮询匹配 `*.zip.download` 半成品 | 抓到半成品 | 本 skill 只解密已落盘的 `encrypt_*`，下载交给 `miwear-ufi-anaylytic` |
