# 多维表格参考文档

筛选语法、批量操作、字段类型与 Property、结构管理、视图管理、错误码与限制。

---

## 筛选语法

配合 `feishu bitable search ... --filter "表达式"` 使用。

| 语法 | 含义 |
|------|------|
| `字段=值` | 等于 |
| `字段=值1,值2` | 等于其中之一（仅部分字段类型支持多值匹配，如数字；**单选字段不支持**） |
| `字段!=值` | 不等于 |
| `字段>10` | 大于 |
| `字段>=10` | 大于等于 |
| `字段<100` | 小于 |
| `字段<=100` | 小于等于 |
| `字段~关键词` | 包含（contains） |
| `字段!~关键词` | 不包含（doesNotContain） |
| `字段?` | 不为空 |
| `字段!?` | 为空 |

> **限制：** 字段名中包含 `=`、`~`、`?` 的无法使用 `--filter`，请改用 `--filter-json`。

### --filter-json 完整 operator 列表

| operator | 含义 | 支持字段 | value 格式 |
|----------|------|----------|-----------|
| `is` | 等于 | 所有 | `["值"]` |
| `isNot` | 不等于 | 除日期外 | `["值"]` |
| `contains` | 包含 | 除日期外 | `["值1", "值2"]` |
| `doesNotContain` | 不包含 | 除日期外 | `["值"]` |
| `isEmpty` | 为空 | 所有 | `[]`（**必须传空数组**） |
| `isNotEmpty` | 不为空 | 所有 | `[]`（**必须传空数组**） |
| `isGreater` | 大于 | 数字、日期 | `["值"]` |
| `isGreaterEqual` | 大于等于 | 数字 | `["值"]` |
| `isLess` | 小于 | 数字、日期 | `["值"]` |
| `isLessEqual` | 小于等于 | 数字 | `["值"]` |

> ⚠️ `isEmpty`/`isNotEmpty` 必须传 `value: []`（空数组），否则 API 返回 400。

### 日期字段特殊值

```bash
feishu bitable search appXXX tblXXX \
  --filter-json '{"conjunction":"and","conditions":[{"field_name":"截止日期","operator":"isLess","value":["Today"]}]}'
```

| 特殊值 | 含义 |
|--------|------|
| `"Today"` | 今天 |
| `"Tomorrow"` | 明天 |
| `"Yesterday"` | 昨天 |
| `"CurrentWeek"` | 本周 |
| `"LastWeek"` | 上周 |
| `"TheLastWeek"` | 过去七天 |
| `"TheNextWeek"` | 未来七天 |
| `["ExactDate", "时间戳ms"]` | 指定具体日期（毫秒时间戳） |

### 筛选示例

```bash
# 查找张三负责的进行中任务
feishu bitable search appXXX tblXXX \
  --filter "状态=进行中" \
  --filter "负责人=张三"

# 查找 P0/P1 项，按创建时间倒序
feishu bitable search appXXX tblXXX \
  --filter "优先级=P0,P1" \
  --sort "创建时间 desc" \
  --fields "名称,优先级,负责人,状态"

# 查找描述为空的记录
feishu bitable search appXXX tblXXX --filter "描述!?"

# 复杂 OR 条件
feishu bitable search appXXX tblXXX \
  --filter-json '{"conjunction":"or","conditions":[{"field_name":"状态","operator":"is","value":["进行中"]},{"field_name":"状态","operator":"is","value":["待处理"]}]}'
```

---

## 批量操作（每次最多 500 条）

`batch-create` 和 `batch-update` 支持 `--records` 内联 JSON 或 `-f` 文件读取（互斥）。大数据量推荐 `-f`。

```bash
# 批量创建：字段对象数组（CLI 自动封装 {fields:...}）
feishu bitable batch-create <app_token> <table_id> \
  --records '[{"名称":"任务1","状态":"待处理"},{"名称":"任务2","状态":"进行中"}]'
feishu bitable batch-create <app_token> <table_id> -f records.json

# 批量更新：必须带 "id"（record_id）和 "fields"
feishu bitable batch-update <app_token> <table_id> \
  --records '[{"id":"recXXX","fields":{"状态":"已完成"}},{"id":"recYYY","fields":{"状态":"已完成"}}]'
feishu bitable batch-update <app_token> <table_id> -f updates.json

# 批量删除：逗号分隔 ID（不是 JSON）
feishu bitable batch-delete <app_token> <table_id> recA,recB,recC
```

