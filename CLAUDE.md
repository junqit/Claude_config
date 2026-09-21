# 全局指令

> 本文件只放**跨项目通用能力**的 skill / agent 派发规则。具体项目的分支命名、集成分支、工程约定等不写在这里，写在各项目自己的 `CLAUDE.md`。

## 自定义 Skill 优先级（~/.claude/skills）

以下 skill 是通用能力，跨项目可用。遇到对应场景**必须先调 skill**，不要直接用默认工具 / MCP 绕过：

### jira-attachments
- **触发**：Jira URL（jira-phone.mioffice.cn / jira.n.xiaomi.com）+ **仅读单 / 下载附件 / 拉 Jira 日志**（取工单完整内容 + 附件，**不分析、不修复**）。**若要分析 / 修复该 Jira bug，直接派 `jira_fix_single`，不走此 skill**。或「读 Jira 单 / 下载 Jira 附件 / 拉 Jira 日志」/需要工单完整内容（summary / description / 复现步骤 / 版本 / 问题时间 / comments）+ 附件。
- **规则**：先调 `jira-attachments` skill 读单 + 下载附件，不要直接调 Jira MCP 工具。下载目录由 caller（如 `jira_fix_single`）生成并传入，路径 = `~/Downloads/jira-bugfix-flow/<ISSUE_KEY>/`（与 jira_fix_single agent 一致）；独立调用（无 caller）回退到同一默认 `~/Downloads/jira-bugfix-flow/<ISSUE_KEY>/`（与 skill SKILL.md:19/46 实际默认一致）。

### jira_comment
- **触发**：Jira URL / issue key + 要求「给 Jira 加备注 / 评论」「comment on Jira」「把分析结论或修复信息发到 Jira 工单」。给定 issue key + 内容按团队既有格式 post 评论；不分析、不生成结论（内容由 caller 提供）。
- **规则**：用 `jira_comment` skill，按 host 选 MCP（`jira-phone.mioffice.cn`→JiraMCP `jira_add_comment` / `jira_edit_comment`；`jira.n.xiaomi.com`→old-mi-jira `jira_comment_add_tool`），按团队既有格式 post：场景一 修复备注 6 字段（根因分析 / 修复方案 / 影响范围 / 复测要求 / 修复信息=`yy/mm/dd hh:mm`+commit hash / 复测版本=date+1，禁代码 / 禁 URL / 禁自测字段）、场景二 非修复备注 三部分（关键日志整行原文 + 分析事件线 + 建议）。JiraMCP 实测渲染规则：禁星号加粗（`*`/`**` 被转义，强调用反引号）、禁嵌套列表（拍平→子项内联或顶格）、禁 `+`（用 `、`）。重写已有评论用 `jira_edit_comment`；session-expired 不伪造成功。

### code-analytic
- **触发**：定位 bug 根因——读关键方法全文、追完整父调用栈到入口、追子调用到状态变更根点、逐帧记录；或积累已分析代码到共享 context 索引。
- **规则**：用 `code-analytic` 方法论逐帧追踪，不凭零散 grep 下结论。

### feishu
- **触发**：飞书 URL（*.feishu.cn）或涉及飞书文档 / 知识库 / 云盘 / 多维表格 / 表格 / 幻灯片 / 权限 / 日历 / 任务的读写。
- **规则**：带飞书 URL 时仅用 `feishu` skill fetch，禁止 `WebFetch`；创建 / 修改走 feishu CLI。

### program-coder
- **触发**：给定 Swift 源文件路径 + 代码编辑需求（改逻辑 / 加功能 / 删代码 / 重构 / 整理格式 / format / clean up）。
- **规则**：编辑代码（按需求改逻辑 / 新增 / 删除 / 重构）+ 代码风格归一化（空白 / 换行 / 注释 / 缩进 / 冒号 / 签名对齐 / 访问控制顺序，按代码库测量多数风格）。标识符 / 字符串字面量 / `#if` 条件 / 注释语言不擅自改（除非需求要求）；最小 diff。
- **强制**：修改 Swift 代码（改逻辑 / 加功能 / 删代码 / 重构）时，**必须使用 /program-coder**（编辑代码 + 格式化），不论场景——手动 Edit、jira_fix_single、business_migration 或任何其他改码。不得直接 Edit 改 Swift 代码后不调 program-coder。

