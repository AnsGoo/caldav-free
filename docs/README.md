# caldav-free 文档

caldav-free 是一个自托管的 CalDAV 日历服务器，内置任务工作台、管理后台、统计、日历和 AI 助手。

> 文档更新：2026-10-23

## 文档目录

| 文档 | 内容 |
| --- | --- |
| [任务工作台使用指南](任务工作台.md) | 功能、界面、任务语法、重复/提醒、日历、统计、AI、同步、配置与限制 |
| [Admin JSON API](API.md) | 管理后台任务相关接口、请求/响应结构、状态码与示例 |
| [架构与同步设计](ARCHITECTURE.md) | 服务端模块、数据表、VTODO 同步、日历事件展开、统计与 AI 工具循环 |
| [实现进度与路线图](ROADMAP.md) | 已完成批次、提交记录、尚未实现的产品能力和建议优先级 |

## 快速入口

- 管理后台：`http://<host>:5232/admin/`
- 任务工作台：`http://<host>:5232/admin/tasks`
- 统计：`http://<host>:5232/admin/tasks?view=stats`
- AI 助手：`http://<host>:5232/admin/tasks?view=ai`
- CalDAV Calendar Home：`http://<host>:5232/calendars/<用户名>/`
- 任务同步日历：`http://<host>:5232/calendars/<用户名>/caldav-tasks/`

## 本地运行

```bash
go run ./cmd/caldav-free -data ./data -addr :5232
```

首次启动会创建管理员并打印随机密码。

## 文档约定

- 时间使用 RFC3339，或 `YYYY-MM-DDTHH:mm`；仅日期时按全天任务处理。
- “工作台”指 `/admin/tasks`，与 CalDAV 客户端共享同一批 VTODO 数据。
- 所有 `/api/admin/*` 接口仅管理员可用，非 GET 请求需要 `X-CSRF-Token`。
- 示例中的主机、用户名、密码、API Key 均为占位符。
