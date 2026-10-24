# 架构与同步设计

本文说明任务工作台、CalDAV VTODO 同步、日历事件、统计和 AI 助手的实现方式。

## 1. 模块划分

```text
cmd/caldav-free/       启动参数、优雅关闭
internal/auth/         PBKDF2 密码、随机 token
internal/store/        用户、日历、对象、同步日志、任务、文件夹、过滤器、统计
internal/ical/         iCalendar 解析/序列化、时区、RRULE 展开
internal/dav/          CalDAV/WebDAV HTTP 处理
internal/tasks/        自然语言解析、下一次重复计算
internal/tasksync/     任务 ↔ VTODO 双向同步
internal/reminders/    服务端提醒调度器、VAPID、Web Push、邮件
internal/mailer/       SMTP 配置、邮件发送
internal/web/          管理后台、任务 API、日历事件、统计、AI
web/                   Vue 3 + Vite+ + Arco 管理后台
```

工作台路由：智能视图、四象限、统计、日历等使用独立路径（`/tasks/today`、`/tasks/matrix`、`/tasks/calendar`、`/tasks/list/:id` 等），共用 `TaskWorkspaceView` 外壳；路由 meta 决定视图和模式，详情/搜索等临时状态仍使用查询参数。旧版 `?view=` 链接会自动迁移。

任务工作台前端组件：

```text
web/src/views/TaskWorkspaceView.vue
web/src/components/tasks/TaskSidebar.vue
web/src/components/tasks/TaskRow.vue
web/src/components/tasks/TaskDetail.vue
web/src/components/tasks/TaskCalendar.vue
web/src/components/tasks/TaskStatsPanel.vue
web/src/components/tasks/TaskSummaryPanel.vue
web/src/components/tasks/TaskAIPanel.vue
web/src/components/tasks/ReminderSettingsDialog.vue
web/public/sw.js       Service Worker（接收 push 并显示通知）
```

## 2. 数据表

### 任务相关

| 表 | 作用 |
| --- | --- |
| `task_folders` | 清单文件夹 |
| `task_lists` | 清单；每用户一个收集箱；`folder_id` 归属文件夹 |
| `tasks` | 任务、日期、重复、提醒、指派人、软删除、VTODO 同步字段 |
| `task_filters` | 保存过滤器；条件以 JSON 存储 |
| `task_list_shares` | 清单共享成员与角色；list_id + user_id 唯一 |
| `notifications` | 站内协作通知：类型、标题、正文、URL、任务、已读状态；SSE 实时推送未读数 |
| `event_snoozes` | 日程稍后提醒：目标日历/事件、原通知、提醒时间、发送状态 |
| `task_snoozes` | 任务稍后提醒：任务、原通知、提醒时间、发送状态 |
| `task_activities` | 任务动态：创建、指派、完成/重新打开 |
| `task_comments` | 任务评论：任务、作者、正文、创建时间 |
| `task_tag_colors` | 用户标签颜色；按用户名+标签名唯一 |
| `matrix_views` | 四象限视图名称、simple/complex/custom 规则（含条件组/名称/颜色）JSON、排序 |
| `matrix_rule_templates` | 用户保存的四象限规则模板 |
| `habits` | 习惯定义、频率、目标、分组、提醒、样式 |
| `habit_sections` | 习惯自定义分组 |
| `habit_checkins` | 按日期唯一的习惯打卡记录 |
| `habit_records` | 习惯打卡日志 |
| `habit_preferences` | 习惯显示与分类偏好 |
| `comment_attachments` | 评论附件：元数据 + SQLite BLOB（单文件 ≤10MB） |
| `event_reminder_deliveries` | 服务端日程提醒成功记录；日历 + UID/实例 + 偏移 + 通道唯一 |
| `summary_documents` | 摘要模板与历史文档（HTML 原文） |
| `push_subscriptions` | 浏览器推送订阅：endpoint、p256dh、auth |
| `reminder_deliveries` | 服务端提醒成功记录；任务 + 到期时间 + 偏移 + 通道唯一 |
| `reminder_attempts` | 失败投递的尝试次数、下次重试时间与错误 |