**各命令的 `--records` 格式区别：**

| 命令 | 格式 |
|------|------|
| `batch-create` | `[{"字段":"值"}, ...]` — 只传字段对象 |
| `batch-update` | `[{"id":"recXXX","fields":{...}}, ...]` — 必须带 `id` |
| `batch-delete` | `recA,recB,recC` — 逗号分隔 ID（不是 JSON） |

> `batch-delete` 是原子操作——要么全部删除，要么全部不删。

---

## 字段类型与 Property

> **快速查 type ID：**
> `1`=文本 `2`=数字 `3`=单选 `4`=多选 `5`=日期 `7`=复选框 `11`=人员 `13`=电话
> `15`=超链接 `17`=附件 `18`=单向关联 `19`=查找引用 `20`=公式 `21`=双向关联
> `22`=地理位置 `23`=群组
> `1001`=创建时间 `1002`=最后更新时间 `1003`=创建人 `1004`=修改人 `1005`=自动编号

### 基础字段

**文本（type=1）**

```bash
feishu bitable create-field appXXX tblXXX --name "备注" --type 1
# property 可省略

# 变体：条码
feishu bitable create-field appXXX tblXXX --name "商品条码" --type 1 \
  --property '{"allowed_edit_modes":{"manual":false,"scan":true}}'
```

**数字（type=2）**

```bash
feishu bitable create-field appXXX tblXXX --name "工时" --type 2 \
  --property '{"formatter":"0.00"}'
```

`formatter` 可选值：`"0"` 整数 · `"0.0"` 一位小数 · `"0.00"` 两位小数 · `"0,000"` 千分位 · `"0.00%"` 百分比

```bash
# 变体：进度条
feishu bitable create-field appXXX tblXXX --name "完成度" --type 2 \
  --ui-type Progress --property '{"formatter":"0"}'

# 变体：货币
feishu bitable create-field appXXX tblXXX --name "预算" --type 2 \
  --ui-type Currency --property '{"currency_code":"CNY","formatter":"0,000.00"}'
# currency_code 可选：CNY USD EUR GBP JPY HKD 等

# 变体：评分
feishu bitable create-field appXXX tblXXX --name "满意度" --type 2 \
  --ui-type Rating --property '{"min":1,"max":5,"rating":{"symbol":"star"}}'
# symbol 可选：star heart thumbsup fire smile lightning flower number
```

**日期（type=5）**

```bash
feishu bitable create-field appXXX tblXXX --name "截止日期" --type 5 \
  --property '{"date_formatter":"yyyy-MM-dd HH:mm","auto_fill":false}'
```

`date_formatter` 可选：`"yyyy/MM/dd"` · `"yyyy-MM-dd HH:mm"` · `"MM-dd"` · `"MM/dd/yyyy"` · `"dd/MM/yyyy"` · `"MM月DD日"` · `"yyyy年MM月DD日"`

**复选框（type=7）** / **电话（type=13）**

```bash
feishu bitable create-field appXXX tblXXX --name "是否完成" --type 7  # property 可省略
feishu bitable create-field appXXX tblXXX --name "联系电话" --type 13 # property 可省略
```

---

### 选择字段

**单选（type=3）**

```bash
feishu bitable create-field appXXX tblXXX --name "状态" --type 3 \
  --property '{"options":[{"name":"待开始","color":0},{"name":"进行中","color":20},{"name":"已完成","color":10}]}'
```

颜色编号范围 0-54（0=红色，10=绿色，20=蓝色）。创建时不传 `id`，系统自动生成。

> ⚠️ **更新选项时**：必须保留已有选项的 `id`，新增选项只传 `name` 和 `color`。

**多选（type=4）** — 格式与单选相同：

```bash
feishu bitable create-field appXXX tblXXX --name "标签" --type 4 \
  --property '{"options":[{"name":"紧急","color":0},{"name":"重要","color":20}]}'
```

---

### 关系字段

**人员（type=11）**

```bash
feishu bitable create-field appXXX tblXXX --name "负责人" --type 11 \
  --property '{"multiple":false}'
# multiple 默认 true。写入格式：[{"id": "ou_xxx"}]
```

**超链接（type=15）**

```bash
feishu bitable create-field appXXX tblXXX --name "参考链接" --type 15
# ⚠️ 不要传 --property，包括空对象 {}，否则报错 1254087
# 写入格式：{"text": "显示文本", "link": "https://..."}
```

