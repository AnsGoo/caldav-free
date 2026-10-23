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
internal/web/          管理后台、任务 API、日历事件、统计、AI
web/                   Vue 3 + Vite+ + Arco 管理后台
```

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
```

## 2. 数据表

### 任务相关

| 表 | 作用 |
| --- | --- |
| `task_folders` | 清单文件夹 |
| `task_lists` | 清单；每用户一个收集箱；`folder_id` 归属文件夹 |
| `tasks` | 任务、日期、重复、提醒、软删除、VTODO 同步字段 |
| `task_filters` | 保存过滤器；条件以 JSON 存储 |
| `summary_documents` | 摘要模板与历史文档（HTML 原文） |

`tasks` 关键字段：

| 字段 | 说明 |
| --- | --- |
| `user_id` / `list_id` | 所有者与清单 |
| `title` / `notes` | 标题、纯文本备注 |
| `priority` | 0–3 |
| `due_at` / `all_day` | 到期时间（UTC）与全天标记 |
| `recurrence` | RRULE 主体 |
| `reminder_offset` | 提前分钟，`-1` 不提醒 |
| `completed` / `completed_at` | 完成状态 |
| `tags` | 逗号分隔标签 |
| `checklist` | JSON 子任务数组 |
| `order_index` | 手动排序 |
| `deleted` / `deleted_at` | 垃圾桶 |
| `vtodo_uid` / `vtodo_href` / `vtodo_etag` | CalDAV 身份 |
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

## 7. 提醒

- 相对偏移写入 `reminder_offset`。
- VTODO `VALARM`：

```text
BEGIN:VALARM
ACTION:DISPLAY
DESCRIPTION:<标题>
TRIGGER:-PT15M
END:VALARM
```

- 导入时解析 `TRIGGER` 为分钟；绝对时间 `TRIGGER` 忽略。
- 浏览器端每 30 秒请求 `/tasks/reminders`，本地计算提醒时刻并去重。
- 通知记录存 localStorage。

## 8. 日历事件

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
- 事件只读，点击跳转事件编辑页

## 9. 统计

`ComputeTaskStats` 在内存中聚合当前用户全部未删除任务：

- 未完成、完成、逾期、今天
- 完成率
- 本周期新建/完成/到期/按时完成
- 平均完成耗时
- 每日趋势
- 按清单/标签/优先级

统计不是基于历史事件日志，清空垃圾桶或彻底删除会丢失对应历史。

## 10. 摘要

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

## 11. AI 助手

### 10.1 配置

存储于 `settings`：

```text
ai.base_url
ai.model
ai.api_key
```

未配置时回退环境变量：

```text
CALDAV_AI_BASE_URL
CALDAV_AI_MODEL
CALDAV_AI_API_KEY
```

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
- API Key 不回传，但以明文存 SQLite。
- 工具只能操作当前用户数据。
- 工具参数大小限制 64 KiB。
- 删除工具依赖模型遵循“先确认”的系统提示，不是硬性拦截。
- 模型调用不是流式，超时 90 秒。

## 12. 测试

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

## 13. 设计限制

- 任务与 CalDAV 的同步是懒对账，不是实时。
- 清单与日历没有一对一映射。
- 子任务依赖扩展属性，部分客户端可能丢弃。
- 任务工作台仅管理员使用。
- VTODO 行内容未做 RFC 5545 75 字节折行；超长备注/子任务在少数客户端可能不兼容。
- 数据库为单机 SQLite，适合个人/小团队。