`tasks` 关键字段：

| 字段 | 说明 |
| --- | --- |
| `user_id` / `list_id` | 所有者与清单 |
| `title` / `notes` | 标题、纯文本备注 |
| `priority` | 0–3 |
| `due_at` / `all_day` | 到期时间（UTC）与全天标记 |
| `recurrence` | RRULE 主体 |
| `reminder_offset` | 兼容字段；单个提醒或最早的多提醒偏移，`-1` 不提醒 |
| `reminder_offsets` | 逗号分隔的提醒偏移列表，最多 10 个，非空时优先 |
| `completed` / `completed_at` | 完成状态 |
| `tags` | 逗号分隔标签 |
| `checklist` | JSON 子任务数组 |
| `order_index` | 手动排序 |
| `deleted` / `deleted_at` | 垃圾桶 |
| `vtodo_uid` / `vtodo_href` / `vtodo_etag` | CalDAV 身份 |
| `assignee` | 指派人用户名；仅工作台共享协作使用 |
| `sync_pending` | 本地变更待推送 |

### 已有 CalDAV 表

- `users`
- `calendars`
- `objects`：ICS 原文、ETag、组件类型、时间范围、墓碑
- `sync_changes`：sync-collection 日志
- `settings`：AI 配置等服务端设置

## 3. 时间处理

- 所有 `due_at` 入库前统一转 UTC。
- “今天/最近 7 天”边界使用服务端默认时区 `Asia/Shanghai`。
- 自然语言解析使用浏览器时区。
- 全天任务存储为对应时区本地午夜对应的 UTC 时间。
- 客户端传入 RFC3339 时保留绝对时刻；`YYYY-MM-DDTHH:mm` 按指定时区解释。

## 4. 任务工作台请求流

```text
浏览器
  -> GET /api/admin/tasks
      -> tasksync.Sync()
          -> 推送 pending 任务
          -> 导入客户端修改
          -> 处理客户端删除墓碑
          -> 重建缺失对象
      -> 查询 lists/folders/filters/tasks/counts/tags
      -> 返回工作台数据
```

写操作：

```text
POST/PATCH/DELETE
  -> store 写任务表
  -> tasksync.PushTask / DeleteTask
      -> 生成/更新 VTODO
      -> 更新 ETag
      -> CalDAV sync journal 自增
```

## 5. VTODO 同步

### 5.1 同步日历

每个用户自动创建：

```text
slug:   caldav-tasks
name:   任务
组件:   VTODO
时区:   Asia/Shanghai
```

- 管理后台禁止删除该日历。
- CalDAV 客户端删除后，下次打开工作台会重建并恢复任务对象。
- 所有清单共用一个 VTODO 日历；清单名写 `X-CALDDAV-LIST`。

### 5.2 推送

任务写入后：

1. 生成 UID（`task-<random>@caldav-free`）
2. 生成 href（`task-<random>.ics`）
3. 构建 VCALENDAR/VTODO
4. 若内容与现有对象一致，只同步 ETag，不重复写
5. 否则 `PutObject` 写入并更新 `vtodo_etag`
6. 清除 `sync_pending`

### 5.3 字段映射

| 工作台 | VTODO |
| --- | --- |
| 标题 | `SUMMARY` |
| 备注 | `DESCRIPTION` |
| 日期 | `DUE`；全天用 `VALUE=DATE` |
| 重复 | `DTSTART` + `RRULE` |
| 优先级 | `PRIORITY`：高 1、中 5、低 9 |
| 完成 | `STATUS:COMPLETED`、`COMPLETED`、`PERCENT-COMPLETE` |
| 标签 | `CATEGORIES` |
| 子任务 | `X-CALDDAV-CHECKLIST`（JSON） |
| 清单 | `X-CALDDAV-LIST` |
| 提醒 | `VALARM` + `TRIGGER` |
| 创建/修改 | `CREATED` / `LAST-MODIFIED` |