**附件（type=17）**

```bash
feishu bitable create-field appXXX tblXXX --name "附件" --type 17
# 写入前必须先 upload-attachment 获取 file_token
# 写入格式：[{"file_token": "xxx"}]
```

**单向关联（type=18）**

```bash
feishu bitable create-field appXXX tblXXX --name "关联任务" --type 18 \
  --property '{"table_id":"tblAnotherTable","multiple":true}'
# 写入格式：{"link_record_ids": ["recXXX", "recYYY"]}
```

**双向关联（type=21）**

```bash
feishu bitable create-field appXXX tblXXX --name "相关项目" --type 21 \
  --property '{"table_id":"tblAnotherTable","back_field_name":"关联的任务","multiple":true}'
# 创建后对方表自动生成对应字段；更新会同步对方表
```

**地理位置（type=22）**

```bash
feishu bitable create-field appXXX tblXXX --name "办公地址" --type 22 \
  --property '{"location":{"input_type":"not_limit"}}'
# input_type：only_mobile=仅移动端定位，not_limit=无限制
# 写入格式："116.3,40.0"（经度,纬度 字符串）
```

**群组（type=23）**

```bash
feishu bitable create-field appXXX tblXXX --name "协作群" --type 23
# 写入格式：[{"id": "oc_xxx"}]（单元格最多 10 个群组）
```

---

### 高级字段

**公式（type=20）**

```bash
feishu bitable create-field appXXX tblXXX --name "总价" --type 20
# ⚠️ 公式表达式必须在飞书客户端设置，API 不支持
# 只读字段，无法通过写接口设置值
```

**查找引用（type=19）** — 只读，由关联字段自动生成。

---

### 系统字段（只读）

**创建时间（type=1001）** / **最后更新时间（type=1002）**

```bash
feishu bitable create-field appXXX tblXXX --name "创建于" --type 1001 \
  --property '{"date_formatter":"yyyy-MM-dd HH:mm"}'
# 系统自动填充，只读
```

**自动编号（type=1005）**

```bash
# 纯自增数字
feishu bitable create-field appXXX tblXXX --name "编号" --type 1005 \
  --property '{"auto_serial":{"type":"auto_increment_number"}}'

# 自定义编号（格式：WO-20240226-0001）
feishu bitable create-field appXXX tblXXX --name "工单号" --type 1005 \
  --property '{"auto_serial":{"type":"custom","options":[
    {"type":"fixed_text","value":"WO-"},
    {"type":"created_time","value":"yyyyMMdd"},
    {"type":"system_number","value":"4"}
  ]}}'
# options 规则类型：fixed_text（最多20字符）created_time  system_number（位数1-9）
```

---

### 字段操作注意事项

| 规则 | 说明 |
|------|------|
| 类型不可变 | 字段类型创建后不能修改 |
| 主字段不可删 | 每张表的主字段（第一列）不能删除 |
| 更新选项需带 id | 单选/多选更新时，已有选项必须保留原 `id` |
| 超链接不传 property | 传空对象 `{}` 也会报错 1254087，必须完全省略 |
| 公式表达式只能客户端设置 | `create-field` 时不支持设置公式表达式 |

---

## 结构管理

### 创建应用

```bash
# 基础创建（默认存入个人知识库）
feishu bitable create-app "表格名称"

# 在知识库节点下创建
feishu bitable create-app "表格名称" --wiki-node wikcnXXX

# 一步到位：创建 + 自定义字段
feishu bitable create-app "项目追踪" --wiki-node wikcnXXX \
  --fields '[{"field_name":"名称","type":1},{"field_name":"优先级","type":3,"property":{"options":[{"name":"P0"},{"name":"P1"}]}}]'

# 放入云盘文件夹
feishu bitable create-app "表格名称" --folder fldcnXXX
feishu bitable create-app "客户表" --folder fldcnXXX -f fields.json
```

> `create-app` 会自动清理默认空行，无需手动清理。

### 建表

```bash
# 一次性定义所有字段（推荐）
feishu bitable create-table <app_token> --name "客户表" \
  --default-view-name "所有客户" \
  --fields '[{"field_name":"负责人","type":11,"property":{"multiple":false}},{"field_name":"状态","type":3,"property":{"options":[{"name":"进行中"},{"name":"已完成"}]}}]'

# 先建表，再逐步添加字段
feishu bitable create-table <app_token> --name "客户表"
feishu bitable create-field <app_token> <table_id> --name "状态" --type 3 \
  --property '{"options":[{"name":"进行中"},{"name":"已完成"}]}'

# 批量创建字段
feishu bitable batch-create-fields <app_token> <table_id> -f fields.json
```

