# Admin JSON API

任务工作台与管理后台共用 `/api/admin` JSON API。

## 1. 约定

- 认证：登录后使用 `caldav_admin` HttpOnly 会话 Cookie。
- CSRF：所有非 `GET/HEAD` 请求必须带：

```http
X-CSRF-Token: <spring session csrf>
```

CSRF token 来自 `/api/admin/login` 或 `/api/admin/me` 响应中的 `csrf`。
- 请求/响应：`application/json; charset=utf-8`。
- 错误格式：

```json
{ "error": "错误说明" }
```

- 仅管理员可访问；普通 CalDAV 用户不能使用这些接口。
- 时间：RFC3339（如 `2026-10-30T15:00:00+08:00`）或 `YYYY-MM-DDTHH:mm`；仅日期按全天处理。
- 任务接口中 `due` 传空字符串表示清除日期。

## 2. 认证

### POST /api/admin/login

```json
{
  "username": "admin",
  "password": "your-password"
}
```

响应：

```json
{
  "user": { "id": 1, "username": "admin", "isAdmin": true },
  "csrf": "token",
  "baseUrl": "https://dav.example.com",
  "caldavUrl": ""
}
```

### GET /api/admin/me

返回当前用户、CSRF、baseUrl、CalDAV 地址。

### POST /api/admin/logout

注销会话。

## 3. 工作台数据

### GET /api/admin/tasks

查询参数：

| 参数 | 说明 |
| --- | --- |
| `view` | `all`、`today`、`next7`、`inbox`、`completed`、`trash`、`list`、`filter` |
| `listId` | `view=list` 时使用 |
| `filterId` | 应用保存过滤器 |
| `q` | 标题/备注关键词 |

响应：

```json
{
  "lists": [
    {
      "id": 2,
      "folderId": 1,
      "name": "工作",
      "color": "#4772fa",
      "order": 1,
      "isInbox": false,
      "count": 5
    }
  ],
  "folders": [
    { "id": 1, "name": "项目", "order": 1 }
  ],
  "filters": [
    {
      "id": 1,
      "name": "高优工作",
      "color": "#4772fa",
      "order": 1,
      "conditions": {
        "listIds": [2],
        "tags": ["工作"],
        "tagMode": "any",
        "priorities": [3],
        "status": "open",
        "date": "any",
        "keyword": ""
      }
    }
  ],
  "tasks": [],
  "counts": {
    "all": 5,
    "today": 2,
    "next7": 4,
    "inbox": 1,
    "completed": 3,
    "trash": 0
  },
  "tags": ["工作", "生活"],
  "tagCounts": [
    { "name": "工作", "count": 4 }
  ],
  "inbox": 1
}
```

`tasks` 中每项结构见“任务对象”。

## 4. 任务 CRUD

### 任务对象

```json
{
  "id": 12,
  "listId": 2,
  "listName": "工作",
  "listColor": "#4772fa",
  "title": "写周报",
  "notes": "汇总本周进度",
  "priority": 2,
  "due": "2026-10-30T18:00:00+08:00",
  "allDay": false,
  "recurrence": "FREQ=WEEKLY",
  "reminderOffset": 15,
  "completed": false,
  "completedAt": "",
  "deletedAt": "",
  "tags": ["工作"],
  "checklist": [
    { "id": "c1", "title": "整理数据", "done": true }
  ],
  "order": 3,
  "createdAt": "2026-10-22T10:00:00Z",
  "modifiedAt": "2026-10-22T10:00:00Z"
}
```

字段：

| 字段 | 说明 |
| --- | --- |
| `priority` | 0 无、1 低、2 中、3 高 |
| `recurrence` | RRULE 主体，如 `FREQ=DAILY`；空表示不重复 |
| `reminderOffset` | 提前分钟数，`-1` 不提醒，`0` 准时 |
| `allDay` | 全天任务 |
| `checklist` | 子任务列表 |

### POST /api/admin/tasks

```json
{
  "title": "写周报",
  "listId": 2,
  "due": "2026-10-30T18:00:00+08:00",
  "priority": 2,
  "tags": ["工作"],
  "notes": "汇总进度",
  "recurrence": "FREQ=WEEKLY",
  "reminderOffset": 15,
  "checklist": [{ "id": "c1", "title": "整理数据", "done": false }],
  "timezone": "Asia/Shanghai"
}
```

也支持自然语言：

```json
{
  "text": "明天下午 3 点和张三开会 #工作 !!",
  "listId": 2,
  "timezone": "Asia/Shanghai"
}
```

`text` 与 `title` 同时存在时，`title` 优先，`text` 只填充未设置的日期/优先级/标签。

响应 `201`：

```json
{ "task": { "...": "任务对象" } }
```

### PATCH /api/admin/tasks/{id}

只传需要修改的字段：