### 5.4 对账算法

`tasksync.Sync`：

1. 加载任务、VTODO 对象、墓碑
2. 按 href/UID 建立映射
3. 遍历任务：
   - 无 UID 或 `sync_pending` → 推送
   - 对象不存在且有墓碑 → 认为客户端删除，软删除任务
   - 对象不存在且无墓碑 → 重建对象
   - ETag 不一致 → 导入客户端修改
4. 遍历未被任务认领的 VTODO → 导入为新任务
5. 如客户端重命名资源或改 UID，则更新映射

### 5.5 冲突策略

- 工作台写入优先。
- 不做字段级合并。
- 客户端改动在下次打开工作台时导入。
- 不是实时推送，依赖页面加载或客户端同步。

### 5.6 删除

- 工作台删除：先删 VTODO，再软删除任务。
- 客户端删除：VTODO 变墓碑；下次 Sync 软删除任务。
- 恢复：清空旧 UID/ETag，重新生成对象。

## 6. 重复任务

- 存储标准 RRULE 主体。
- 使用 `github.com/teambition/rrule-go` 计算下一次。
- 完成有到期时间的重复任务时：
  - 计算下一次到期时间
  - 更新 `due_at`
  - 保持未完成
  - 推送新的 `DTSTART` / `DUE`
- 不保留历史实例。
- `COUNT` / `UNTIL` 会以当前到期时间重新锚定。

## 7. 清单共享

- `task_list_shares` 记录 `list_id`、`owner_id`、`user_id`、`role`。
- 支持 `viewer` / `editor`；只有清单所有者可以管理共享。
- 接收方通过 `/tasks/shared?listId=` 读取任务；编辑者复用普通任务写接口，后端校验 `editor` 角色，任务仍归属清单所有者。
- 共享任务保留所有者 `user_id`，因此 CalDAV 同步、提醒、统计仍归所有者；编辑者的修改也会推送到所有者的 CalDAV。
- 接收方侧栏显示“共享给我”；viewer 使用 `inert` 只读展示，editor 可编辑任务但清单下拉锁定。
- 删除清单或用户时清理对应共享记录。
- `assignee` 只允许清单所有者或共享成员；不写入 VTODO，由工作台展示。
- 指派变更时写入 `notifications`，并异步尝试 Web Push / SMTP；失败不影响任务保存。
- 前端通过 EventSource 连接 `/api/admin/notifications/stream`，新通知立即更新未读数；仍保留 60 秒轮询兜底。
- 点击通知按 `url` 进入共享或普通任务。
- 评论通过 `GetTaskAccess` 支持所有者/共享成员；`@username` 仅对清单成员生效，评论作者和所有者可删除。
- 评论通知复用站内通知、Web Push 和 SMTP 链路。
- 附件通过任务权限校验后上传/下载；文件内容存 SQLite，便于单文件备份。
- 评论仅作者可编辑；删除评论时在同一事务中删除附件。
- 图片附件在前端按 `Content-Type: image/*` 内联预览。

## 8. 四象限

