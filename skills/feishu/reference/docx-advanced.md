# 飞书文档高级块操作参考

`feishu docx update` 已覆盖大多数日常编辑需求并支持 URL。
以下底层命令适用于需要**精确块级控制**的场景（只接受 `doc_token`，不支持 URL）。

---

## 写入 / 追加

等价于 `update --mode overwrite/append`，适用于需要裸 token 的场景：

```bash
feishu docx write  <doc_token> -c "# 完整内容"   # 替换整篇（破坏性，图片/白板将丢失）
feishu docx append <doc_token> -c "## 新章节"    # 追加到末尾
feishu docx write  <doc_token> -f content.md      # 从文件读取
```

---

## 块操作

### 读取块

```bash
feishu docx blocks <doc_token>                      # 列出所有块（含 block_id、block_type）
feishu docx block  <doc_token> <block_id>           # 获取单个块的完整数据
```

### 单块修改

```bash
feishu docx update-block <doc_token> <block_id> -c "文本"    # 更新文本块（type=2）
feishu docx delete-block <doc_token> <block_id>               # 删除单个块
feishu docx insert <doc_token> <after_block_id> -c "内容"    # 在指定块之后插入内容
```

> 删除单个已知 block ID 请用 `delete-block`；删除多个块请用 `delete-blocks`。

### 批量块操作

#### `delete-blocks` — 范围删除 或 ID 列表删除

**模式 A：按父块下的索引范围删除**

```bash
feishu docx delete-blocks <doc_token> <parent_id> --start 2 --end 5   # 删除索引 [2, 5)
feishu docx delete-blocks <doc_token> <parent_id> --start 3           # 从索引 3 删到末尾
feishu docx delete-blocks <doc_token> <parent_id> --all               # 清空父块下所有子块
```

**模式 B：按 block ID 列表删除（逗号分隔，至少两个 ID）**

```bash
feishu docx delete-blocks <doc_token> blockA,blockB,blockC
```

> 返回：`{ blocks_deleted: N }`
> ⚠️ 单个 block ID 请使用 `delete-block`，`delete-blocks` 的 ID 列表模式需要逗号分隔的多个 ID。

#### `batch-update-blocks` — 批量更新文本块

一次更新多个 **文本块**（block_type=2）的内容，各块并行更新，失败项非致命（收入 `failed` 数组）：

```bash
feishu docx batch-update-blocks <doc_token> \
  --records '[{"block_id":"xxx","content":"新文本"},{"block_id":"yyy","content":"另一段"}]'

feishu docx batch-update-blocks <doc_token> -f updates.json   # 从文件读取
```

records 格式：`[{ "block_id": "<id>", "content": "<纯文本>" }]`

返回：`{ updated: N, failed: [{ block_id, error }] }`

> ⚠️ 只支持文本块（type=2）。非文本块会直接报错进入 `failed`，不影响其他条目。

---

## 表格操作

```bash
feishu docx create-table <doc_token> --rows 3 --cols 4
feishu docx create-table <doc_token> --rows 2 --cols 2 --values '[["A1","B1"],["A2","B2"]]'
feishu docx write-table-cells <doc_token> <table_block_id> --values '[["A1","B1"]]'
feishu docx insert-table-row    <doc_token> <table_block_id> --index 2
feishu docx insert-table-column <doc_token> <table_block_id> --index 1
feishu docx delete-table-rows   <doc_token> <table_block_id> --start 0 --count 2
feishu docx delete-table-columns <doc_token> <table_block_id> --start 1
feishu docx merge-table-cells   <doc_token> <table_block_id> \
  --row-start 0 --row-end 1 --col-start 0 --col-end 1
```

> ⚠️ `merge-table-cells` 只能用于**没有**已合并单元格的表格。

---

## 上传图片 / 文件 / 视频

```bash
feishu docx upload-image <doc_token> --url "https://example.com/image.png"
feishu docx upload-image <doc_token> --file /path/to/image.png
feishu docx upload-file  <doc_token> --url "https://example.com/report.pdf"
feishu docx upload-file  <doc_token> --file /path/to/report.pdf --filename "Q1-report.pdf"
feishu docx upload-video <doc_token> --file /path/to/demo.mp4
feishu docx upload-video <doc_token> --url "https://example.com/demo.mp4" --filename "产品演示.mp4"
```

`upload-video` 会创建展开的视频卡片（View 块 view_type:2），飞书客户端自动渲染为视频播放器。

---

## 彩色文字

语法：`[颜色]文字[/颜色]`，颜色：`red` `orange` `yellow` `green` `blue` `purple` `gray`

```bash
feishu docx color-text <doc_token> <block_id> -c "[red]错误[/red] [green]正常[/green]"
```

---

## 权限范围

```bash
feishu docx scopes   # 查看当前应用已授权的权限范围
```