```json
{
  "title": "写月报",
  "due": "2026-11-01T18:00:00+08:00",
  "priority": 3,
  "tags": ["工作", "月度"],
  "reminderOffset": 60,
  "completed": false
}
```

特殊行为：

- `completed: true`：普通任务完成；有到期时间的重复任务推进到下一次，返回 `completed: false`
- `due: ""`：清除日期
- `recurrence: ""`：取消重复

响应：

```json
{ "task": { "...": "任务对象" } }
```

### DELETE /api/admin/tasks/{id}

软删除到垃圾桶，返回 `204`。同时删除对应 VTODO。

## 5. 批量、排序、垃圾桶

### POST /api/admin/tasks/batch

```json
{
  "ids": [12, 13, 14],
  "action": "move",
  "listId": 3
}
```

`action`：

- `complete`
- `uncomplete`
- `move`（需要 `listId`）
- `delete`

响应：

```json
{ "updated": 3 }
```

### POST /api/admin/tasks/reorder

```json
{ "ids": [13, 12, 14] }
```

按数组顺序写入 `order_index`，返回 `204`。

### POST /api/admin/tasks/{id}/restore

恢复垃圾桶任务。返回：

```json
{ "task": { "...": "任务对象" } }
```

恢复时会清空旧 VTODO 身份并重新推送。

### DELETE /api/admin/tasks/{id}/purge

彻底删除垃圾桶中的单条任务，返回 `204`。

### DELETE /api/admin/tasks/trash

清空垃圾桶，返回 `204`。

## 6. 提醒

### GET /api/admin/tasks/reminders

返回未完成、带提醒且有时间字段的任务：

```json
{
  "tasks": [
    {
      "id": 12,
      "title": "开会",
      "due": "2026-10-30T15:00:00+08:00",
      "reminderOffset": 15
    }
  ]
}
```

浏览器端据此计算提醒时间并显示通知。

## 7. 日历事件

### GET /api/admin/tasks/calendar?from=...&to=...

示例：

```text
/api/admin/tasks/calendar?from=2026-10-01T00:00:00%2B08:00&to=2026-11-01T00:00:00%2B08:00
```

响应：

```json
{
  "from": "2026-10-01T00:00:00+08:00",
  "to": "2026-11-01T00:00:00+08:00",
  "calendars": [
    { "id": 2, "name": "工作日历", "color": "#0ea5e9" }
  ],
  "events": [
    {
      "id": "2:meeting.ics:1760000000",
      "uid": "meeting@example",
      "href": "meeting.ics",
      "calendarId": 2,
      "calendarName": "工作日历",
      "color": "#0ea5e9",
      "summary": "产品评审",
      "location": "会议室 A",
      "start": "2026-10-22T14:00:00+08:00",
      "end": "2026-10-22T15:00:00+08:00",
      "allDay": false,
      "recurring": false
    }
  ]
}
```

- 排除 `caldav-tasks` 任务同步日历
- 重复 `VEVENT` 在范围内展开
- 范围最长 120 天
- 最多 2000 个实例

## 8. 统计

### GET /api/admin/tasks/stats?days=30

`days`：1–365，默认 30。

```json
{
  "stats": {
    "days": 30,
    "open": 5,
    "completed": 12,
    "overdue": 2,
    "today": 3,
    "trash": 1,
    "completionRate": 70.5,
    "createdInPeriod": 20,
    "completedInPeriod": 14,
    "dueInPeriod": 18,
    "onTimeInPeriod": 11,
    "avgCompletionHours": 27.4,
    "daily": [
      { "date": "2026-10-01", "created": 2, "completed": 1, "due": 3 }
    ],
    "lists": [
      {
        "id": 2,
        "name": "工作",
        "color": "#4772fa",
        "open": 4,
        "completed": 8,
        "overdue": 1
      }
    ],
    "tags": [
      { "name": "工作", "open": 3, "completed": 2, "overdue": 1 }
    ],
    "priorities": [
      { "priority": 3, "open": 2, "completed": 4 }
    ]
  }
}
```

## 9. 摘要

### GET /api/admin/tasks/summary

查询参数：

| 参数 | 说明 |
| --- | --- |
| `from` / `to` | 时间范围，RFC3339 或 `YYYY-MM-DD`；`to` 为开区间 |
| `listId` | 可选，限定清单 |
| `status` | `all`、`completed`、`open` |
| `priority` | 1–3，可选 |
| `tag` | 标签名，可选 |
| `includeNext` | `1` 时追加下一周期任务 |

示例：

```text
/api/admin/tasks/summary?from=2026-09-01T00:00:00%2B08:00&to=2026-10-01T00:00:00%2B08:00&status=all
```

响应：