- 前端 `TaskMatrixPanel` 按内置或自定义规则把任务分为四个象限。
- 简化规则：高→重要且紧急、中→重要不紧急、低→不重要但紧急、无→不重要不紧急。
- 复杂规则：重要=高/中优先级，紧急=已过期/今天/明天到期，组合为四个象限。
- 简化模式支持拖拽任务到象限，映射为优先级并复用任务 PATCH。
- 每个象限按无日期、已过期、今天、明天、未来、已完成分组。
- 矩阵视图复用任务工作区数据；视图名称、规则 JSON 和排序保存在 `matrix_views`，任务操作走现有任务 API。
- 自定义规则按 Q1 → Q4 顺序匹配；每个条件组内部为 AND，条件组之间由 `match` 控制 AND/OR；未匹配任务归入 Q4。
- 象限名称、颜色、条件组均保存在规则 JSON 中，名称与颜色对所有规则模式生效。
- 规则弹窗基于当前任务列表实时计算象限与条件组命中数；条件组排序仅影响编辑体验，不改变匹配语义。
- 规则模板与条件复制/粘贴只修改前端表单，保存时整体写入规则 JSON。
- 矩阵页显示/隐藏已完成状态保存在浏览器 `localStorage`，过滤后的任务同时用于卡片和规则预览。
- 自定义模式拖拽由 `planMatrixDrop` 生成补丁，先在内存中重新计算归属，命中目标象限后才提交 PATCH；无法满足时不变更任务。
- 象限折叠状态按当前视图保存在 `localStorage`，桌面端两行都折叠时自动收缩对应网格行。
- 矩阵手动排序复用 `/tasks/reorder`：把 Q1–Q4 的可见任务按顺序扁平化后写入全局 `order`；关闭手动排序后恢复日期分组。
- 自定义规则模板保存在 `matrix_rule_templates`，存完整四象限规则 JSON（含名称、颜色、条件组）；规则弹窗挂载时拉取，支持创建、重命名、更新规则和删除。
- 手动排序跨象限拖动会先计算目标条件补丁和插入位置；任务条件更新成功后再写入新的全局顺序，避免移动失败时顺序被破坏。
- 四象限批量移动复用单任务条件推导，对每个选中任务执行 PATCH；快速添加先用空白任务壳推导目标象限条件，再调用创建任务接口。

## 8.1 习惯

- 习惯数据独立存储在 SQLite，不写入 CalDAV `VTODO`。
- `HabitPanel` 通过 `/api/admin/habits` 加载习惯、分组、偏好和近 60 天打卡；详情按月份加载统计、月历和日志。
- 频率使用本项目 JSON：`daily`（星期集合）、`weekly`（每周 N 天）、`interval`（每 N 天）。
- 打卡按 `habit_id + checkin_stamp` 唯一；`value >= goal` 视为完成。
- 月完成率、当前连续、月完成量和每日完成量由后端实时计算。
- 习惯排序通过批量 `sort_order` 更新；打卡样式、分组和日志编辑均走习惯 API。
- `HabitTodayStrip` 根据偏好接入今天/最近 7 天与日历顶部；打卡满足 `recordEnable` 时弹出日志编辑器。
- 提醒调度器检查习惯 HH:mm 提醒，按习惯/日期/时间/渠道去重；站内通知、Web Push 和 SMTP 复用现有提醒基础设施，内部用负数 `task_id` 复用投递与退避表。
- 日历通过 `/api/admin/habits/calendar` 获取日期范围内的习惯打卡条目，并以只读全天条目展示；点击条目进入 `/tasks/habit/:habitId`。坚持目标按总完成天数计算轮次和当前进度。
- 习惯详情深链由 `/tasks/habit/:habitId` 驱动，`HabitPanel` 挂载或收到 focus 变化时加载对应详情；专注计时完成后通过 `/habits/{id}/focus` 写入专注历史，并参与累计/本月专注统计。
- 习惯提醒时区来自 `habit_preferences.timezone`；JSON 备份导出习惯、分组、打卡、日志和专注记录，导入时重建分组映射并写入当前用户。

## 9. 提醒

- 相对偏移写入 `reminder_offsets`（兼容字段 `reminder_offset` 保存最早的一个）。
- 每个提醒生成一个 VTODO `VALARM`：

```text
BEGIN:VALARM
ACTION:DISPLAY
DESCRIPTION:<标题>
TRIGGER:-PT15M
END:VALARM
```