### mail-attachment
- **触发**：**仅当需要抓取 mail 信息时**——搜邮件 + 下载附件 / 拿下载地址（symbol zip / dSYM 等）/ 需要邮件里某文件（dSYM / symbol / 日志 zip）的下载链接。`mail.xiaomi.com` URL 只有在要下载附件 / 提取链接时才触发；仅阅读邮件正文、URL 仅作上下文、或仅提及 dSYM/symbol/CI 构建号而无实际搜邮件+下载任务时，**不触发**。
- **规则**：先调 `mail-attachment` 驱动已登录的 Safari 搜邮件 + 拿附件 / 下载地址；内网直链（FDS 等）用 curl，CAS 站走 Safari 同源 blob fetch；不直接 WebFetch / 裸 curl 绕过。

## 自定义 Agent 派发优先级（~/.claude/agents）

以下 agent 是通用能力，跨项目可用。遇到对应场景**优先用 Agent 工具 dispatch 对应 agent**，在 prompt 里指定模式 / 必要参数：

### jira_fix_single
- **触发**：单个 Jira bug 的修复 / 分析 / 端到端处理（读单 + 分析日志和调用栈 + **崩溃 `.ips` 符号化（dSYM 经 `mail-attachment` 从 CI 邮件取）** + 改码用 `program-coder`（编辑代码逻辑 + 格式化）+ 飞书自测报告 + 推独立分支 + Jira 评论）。
- **模式**：`仅分析` / `仅修复` / `完整`（默认），dispatch prompt 里写明。
- **规则**：分析 / 修复 / 端到端处理单个 Jira bug（含 Jira URL）**直接派 `jira_fix_single`**，agent 内部自走读单 + 下载附件 + `.ips` 符号化 + 调用栈分析（caller **不必先调 `jira-attachments` skill**）；仅读单 / 拉附件（不分析、不修复）才走 `jira-attachments` skill，不派 agent。从**当前工作分支**切独立 fix 分支，不从其他集成分支切（避免夹带分叉冲突）。

### business_migration
- **触发**：「业务移植 / 跨平台对齐 / 把改动移植到另一端 / 按分支同步功能到另一端」。
- **规则**：dispatch `business_migration`，目标 = 当前工作目录，源工程自动发现。模式：`仅分析` / `完整`（默认）/ `发布`（含 push）。SOURCE_DIR 缺省时自动发现与目标平台不同的兄弟工程。

### pod_version_generator
- **触发**：「pod 版本生成 / 组件发新版 / 给 commit 接入的库打 tag 发版」。
- **规则**：dispatch `pod_version_generator`，**必须提供 SOURCE_REPOS_DIR 与 PODSPEC_REPOS**（podspec 仓库列表，无内置默认）。模式：`准备`（默认）/ `发布`（含 push）。

### miwear-ufi-anaylytic
- **触发**：「拉反馈日志 / 下载反馈日志并解密 / 反馈查找→日志下载→解密 / miwear-ufi」（可带应用版本号 / 具体问题 / 反馈平台，均可选）。
- **参数**（**全部可选，可不传**）：`appVersion` 应用版本号、`issue` 具体问题名或 tagId、`platform` 反馈平台（默认 `wear`）、`pageSize` 每页条目数（默认 `100`）、`feedbackId` 反馈编号（单条模式，跳过列表只下该条）。不传 `appVersion`/`issue` 则该维度不过滤（更宽查询）；完全不传 = 拉 wear 平台最新 100 条反馈。
- **规则**：dispatch `miwear-ufi-anaylytic`，从 feedback.pt.xiaomi.com 按版本+问题+平台拉**全量列**反馈列表存 manifest.tsv → 逐条下载日志（logDownloadBox 页面加载自动下载，文件夹改名为反馈编号，**不点「下载所有」按钮**——合成 click 会导航到脱敏坏 URL）→ 逆向解密工具客户端 AES（key 经 `/log/decrypt/wear/decryptLogKeys` 同源 POST 取，本地 node AES-256-CBC/IV=`A-16-Byte-String`/分块格式解密，解密文件放 `decrypted/` 子目录）→ 递归处理打包压缩包内嵌套加密日志至不动点。前置：Safari 登录 feedback.pt + `AllowJavaScriptFromAppleEvents` ON（agent 不能自开，caller 手动 `! defaults write com.apple.Safari AllowJavaScriptFromAppleEvents -bool true`；任务结束 agent 自动 `defaults delete` 还原）。**只采集+解密，不分析日志内容、不改码、不 commit**（分析交给 `ufi-analytic` / `jira_fix_single`）。