```json
{
  "title": "9月1日-9月30日",
  "from": "2026-09-01T00:00:00+08:00",
  "to": "2026-10-01T00:00:00+08:00",
  "tasks": [
    {
      "id": 12,
      "title": "研发日报",
      "listId": 1,
      "listName": "收集箱",
      "listColor": "#4772fa",
      "completed": true,
      "completedAt": "2026-09-04T10:00:00+08:00",
      "priority": 0,
      "tags": [],
      "notes": "",
      "checklist": [],
      "createdAt": "2026-09-03T09:00:00+08:00"
    }
  ],
  "nextTasks": [],
  "counts": {
    "completed": 8,
    "open": 2
  }
}
```

规则：

- 已完成任务按 `completedAt` 是否落在范围内筛选
- 未完成任务按 `due` 是否落在范围内筛选；没有到期时间时按 `createdAt`
- 已完成条目排在未完成之前，已完成按完成时间倒序
- `includeNext=1` 时，返回下一段等长范围内到期的未完成任务

## 10. 清单与文件夹

### POST /api/admin/task-lists

```json
{ "name": "工作", "color": "#4772fa", "folderId": 1 }
```

响应 `201`：

```json
{ "list": { "...": "清单对象" } }
```

### PATCH /api/admin/task-lists/{id}

```json
{ "name": "工作台", "color": "#2ea88a", "order": 3, "folderId": 2 }
```

`folderId: 0` 表示移到根目录。

### DELETE /api/admin/task-lists/{id}

删除清单，任务移动到收集箱；同步日历 `caldav-tasks` 不能删除。

### POST /api/admin/task-folders

```json
{ "name": "项目" }
```

### PATCH /api/admin/task-folders/{id}

```json
{ "name": "项目 Alpha", "order": 2 }
```

### DELETE /api/admin/task-folders/{id}

删除文件夹，其中的清单回到根目录。

## 11. 标签

### GET /api/admin/task-tags

```json
{
  "tags": [
    { "name": "工作", "count": 4 },
    { "name": "生活", "count": 2 }
  ]
}
```

### POST /api/admin/task-tags/rename

```json
{ "from": "工作", "to": "项目" }
```

会更新任务、VTODO `CATEGORIES` 和保存过滤器条件。

### POST /api/admin/task-tags/delete

```json
{ "tag": "工作" }
```

两个接口都返回更新后的标签列表。

## 12. 保存过滤器

### GET /api/admin/task-filters

### POST /api/admin/task-filters

```json
{
  "name": "高优工作",
  "color": "#4772fa",
  "conditions": {
    "listIds": [2],
    "tags": ["工作"],
    "tagMode": "any",
    "priorities": [3],
    "status": "open",
    "date": "any",
    "keyword": ""
  }
}
```

`status`：`open` / `completed` / `all`。
`date`：`any` / `today` / `next7` / `overdue` / `none`。
`tagMode`：`any` / `all`。

### PATCH /api/admin/task-filters/{id}

```json
{
  "name": "高优工作",
  "conditions": {
    "tags": ["项目"],
    "status": "open",
    "date": "next7"
  }
}
```

### DELETE /api/admin/task-filters/{id}

返回 `204`。

## 13. AI 助手

### GET /api/admin/tasks/ai/settings

```json
{
  "baseUrl": "https://api.openai.com/v1",
  "model": "gpt-4o-mini",
  "hasKey": true,
  "configured": true
}
```

API Key 永不返回。

### PUT /api/admin/tasks/ai/settings

```json
{
  "baseUrl": "https://api.openai.com/v1",
  "model": "gpt-4o-mini",
  "apiKey": "sk-...",
  "clearKey": false
}
```

`apiKey` 为空表示保留原值；`clearKey: true` 清除已保存 Key。

### POST /api/admin/tasks/ai/chat

```json
{
  "messages": [
    { "role": "user", "content": "明天下午 3 点提醒我和张三开会" }
  ],
  "timezone": "Asia/Shanghai"
}
```

响应：

```json
{
  "message": "已创建任务「和张三开会」，定在明天 15:00。",
  "actions": [
    {
      "type": "create_task",
      "label": "已创建任务「和张三开会」",
      "taskId": 21
    }
  ],
  "model": "gpt-4o-mini"
}
```

未配置模型返回：

```json
HTTP 503
{ "error": "尚未配置 AI 模型，请先在 AI 设置中填写 Base URL 与模型" }
```

支持的 AI 工具：

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

## 14. 状态码

| 状态码 | 说明 |
| --- | --- |
| 200 | 成功 |
| 201 | 创建成功 |
| 204 | 成功，无响应体 |
| 400 | 参数错误 |
| 401 | 未登录/会话过期 |
| 403 | 非管理员或 CSRF 失败 |
| 404 | 资源不存在 |
| 409 | 同名清单/文件夹冲突，或任务同步日历不能删除 |
| 503 | AI 未配置 |
| 502 | AI 上游请求失败 |