- 导入时解析 `TRIGGER` 为分钟；绝对时间 `TRIGGER` 忽略。
- 浏览器端每 30 秒请求 `/tasks/reminders`，本地计算提醒时刻并去重；通知记录存 localStorage。
- 服务端 `internal/reminders` 独立于页面运行，默认每 30 秒扫描带提醒的未完成任务：
  - 对每个 `ReminderOffsets` 偏移分别计算 `due_at - offset`；旧任务回退到 `reminder_offset`。全天任务按 `Asia/Shanghai` 当天 09:00 计算。
  - 只补发最近 6 小时内到期的提醒。
  - 通过 `push_subscriptions` 中的 endpoint 调用 Web Push，payload 为 JSON（标题、正文、任务 URL）。
  - `reminder_deliveries` 以任务、到期时间、偏移、通道去重；推送服务返回 404/410 时删除失效订阅。
  - 邮件通道使用 `internal/mailer`，支持 STARTTLS、隐式 TLS 和无加密；收件人为任务所有者邮箱。
  - 失败投递写入 `reminder_attempts`，按 1 分钟、2 分钟、4 分钟……最长 2 小时退避；成功后删除尝试记录。
- VAPID 密钥首次启动自动生成，保存在 `settings`（`push.vapid_public` / `push.vapid_private`），私钥不通过 API 返回。
- SMTP 配置保存在 `settings`（`smtp.*`），可用 `CALDAV_SMTP_*` 环境变量兜底；密码不通过 API 返回但以明文存 SQLite。
- Service Worker 位于 `/admin/sw.js`，通知点击后聚焦或打开对应任务。
- 可通过 `CALDAV_REMINDERS=off` 关闭调度器；`CALDAV_PUSH_SUBJECT` 配置 VAPID 联系人。

## 10. 日历事件

`GET /api/admin/tasks/calendar`：

1. 列出当前用户日历，排除 `caldav-tasks`
2. 对每个日历用 `ObjectRange` 预筛对象
3. `ical.Load` + `ExpandObject` 展开重复实例
4. 只保留 `VEVENT`
5. 返回实例起止、标题、地点、颜色、所属日历
6. 最大范围 120 天、最多 2000 实例

前端：

- 月：任务 + 事件按天聚合
- 周/日：全天行 + 24 小时时间网格，重叠项分列
- 日程：未来 30 天分组
- 工作台内打开结构化日程弹窗，支持新建、编辑、删除
- 月/周/日视图支持 HTML5 拖拽：任务更新 due，事件通过结构化 PATCH 保持时长
- 拖拽重复事件修改整个系列
- 周/日视图通过 pointer 事件调整定时日程结束时间，按 15 分钟吸附，再走结构化 PATCH
- 重复事件编辑/删除支持“仅此次 / 整个系列”
- 单次修改写入带 `RECURRENCE-ID` 的 VEVENT 例外；单次删除写入 `EXDATE`
- 拖拽重复事件仍修改整个系列
- 结构化更新会重建 VEVENT 标准字段
- `reminders` 写入 `VALARM`；浏览器端在页面打开时轮询 2 天内的日程并按提醒偏移通知
- 服务端调度器扫描有 VALARM 的日历对象，展开重复实例，并按实例开始时间计算提醒；写入站内通知并成功投递后记录 `event_reminder_deliveries`
- 日程通知的“稍后提醒”写入 `event_snoozes`，任务提醒写入 `task_snoozes`，调度器按 UTC 时间到期后重新生成通知并尝试推送/邮件
- 日程提醒复用 Web Push 和 SMTP，失败通过 `reminder_attempts` 退避重试
- 推送/邮件链接携带 `calendar`、`event`、`occurrence`，工作台加载日历后匹配实例并自动打开编辑弹窗
- 原始 ICS 仍可在管理后台事件编辑页修改

## 11. 统计

`ComputeTaskStats` 在内存中聚合当前用户全部未删除任务：

- 未完成、完成、逾期、今天
- 完成率
- 本周期新建/完成/到期/按时完成
- 平均完成耗时
- 每日趋势
- 按清单/标签/优先级

统计不是基于历史事件日志，清空垃圾桶或彻底删除会丢失对应历史。

## 12. 摘要

摘要页不持久化服务端文档，而是按条件生成内容：

```text
筛选条件
  -> GET /api/admin/tasks/summary
      -> 已完成：CompletedAt ∈ [from, to)
      -> 未完成：DueAt ∈ [from, to)，无日期时用 CreatedAt
      -> 下一周期：DueAt ∈ 下一段等长范围
  -> 前端按分组/显示字段生成 HTML
  -> contenteditable 编辑器允许继续修改
```