### 数据表 / 字段 / 应用管理

```bash
feishu bitable rename-table <app_token> <table_id> --name "Q2 OKR"
feishu bitable delete-table <app_token> <table_id>           # 不可撤销

feishu bitable update-field <app_token> <table_id> <field_id> --name "项目名称"
feishu bitable update-field <app_token> <table_id> <field_id> \
  --property '{"options":[{"name":"高"},{"name":"中"},{"name":"低"}]}'
feishu bitable delete-field <app_token> <table_id> <field_id>

feishu bitable update-app <app_token> --name "产品需求池"
feishu bitable copy-app <app_token> --name "Q3 追踪" --folder fldcnXXX  # 只复制结构，不含数据
```

---

## 完整工作流

**查询和写入数据：**

1. `bitable meta <url_or_token>` → 获取 `app_token`、`table_id`
2. `bitable fields <app_token> <table_id>` → 确认字段名称和类型
3. `bitable search ... --filter "..."` → 按条件查询
4. `batch-create -f data.json` / `batch-update -f updates.json` / `batch-delete` → 写入

**从零搭建（推荐：一步到位）：**

```bash
# 步骤 1：创建应用 + 自定义字段
feishu bitable create-app "项目追踪" --wiki-node wikcnXXX \
  --fields '[
    {"field_name":"名称","type":1},
    {"field_name":"优先级","type":3,"property":{"options":[{"name":"P0"},{"name":"P1"},{"name":"P2"}]}},
    {"field_name":"负责人","type":11},
    {"field_name":"截止日期","type":5}
  ]'
# → app_token=BascXXX, table_id=tblYYY

# 步骤 2：批量导入数据
feishu bitable batch-create BascXXX tblYYY -f records.json
```

---

## 视图管理

```bash
feishu bitable views <app_token> <table_id>
feishu bitable create-view <app_token> <table_id> --name "我的视图" --type grid
feishu bitable delete-view <app_token> <table_id> <view_id>

# 按视图查询（应用视图的筛选条件和可见字段）
feishu bitable records <app_token> <table_id> --view-id vewXXX
feishu bitable search  <app_token> <table_id> --view-id vewXXX --filter "状态=进行中"
```

视图类型：`grid` / `kanban` / `gallery` / `gantt` / `form`

---

## 附件上传

必须先上传获取 `file_token`，再写入记录。

```bash
feishu bitable upload-attachment <app_token> <table_id> --file ./report.pdf
feishu bitable upload-attachment <app_token> <table_id> --url "https://example.com/doc.pdf"
feishu bitable upload-attachment <app_token> <table_id> --file ./img.png --type image
# → { file_token, file_name, size }

feishu bitable create-record appXXX tblXXX \
  --fields '{"附件": [{"file_token": "DRiFbwaKsoZaLax4WKZbEGCccoe"}]}'
```

> 单次最大 20MB。超出请在飞书客户端直接上传。

---

## 错误码排查

**记录操作错误码：**

| 错误码 | 含义 | 解决方案 |
|--------|------|---------|
| `1254064` | 日期字段格式错误 | 改用毫秒时间戳，不能用字符串或秒级时间戳 |
| `1254066` | 人员字段格式错误 | 必须传 `[{"id":"ou_xxx"}]` |
| `1254068` | 超链接字段格式错误 | 必须传 `{"text":"...","link":"..."}` 对象 |
| `1254015` | 字段类型不匹配 | 先执行 `fields` 确认字段类型 |
| `1254045` | 字段名不存在 | 检查字段名大小写和空格 |
| `1254104` | 批量操作超过 500 条 | 分批调用，每批 ≤ 500 条 |
| `1254291` | 并发写入冲突 | 串行调用，间隔 0.5-1 秒 |
| `1254303` | 附件未挂载到当前表格 | 先用 `upload-attachment` 上传 |

**字段 Property 错误码：**

