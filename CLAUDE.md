# 全局指令

> 本文件只放**跨项目通用能力**的 skill / agent 派发规则。具体项目的分支命名、集成分支、工程约定等不写在这里，写在各项目自己的 `CLAUDE.md`。

## 自定义 Skill 优先级（~/.claude/skills）

以下 skill 是通用能力，跨项目可用。遇到对应场景**必须先调 skill**，不要直接用默认工具 / MCP 绕过：

### jira-attachments
- **触发**：Jira URL（jira-phone.mioffice.cn / jira.n.xiaomi.com）或「读 Jira 单 / 下载 Jira 附件 / 拉 Jira 日志」/需要工单完整内容（summary / description / 复现步骤 / 版本 / 问题时间 / comments）+ 附件。
- **规则**：先调 `jira-attachments` skill 读单 + 下载附件，不要直接调 Jira MCP 工具。下载目录由 caller（如 `jira_fix_single`）生成并传入；独立调用（无 caller）回退到 `~/Downloads/Skill/jira-attachments/<ISSUE_KEY>/`。

### code-analytic
- **触发**：定位 bug 根因——读关键方法全文、追完整父调用栈到入口、追子调用到状态变更根点、逐帧记录；或积累已分析代码到共享 context 索引。
- **规则**：用 `code-analytic` 方法论逐帧追踪，不凭零散 grep 下结论。

### feishu
- **触发**：飞书 URL（*.feishu.cn）或涉及飞书文档 / 知识库 / 云盘 / 多维表格 / 表格 / 幻灯片 / 权限 / 日历 / 任务的读写。
- **规则**：带飞书 URL 时仅用 `feishu` skill fetch，禁止 `WebFetch`；创建 / 修改走 feishu CLI。

### program-coder
- **触发**：给定 Swift 源文件路径，要求「整理格式 / format / clean up」。
- **规则**：纯格式化（空白 / 换行 / 注释 / 缩进 / 冒号 / 签名对齐 / 访问控制顺序），不改逻辑。

### mail-attachment
- **触发**：mail.xiaomi.com（OWA）URL 或「搜邮件 + 下载附件 / 拿下载地址 / symbol zip / dSYM 下载地址」/ 需要邮件里某个文件（dSYM / symbol / 日志 zip）的下载链接。
- **规则**：先调 `mail-attachment` 驱动已登录的 Safari 搜邮件 + 拿附件 / 下载地址；内网直链（FDS 等）用 curl，CAS 站走 Safari 同源 blob fetch；不直接 WebFetch / 裸 curl 绕过。

## 自定义 Agent 派发优先级（~/.claude/agents）

以下 agent 是通用能力，跨项目可用。遇到对应场景**优先用 Agent 工具 dispatch 对应 agent**，在 prompt 里指定模式 / 必要参数：

### jira_fix_single
- **触发**：单个 Jira bug 的修复 / 分析 / 端到端处理（读单 + 分析日志和调用栈 + **崩溃 `.ips` 符号化（dSYM 经 `mail-attachment` 从 CI 邮件取）** + 改码（修复后用 `program-coder` 纯格式化）+ 飞书自测报告 + 推独立分支 + Jira 评论）。
- **模式**：`仅分析` / `仅修复` / `完整`（默认），dispatch prompt 里写明。
- **规则**：修 bug 派 `jira_fix_single`；仅读单 / 拉附件走 `jira-attachments` skill，不派 agent。从**当前工作分支**切独立 fix 分支，不从其他集成分支切（避免夹带分叉冲突）。

### business_migration
- **触发**：「业务移植 / 跨平台对齐 / 把改动移植到另一端 / 按分支同步功能到另一端」。
- **规则**：dispatch `business_migration`，目标 = 当前工作目录，源工程自动发现。模式：`仅分析` / `完整`（默认）/ `发布`（含 push）。SOURCE_DIR 缺省时自动发现与目标平台不同的兄弟工程。

### pod_version_generator
- **触发**：「pod 版本生成 / 组件发新版 / 给 commit 接入的库打 tag 发版」。
- **规则**：dispatch `pod_version_generator`，**必须提供 SOURCE_REPOS_DIR 与 PODSPEC_REPOS**（podspec 仓库列表，无内置默认）。模式：`准备`（默认）/ `发布`（含 push）。