前端 `TaskSummaryPanel`：

- 日期预设与自定义范围
- 分组：状态/清单/完成时间/任务时间/标签/优先级
- 显示字段：完成时间、任务时间、标签、清单、优先级、详细内容
- 富文本工具栏基于 `document.execCommand`
- 模板/历史文档存服务端 `summary_documents`
- 内容优化：调用 AI 文本接口，将摘要重写为 Markdown 后转换成 HTML
- 导出：剪贴板、HTML、PNG（SVG foreignObject + canvas）、打印/PDF、mailto

服务端只返回任务快照，不保存编辑后的文档。

## 13. AI 助手

### 10.1 配置

存储于 `settings`：

```text
ai.provider
ai.base_url
ai.model
ai.api_key
ai.models
ai.models_base
ai.recent_models
ai.model_stats
```

未配置时回退环境变量：

```text
CALDAV_AI_PROVIDER
CALDAV_AI_BASE_URL
CALDAV_AI_MODEL
CALDAV_AI_API_KEY
```

模型列表接口使用当前或表单中的 Base URL/Key 请求 `GET {baseURL}/models`，支持 `data[].id` 和 `models[].id/name` 两种响应格式，最多返回 200 个模型；Ollama 优先使用原生 `/api/tags`。列表写入 `ai.models`，`ai.models_base` 记录来源地址，换地址保存时自动清空。

对话请求可以携带 `model` 覆盖默认模型，只影响本次请求；前端把对话模型选择保存在浏览器本地，并在设置页根据模型名称推测推荐、工具调用、视觉、推理和轻量标签。

连接测试接口使用最小对话请求验证地址、Key 和模型，也可发送 ping 工具检查 function calling。对话首轮调用失败且尚未执行工具操作时，会按默认模型、最近模型、已保存模型顺序最多尝试 3 个候选；失败发生在工具执行之后则不重试，避免重复修改任务。成功调用会更新 `ai.recent_models`（最多 8 个）和 `ai.model_stats`（调用次数、累计/最近耗时、最近时间，最多 20 个模型），设置接口和对话响应都会返回这些数据。

### 10.2 对话循环

```text
用户消息
  -> 系统提示（时间、时区、清单）
  -> POST <base>/chat/completions
  -> 模型返回 tool_calls
  -> 服务端执行工具
  -> tool 消息回传
  -> 再次请求模型
  -> 最多 6 轮
  -> 返回最终文本 + actions
```

### 10.3 工具

```text
list_lists
list_tasks
get_stats
create_task
update_task
complete_task
delete_task
create_list
```

工具直接操作 store 和 tasksync，复用与 HTTP API 相同的完成/推送逻辑。

### 10.4 安全边界

- AI 设置接口仅管理员可用。
- API Key 与 SMTP 密码不回传，但以明文存 SQLite。
- 工具只能操作当前用户数据。
- 工具参数大小限制 64 KiB。
- 删除工具依赖模型遵循“先确认”的系统提示，不是硬性拦截。
- 模型调用不是流式，超时 90 秒。

## 14. 测试

```bash
go test ./...
go vet ./...
cd web && npx vue-tsc --noEmit
```

覆盖：

- iCalendar 解析、时区、RRULE、时间范围
- CalDAV/WebDAV、sync-collection、free-busy
- 任务 CRUD、过滤器、文件夹、标签、垃圾桶、批量、排序
- VTODO 推送/导入/删除/重建
- 日历事件展开
- 统计聚合
- AI 配置、工具调用、Mock OpenAI 上游

## 15. 设计限制

- 任务与 CalDAV 的同步是懒对账，不是实时。
- 清单与日历没有一对一映射。
- 子任务依赖扩展属性，部分客户端可能丢弃。
- 任务工作台仅管理员使用。
- VTODO 行内容未做 RFC 5545 75 字节折行；超长备注/子任务在少数客户端可能不兼容。
- 数据库为单机 SQLite，适合个人/小团队。