| 错误码 | 字段类型 | 常见原因 |
|--------|---------|---------|
| `1254080` | 文本 | property 结构错误 |
| `1254081` | 数字 | `formatter` 格式错误 |
| `1254082` | 单选 | `options` 数组格式错误 |
| `1254083` | 多选 | `options` 数组格式错误 |
| `1254084` | 日期 | `date_formatter` 错误 |
| `1254086` | 人员 | `multiple` 格式错误 |
| `1254087` | 超链接 | 传了 `property` 参数（必须完全省略） |
| `1254089` | 单向关联 | `table_id` 不存在或格式错误 |
| `1254092` | 双向关联 | `table_id` 或 `back_field_name` 错误 |

---

## 并发写入限制

飞书多维表格**不支持对同一数据表的并发写操作**。解决方法：
- 写操作串行执行（一个完成后再发下一个）
- 相邻写操作之间加 0.5-1 秒延迟
- 优先使用批量接口（`batch-create` / `batch-update` / `batch-delete`）减少调用次数

---

## 使用限制速查

| 对象 | 上限 |
|------|------|
| 单个 App 的数据表 + 仪表盘 | 100 |
| 单个数据表的记录数 | 20,000 |
| 单个数据表的字段数 | 300 |
| 单个数据表的视图数 | 200 |
| 单次批量操作（create/update/delete） | 500 条 |
| 单元格文本 | 10 万字符 |
| 单选/多选选项数 | 20,000 |
| 单元格附件数 | 100 |
| 单元格人员数 | 1,000 |
| 单次上传附件大小 | 20 MB |

---

## 字段创建变体（create-field / batch-create-fields）

```bash
# 普通文本字段
feishu bitable create-field <app_token> <table_id> --name "备注" --type 1

# 数字字段（type=2）
# formatter 合法值："0"=整数 "0.0"=一位小数 "0.00"=两位小数 "0,000"=千分位 "0.00%"=百分比
feishu bitable create-field <app_token> <table_id> --name "数量" --type 2 \
  --property '{"formatter":"0,000"}'

# 数字变体：进度条（--ui-type Progress）
feishu bitable create-field <app_token> <table_id> --name "完成度" --type 2 \
  --ui-type Progress --property '{"formatter":"0"}'

# 数字变体：货币
feishu bitable create-field <app_token> <table_id> --name "预算" --type 2 \
  --ui-type Currency --property '{"currency_code":"CNY","formatter":"0,000.00"}'

# 数字变体：评分
feishu bitable create-field <app_token> <table_id> --name "满意度" --type 2 \
  --ui-type Rating --property '{"min":1,"max":5,"rating":{"symbol":"star"}}'

# 批量创建字段（从文件读取时 --fields 与 -f 互斥）
feishu bitable batch-create-fields <app_token> <table_id> \
  --fields '[{"field_name":"状态","type":3,"property":{"options":[{"name":"进行中"}]}},{"field_name":"负责人","type":11}]'
feishu bitable batch-create-fields <app_token> <table_id> -f fields.json
```

---

## 批量表管理

```bash
feishu bitable batch-create-tables <app_token> --tables '[{"name":"T1"},{"name":"T2"}]'
feishu bitable batch-create-tables <app_token> -f tables.json
feishu bitable batch-delete-tables <app_token> tblA,tblB
```

---

## 仪表盘

```bash
feishu bitable dashboard list <app_token>
feishu bitable dashboard copy <app_token> <block_id> [--name "副本"]
```

---

## 角色权限

```bash
feishu bitable role create <app_token> --name "编辑者" [--table-perm <json>]
feishu bitable role list <app_token>
feishu bitable role update <app_token> <role_id> [--name "新名"] [--table-perm <json>]
feishu bitable role delete <app_token> <role_id>
feishu bitable role members <app_token> <role_id>
feishu bitable role add-member <app_token> <role_id> --member-id ou_xxx
feishu bitable role remove-member <app_token> <role_id> ou_xxx
```

---

## 表单

表单操作需要 `form_id`，可通过 `feishu bitable views` 获取表单视图 ID。

```bash
feishu bitable form get <app_token> <table_id> <form_id>
feishu bitable form update <app_token> <table_id> <form_id> [--name "问卷"] [--description "描述"] [--shared]
feishu bitable form fields <app_token> <table_id> <form_id>
feishu bitable form update-field <app_token> <table_id> <form_id> <field_id> \
  [--visible] [--required] [--description "说明"]
```

---

## 自动化工作流

```bash
feishu bitable workflow list <app_token>
feishu bitable workflow update <app_token> <workflow_id> --enable   # 启用
feishu bitable workflow update <app_token> <workflow_id> --disable  # 禁用
```
