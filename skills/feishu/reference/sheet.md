# 电子表格高级操作参考

## 批量读写

```bash
# 一次读取多个范围
feishu sheet read-batch TOKEN "Sheet1!A1:D5" "Sheet2!A1:B3"
# 返回：{ results: [{ range, values }] }

# 一次写入多个范围（--values 或 -f）
feishu sheet write-batch TOKEN --values '[{"range":"Sheet1!A1:B2","values":[["a","b"]]},{"range":"Sheet2!A1","values":[["x"]]}]'
feishu sheet write-batch TOKEN -f batch.json
```

`batch.json` 格式：`[{ "range": "<sheetRef>!<start>:<end>", "values": [[...]] }]`

---

## 筛选 / 保护范围 / 浮动图片

```bash
# 筛选（--col --filter-type --expected 均为必填）
feishu sheet filter create <url_or_token> <工作表> <range> \
  --col <列字母> --filter-type <类型> --expected <值> [--compare-type <比较方式>]
feishu sheet filter get    <url_or_token> <工作表>
feishu sheet filter delete <url_or_token> <工作表>

# 示例：筛选 B 列等于 "Alice" 或 "Bob" 的行
feishu sheet filter create TOKEN Sheet1 "Sheet1!A1:D100" --col B --filter-type text --expected "Alice,Bob"
# 示例：筛选 C 列大于 90 的行
feishu sheet filter create TOKEN Sheet1 "Sheet1!A1:C100" --col C --filter-type number --expected "90" --compare-type greater

# 保护范围
feishu sheet protect   <url_or_token> <工作表> [--dimension ROWS|COLUMNS] [--start N] [--end N] [--lock-info <说明>]
feishu sheet unprotect <url_or_token> <工作表> <protect_id...>   # protectId 来自 protect 命令返回值

# 浮动图片
feishu sheet image add    <url_or_token> <工作表> --image-token <t> --cell <cell> [--width N] [--height N]
feishu sheet image list   <url_or_token> <工作表>
feishu sheet image delete <url_or_token> <工作表> <float_image_id>
```

---

## Windows Git Bash 引号与转义注意事项

Windows Git Bash（MINGW64）对引号和特殊字符有独特处理，**AI Agent 在 Windows 环境调用 CLI 时必须注意以下规则**：

### 1. `!` 符号 — history 展开

`!` 在双引号内会被 bash 当作 history 展开，导致参数被吞掉或报错。**所有包含 `!` 的 range 参数都受影响**。

```bash
# ❌ 错误：双引号内的 ! 被展开
feishu sheet read TOKEN "Sheet1!A1:D10"

# ✅ 方案 1：不加引号（range 参数不含空格时推荐）
feishu sheet read TOKEN Sheet1!A1:D10

# ✅ 方案 2：直接用 sheetId 拼接（推荐 AI Agent 使用）
feishu sheet read TOKEN 257432!A1:D10

# ✅ 方案 3（仅交互式终端）：先关闭 history 展开
set +H
feishu sheet read TOKEN "Sheet1!A1:D10"
```

> **AI Agent 最佳实践**：先通过 `feishu sheet sheets TOKEN` 获取 sheetId，然后用 `sheetId!A1:D10` 格式，不加引号。这样完全避开 `!` 转义问题。

### 2. 引号嵌套 — JSON 参数

`--values` 等需要传 JSON 的参数，在 Git Bash 中容易因引号嵌套导致解析异常。

```bash
# ✅ 正确：外层单引号，内层双引号
feishu sheet write TOKEN 257432!A1:B2 --values '[["名称","值"],["Alice",100]]'

# ❌ 错误：外层双引号，内层转义容易出错
feishu sheet write TOKEN 257432!A1:B2 --values "[["名称","值"]]"
```

### 3. 反斜杠 `\` — 路径与转义

Git Bash 会自动将某些参数中的 `\` 解释为转义。如果参数值恰好包含反斜杠或被 bash 误判为路径，可能被篡改。

```bash
# ✅ 用单引号包裹包含反斜杠的内容
feishu sheet find TOKEN Sheet1 'C:\path'
```

### 影响范围

| 环境 | `!` 展开 | 引号处理 | 需要注意 |
|------|---------|---------|---------|
| Git Bash (MINGW64) | ✅ 有问题 | ✅ 有问题 | **需要上述规避** |
| PowerShell | 无影响 | 无影响 | 无需特殊处理 |
| CMD | 无影响 | 无影响 | 无需特殊处理 |
| macOS / Linux | 无影响 | 无影响 | 无需特殊处理 |
