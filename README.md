# caldav-free

一个完整、可自托管的 **CalDAV 日历服务器**，使用 Go 编写，内置 Web 管理后台。
兼容 Apple 日历、iOS/macOS、Thunderbird、DAVx5、GNOME Evolution 等标准 CalDAV 客户端。

```
Go 1.26 · SQLite (GORM) · 单二进制 · 无 CGO · 单文件数据库
```

## 功能

### CalDAV / WebDAV

- **RFC 4791 CalDAV**：principal 发现、calendar-home-set、MKCALENDAR、calendar-query、calendar-multiget、free-busy-query
- **RFC 4918 WebDAV**：PROPFIND、PROPPATCH、GET/HEAD、PUT、DELETE、OPTIONS、extended MKCOL
- **RFC 6578 WebDAV Sync**：`sync-collection`、增量同步 token、删除墓碑（tombstone）
- 强 ETag、`If-Match` / `If-None-Match` 条件请求、`If-Modified-Since`
- 日历级 `getctag`（CalendarServer 扩展）与 Apple `calendar-color` / `calendar-order`
- `supported-calendar-component-set`：VEVENT / VTODO / VJOURNAL 可按日历启用
- `calendar-data` 的 `<expand>` 展开、时间范围过滤、文本/参数/property 过滤
- 重复事件：RRULE、RDATE、EXDATE、RECURRENCE-ID 覆盖、COUNT/UNTIL、BYSETPOS/BYDAY 等
- 时区：IANA tzdata 内嵌，支持 VTIMEZONE 回退、Windows TZID 映射、DST 展开
- 多用户、owner 隔离；管理员可跨用户管理
- Basic Auth + PBKDF2-SHA256 密码哈希；认证结果短期缓存，改密立即失效

### 任务工作台

- 内置滴答清单风格的任务管理界面：图标栏 + 清单侧栏 + 任务列表 + 详情面板；文件夹和清单支持拖拽排序
- 智能视图：所有、今天、最近 7 天、收集箱、已完成、垃圾桶；支持清单、标签与关键词筛选
- 工作台各视图使用独立路径：`/tasks`、`/tasks/today`、`/tasks/matrix`、`/tasks/calendar`、`/tasks/list/:id` 等，支持直接访问、刷新和浏览器前进后退
- 四种视图模式：清单 / 看板（按清单分列，支持拖拽移动；单个清单内可建自定义分组列）/ 日历 / 四象限，工作台各视图使用满宽内容区；看板列自适应铺满并独立滚动，日历满宽满高，统计/摘要/AI 占满剩余空间
- 任务支持开始/截止时间与时长，VTODO 同时写入 DTSTART 和 DUE
- 真实子任务层级：任务通过 parentId 关联，父任务详情可添加、完成、打开和删除子任务
- 任务级附件：支持图片和其他文件上传、预览、下载与删除，单文件最大 10MB
- 任务模板：任务详情右上角保存为模板，快速添加栏从模板创建任务；保存标题、备注、清单、优先级、标签、子任务、重复规则和提醒偏移
- 笔记清单：侧栏「笔记」分组集中展示笔记清单，点击 + 直接新建笔记，文档图标新建笔记清单；笔记使用固定宽度卡片视图和 Markdown 所见即所得编辑器（Tiptap，单栏实时渲染），支持标题、加粗、斜体、删除线、引用、代码、列表、复选框、表格、链接、自动保存、置顶、搜索与删除；笔记清单和单篇笔记都支持只读/可编辑共享，笔记支持评论、@提及、附件和改动动态；编辑器顶部可切换笔记所属清单，编辑器与卡片列表之间的分隔线可拖动调整宽度；Markdown 存储，服务端维护搜索镜像；笔记只保存在工作台，不写入 CalDAV VTODO
- 时间线视图：按清单分组的横向时间轴，支持日 / 周 / 月缩放、按清单 / 标签 / 优先级着色、点击空白新建、拖动任务条改期、上一段 / 今天 / 下一段
- CalDAV 近实时同步：工作台打开时每 15 秒增量同步 VTODO，变化通过 SSE 自动刷新列表；其他标签页和 CalDAV 客户端修改会同步到当前页面
- 并列显示：任务列表 / 看板 / 时间线可与日历左右并列，拖动分隔条调整宽度，点击任务时自动收起日历面板
- 工作台内日期、时间选择器统一使用 Arco DatePicker / TimePicker，不使用浏览器原生日期控件
- 日历支持月、周、2 周、3 日、日、日程、年七种视图；支持外部 ICS 日历订阅和内置节假日日历；订阅与节假日事件只读，但可点击查看详情；移动端月视图用紧凑圆点展示事件密度，并使用满宽满高工作区；月视图日期格自动均分剩余高度，周/日为填满剩余空间的时间网格，日程为未来 30 天满宽清单
- 日历叠加当前用户所有 CalDAV 日历的 `VEVENT`（重复事件会展开），与任务到期时间同屏显示；支持在工作台内新建、编辑、删除日程，可维护参与人邮箱、拖拽改期、拖动底部边缘调整时长；日程可写 CalDAV `VALARM` 提醒，页面打开时使用浏览器通知，服务端也会按提醒时间写入站内通知并投递 Web Push / 邮件，通知可直接打开对应日程实例；重复日程支持“仅此次 / 整个系列”编辑与删除
- 四象限页：支持多套服务端保存的视图，视图可在管理弹窗中重命名、拖拽排序、修改规则；规则支持“按优先级”“优先级 + 截止日期”和“自定义”，自定义模式可为每个象限设置多组优先级、日期、清单、标签、指派人条件，条件组之间支持 AND/OR，可拖拽排序并实时预览命中数量，支持内置模板、服务端保存并可重命名/更新的自定义模板、跨象限复制/粘贴条件，还可设置象限名称与颜色；矩阵页可一键显示/隐藏已完成任务、折叠象限、手动排序和跨象限拖动排序，支持多选批量移动与象限内快速添加任务；自定义模式可直接拖拽任务并按目标象限条件自动调整；按无日期/已过期/今天/明天/未来/已完成分组，简化模式可拖拽任务修改优先级
- 习惯页：独立 `/tasks/habit` 路由，支持周视图、列表/卡片、习惯创建编辑、按天/按周/按间隔频率、完成量目标与部分进度环、快捷步进打卡、打卡/补卡与例外日期、未来日期禁用、打卡样式切换、分组管理、卡片视图频率/目标/分组信息、拖拽排序、活跃/已归档筛选、归档批量恢复与删除、月历热力、统计、日志编辑、今天/日历快捷打卡、日历月周日日程中的习惯条目、习惯详情深链、专注计时、专注历史与本月专注图表、单习惯导出、只读分享链接与访问限流、Dida XLSX 导入、并发打卡幂等、可配置提醒时区、站内/Web Push/邮件提醒、坚持目标进度、自动打卡日志、CSV/JSON 导出、Dida 风格 XLSX 导出、JSON 备份导入（新增副本/跳过同名/覆盖同名）
- 倒数纪念日：独立 `/tasks/countdown` 路由，支持纪念日/倒数日/生日/节日、今天与剩余天数/小时/分钟/秒、年度/月度/每周/周末重复、公历与农历日期、农历节日预设、闰月回退与农历边界处理、生日年龄、置顶、归档、备注、卡片详情、样式/颜色/背景预设、自定义背景图与深色主题文字适配、拖拽排序、提醒偏移与自定义提醒时间，以及站内通知/Web Push/邮件提醒
- PWA：管理后台可安装到桌面/主屏幕，内置 manifest、图标和离线静态 shell；离线时仍需要恢复网络才能读写任务数据
- 专注页：独立 `/tasks/focus` 路由，支持番茄计时 / 正计时、开始暂停继续结束、圆形进度、今日与累计统计、专注记录分组与删除、手动补记、任务/习惯关联与任务选择器分组筛选、专注笔记、番茄与休息节奏、自动开始、提示音、标签页倒计时、7 天趋势、最佳专注时段和年度热力图、独立 7/30/90/365 天统计页与 CSV 导出、SSE 多端计时实时同步与远程变更提示
- 统计页：总览/任务/专注/完成四个 Tab；任务未完成/已完成/逾期/完成率、每日新建与完成趋势、到期折线、按清单/标签/优先级分布、7/30/90 天周期概览；专注 KPI、每日专注、模式与专注对象；完成趋势与按清单完成情况
- 摘要页：按日期/清单/状态/优先级/标签生成可编辑 Markdown 摘要；支持分组、显示字段、下一周期、AI 内容优化、服务端模板/历史、复制与导出
- AI 助手：接入 OpenAI 兼容接口，通过 SSE 流式显示回复，通过工具调用查询/创建/修改/完成/删除任务、创建清单、读取统计；支持对话中切换模型
- AI 语音输入：支持浏览器 Web Speech API 的浏览器可直接口述任务
- AI 设置：选择服务商自动填充接口地址，填写 API Key 后可拉取模型，列表带推荐/工具调用/视觉/推理等标签；支持连接与工具调用测试、对话顶部切换模型、多候选自动回退、最近模型和耗时统计；也支持环境变量初始化
- 重复任务：每天、工作日、每周、每月、每年，或自定义 RRULE；完成后自动滚到下一次，支持“跳过本次”，并保留每次完成/跳过历史
- 多提醒：一个任务可设置最多 10 个提醒（准时、提前 5 分钟 / 15 分钟 / 1 小时 / 1 天或客户端自定义），每个提醒写入独立 CalDAV `VALARM`；同时支持页面内浏览器提醒、服务端 Web Push 与 SMTP 邮件提醒
- 清单文件夹：把多个清单收进文件夹并折叠展示，删除文件夹后清单回到根目录
- 清单复制：右键/悬停清单可复制为副本，支持只复制未完成、复制全部保留完成状态、复制全部不保留完成状态；同时复制分组与子任务
- 看板分组：单个清单的看板可新建、重命名、左右插入、拖拽排序、删除分组；删除时可选择迁移任务或连同任务删除
- 清单共享：按用户名把清单共享给其他管理员，可授予只读或编辑权限，可直接修改现有成员角色；编辑者可在共享清单中新建、修改、完成、删除和指派任务
- 协作通知：任务被指派时生成站内通知，并尽力通过 Web Push / SMTP 邮件提醒被指派人
- 通知中心通过 SSE 实时更新未读数；任务和日程提醒都支持站内通知与“稍后 10 分钟 / 30 分钟 / 1 小时 / 1 天”，任务通知可直接完成，并由服务端重新投递站内/Push/邮件
- 任务动态：记录创建、指派、完成/重新打开，以及标题、日期、优先级、标签、备注、重复、提醒、清单变更；同一用户 2 分钟内的连续字段修改自动合并
- 任务评论：共享成员可评论，使用 `@用户名` 提及成员并触发站内/推送/邮件通知；评论支持附件（单文件最大 10MB）、图片预览和作者编辑
- 保存过滤器：按清单、标签、优先级、日期、状态、关键词组合筛选并命名保存；支持今天/明天/本周/上周/本月/上月/自定义时间段，过滤器可拖拽排序、置顶、编辑、删除
- 任务与笔记分属任务清单/笔记清单，不能跨类型移动
- 置顶：任务、清单、过滤器都可置顶，置顶项进入列表顶部或侧栏顶部图标条；顶部图标条每项可一键取消置顶；笔记清单置顶后进入顶部图标条
- 主题：内置 12 套纯色主题（默认、暗夜、晴蓝、松石、秘青、蒹葭、杏黄、桃夭、暮山紫、沉香、藏蓝、灰色），支持跟随系统深浅色
- 快捷键：全局键位（`N` 新建、`Tab+P` 置顶、`Tab+M` 完成、`G` 序列导航、`V` 切换视图等），支持重绑定、冲突检测与恢复默认；`⌘/Ctrl+K` 打开指令菜单
- 标签管理：重命名/删除标签，变更回写到所有任务与 VTODO `CATEGORIES`；每个标签可设置独立颜色
- 垃圾桶：删除后可恢复、单条彻底删除或清空垃圾桶
- 多选批量操作：批量完成、移动到清单、删除
- 手动排序：拖拽调整任务顺序并持久化
- 快速添加支持自然语言：`明天下午 3 点和张三开会 #工作 !!`
  - 中文相对日期：今天、明天、后天、今晚、周一…周日、下周一、10 月 25 日
  - 时间：`下午 3 点`、`15:30`、`3 点半`；无日期时默认当天
  - `#标签`、`!` / `!!` / `!!!` 优先级
- 任务详情：标题、备注、日期/全天、重复、提醒、清单、优先级、标签、子任务，输入后自动保存
- 逾期任务一键顺延到今天；已完成任务自动归档；删除任务清单时任务移入收集箱，删除笔记清单时笔记移入其他笔记清单
- 12 套纯色主题、跟随系统深浅色与手动切换；响应式布局支持手机浏览器
- 管理员账号拥有自己的任务空间
- **CalDAV VTODO 同步**：每个用户自动获得一个“任务”日历（slug `caldav-tasks`），工作台里的新建、修改、完成、删除都会写入标准 `VTODO` 对象；CalDAV 客户端（Apple 提醒事项、DAVx5、Thunderbird 等）对任务的修改会在下次打开工作台时回写
- 任务与客户端冲突时以工作台的最新修改为准；任务日历由工作台维护，管理后台不能删除

### 管理后台

- Vue 3 + Vite+ + Arco Design Vue 单页应用，Go `embed` 进单个二进制
- 用户创建、资料修改、密码重置、管理员权限、删除
- 日历创建、颜色、排序、时区、描述、组件类型、删除
- 新建日历时区默认 `Asia/Shanghai`（东八区），已有日历保持原时区
- 事件列表、创建（含重复规则与全天事件）、原始 ICS 编辑、查看源码、删除
- 控制台统计、客户端接入地址一键复制
- JSON API + HttpOnly/SameSite 会话、CSRF、CSP、登录限速
- 响应式布局，手机浏览器可直接管理

## 文档

- [任务工作台使用指南](docs/任务工作台.md)：界面、自然语言、重复/提醒、日历、统计、AI、VTODO 同步、配置与限制
- [专注模块复刻记录](docs/专注模块.md)：REA 证据、番茄/正计时、设置、记录、统计与未对齐项
- [倒数纪念日复刻记录](docs/倒数纪念日模块.md)：REA 证据、卡片、周期、提醒与未对齐项
- [习惯模块复刻记录](docs/习惯模块.md)：REA 证据、打卡、提醒、统计、导入导出与未对齐项
- [Admin JSON API](docs/API.md)：任务/清单/文件夹/过滤器/标签/日历/统计/AI 接口与示例
- [架构与同步设计](docs/ARCHITECTURE.md)：数据表、VTODO 对账、事件展开、统计聚合、AI 工具循环
- [实现进度与路线图](docs/ROADMAP.md)：已完成批次、提交记录、未实现能力与优先级

## 快速开始

### 本地运行

```bash
go run ./cmd/caldav-free -data ./data -addr :5232
```

首次启动会创建管理员账号。没有提供密码时会生成一个随机密码并打印在终端：

```
Initial admin password (save it now):
xxxxxxxxxxxxxxxx
```

打开 <http://localhost:5232/admin> 登录管理后台。

也可以显式指定初始管理员：

```bash
go run ./cmd/caldav-free \
  -addr :5232 \
  -data ./data \
  -admin-user admin \
  -admin-pass 'a-strong-password' \
  -external-url 'https://dav.example.com'
```

> 只有数据库为空（没有任何用户）时才会创建初始管理员。之后的账号请在后台创建。

### 编译

前端使用 Vue 3 + Vite+ + Arco Design Vue，构建产物输出到 `internal/web/dist`，再由 Go `embed` 打包：

```bash
make web-deps       # 首次安装前端依赖
make web-build      # 构建 internal/web/dist
make build          # 产出 bin/caldav-free
make test           # 运行全部测试
make run            # 本地启动
```

> `go build` 需要 `internal/web/dist` 存在；仓库已包含一次构建产物。修改前端后请先执行 `make web-build`。

前端开发模式：

```bash
cd web
npm run dev         # Vite+ dev server: http://localhost:5175/admin/
```

静态二进制（无 CGO）：

```bash
CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o caldav-free ./cmd/caldav-free
```

### Docker

```bash
docker compose up -d --build
```

或：

```bash
docker build -t caldav-free .
docker run -d --name caldav \
  -p 5232:5232 \
  -v "$PWD/data:/data" \
  -e CALDAV_ADMIN_PASSWORD='a-strong-password' \
  -e CALDAV_EXTERNAL_URL='https://dav.example.com' \
  caldav-free
```

## 配置

| 参数 | 环境变量 | 默认值 | 说明 |
| --- | --- | --- | --- |
| `-addr` | `CALDAV_ADDR` | `:5232` | HTTP 监听地址 |
| `-data` | `CALDAV_DATA` | `./data` | 数据目录（SQLite 文件位置） |
| `-admin-user` | `CALDAV_ADMIN_USER` | `admin` | 首次启动创建的管理员用户名 |
| `-admin-pass` | `CALDAV_ADMIN_PASSWORD` | 随机生成 | 首次启动管理员密码（至少 8 位） |
| `-admin-email` | `CALDAV_ADMIN_EMAIL` | 空 | 管理员邮箱（用于 calendar-user-address-set） |
| `-external-url` | `CALDAV_EXTERNAL_URL` | 自动推导 | 对外访问地址，用于管理后台展示 |
| `-caldav-url` | `CALDAV_PUBLIC_URL` | 自动推导 | 管理后台展示的 CalDAV 公网地址（例如手机隧道地址） |
| `-tls-cert` | — | 空 | TLS 证书；与 `-tls-key` 同时提供时启用 HTTPS |
| `-tls-key` | — | 空 | TLS 私钥 |
| `-debug` | — | false | 调试日志 |
| — | `CALDAV_AI_BASE_URL` | 空 | AI 接口 Base URL（OpenAI 兼容） |
| — | `CALDAV_AI_MODEL` | 空 | AI 模型名称 |
| — | `CALDAV_AI_API_KEY` | 空 | AI API Key（页面保存优先） |
| — | `CALDAV_REMINDERS` | 开启 | 设为 `off` 关闭服务端提醒调度器 |
| — | `CALDAV_REMINDER_INTERVAL` | `30s` | 调度器检查间隔，最小 `10s` |
| — | `CALDAV_PUSH_SUBJECT` | `mailto:admin@example.com` | VAPID 联系人，建议改成真实邮箱或站点 URL |
| — | `CALDAV_SMTP_ENABLED` | `0` | 设为 `1` 启用邮件提醒（页面保存后以页面配置为准） |
| — | `CALDAV_SMTP_HOST` | 空 | SMTP 服务器 |
| — | `CALDAV_SMTP_PORT` | `587` | SMTP 端口 |
| — | `CALDAV_SMTP_USER` | 空 | SMTP 用户名 |
| — | `CALDAV_SMTP_PASSWORD` | 空 | SMTP 密码或授权码 |
| — | `CALDAV_SMTP_FROM` | 空 | 发件人，缺省使用用户名 |
| — | `CALDAV_SMTP_SECURITY` | `starttls` | `starttls` / `tls` / `none` |
| `-version` | — | — | 输出版本号 |

数据库文件位于 `<data>/caldav-free.db`，使用 WAL 模式。

## 客户端接入

所有客户端都使用 **CalDAV 账户** + Basic Auth：

| 项目 | 值 |
| --- | --- |
| 服务器 / Principal URL | `https://dav.example.com/principals/{用户名}/` |
| Calendar Home | `https://dav.example.com/calendars/{用户名}/` |
| 用户名 | 后台创建的用户名（不区分大小写，存储为小写） |
| 密码 | 后台设置的密码 |
| 传输 | 推荐 HTTPS |

### Apple 日历（macOS）

日历 → 添加账户 → 其他 CalDAV 账户 → 服务器地址填 Calendar Home URL → 输入用户名密码。

### iPhone / iPad

设置 → 日历 → 账户 → 添加账户 → 其他 → 添加 CalDAV 账户 → 服务器填 `https://dav.example.com`，路径通常可留空（系统会走 `.well-known/caldav`）。

### Thunderbird

新建日历 → 位于网络上 → CalDAV → 填写用户名与 Calendar Home URL。

### DAVx5（Android）

添加账户 → 使用 URL 和用户名登录 → 选择 CalDAV → 填入 Calendar Home URL。

> 服务端只提供 CalDAV，不提供 CardDAV。DAVx5 中选择仅日历即可。

## 服务端端点

| 路径 | 说明 |
| --- | --- |
| `/.well-known/caldav` | 301 → `/`，principal 发现 |
| `/` | PROPFIND 返回当前用户 `current-user-principal` |
| `/principals/` | principal 集合 |
| `/principals/{user}/` | principal，返回 `calendar-home-set` |
| `/calendars/{user}/` | 日历集合（calendar home） |
| `/calendars/{user}/{calendar}/` | 日历集合；支持 GET 聚合 ICS |
| `/calendars/{user}/{calendar}/{name}.ics` | 日历对象资源 |
| `/admin` | Vue 管理后台（仅管理员） |
| `/admin/tasks` | 任务工作台（清单 / 看板 / 日历） |
| `/api/admin/*` | 管理后台 JSON API（会话 + CSRF） |
| `/api/admin/tasks` | 任务工作台数据与任务 CRUD |
| `/api/admin/tasks/reminders` | 提醒候选任务（页面内提醒） |
| `/api/admin/tasks/push/public-key` | Web Push VAPID 公钥 |
| `/api/admin/tasks/push/subscriptions` | 当前用户已登记的推送设备数 |
| `/api/admin/tasks/push/subscribe` | 新增或删除浏览器推送订阅 |
| `/api/admin/tasks/notifications/email` | 读取/保存 SMTP 邮件提醒设置 |
| `/api/admin/tasks/notifications/email/test` | 向当前账号邮箱发送测试邮件 |
| `/api/admin/tasks/calendar` | 指定日期范围内的 CalDAV 事件（展开重复） |
| `/api/admin/tasks/stats` | 任务统计（天数可配置） |
| `/api/admin/tasks/summary` | 按筛选条件生成摘要数据 |
| `/api/admin/tasks/summary/optimize` | AI 润色摘要 |
| `/api/admin/task-summary-documents` | 摘要模板/历史文档 CRUD |
| `/api/admin/tasks/ai/settings` | AI 模型配置（读取/保存，Key 不回传） |
| `/api/admin/tasks/ai/models` | 使用当前接口和 Key 拉取可用模型（兼容 Ollama 原生列表） |
| `/api/admin/tasks/ai/test` | 测试指定模型的对话连通性 |
| `/api/admin/tasks/ai/chat` | AI 对话与工具调用 |
| `/api/admin/tasks/ai/chat/stream` | AI 流式对话（SSE） |
| `/api/admin/tasks/{id}/attachments` | 任务附件列表/上传 |
| `/api/admin/tasks/{id}/attachments/{attachmentId}` | 下载/删除任务附件 |
| `/api/admin/calendar-subscriptions` | 日历订阅列表/新增 |
| `/api/admin/tasks/batch` | 批量完成 / 移动 / 删除 |
| `/api/admin/tasks/reorder` | 手动排序 |
| `/api/admin/tasks/{id}/restore` | 从垃圾桶恢复 |
| `/api/admin/tasks/{id}/purge` | 彻底删除垃圾桶任务 |
| `/api/admin/task-lists` | 清单 CRUD（支持文件夹） |
| `/api/admin/task-lists/{id}/shares` | 清单共享成员与角色管理 |
| `/api/admin/task-lists/{id}/members` | 清单所有者与成员列表（用于指派） |
| `/api/admin/tasks/shared` | 共享清单任务列表 |
| `/api/admin/notifications` | 站内通知列表与未读数 |
| `/api/admin/notifications/stream` | 通知未读数 SSE 流 |
| `/api/admin/notifications/read` | 单条或全部标记已读 |
| `/api/admin/notifications/{id}/snooze` | 日程通知稍后提醒 |
| `/api/admin/tasks/{id}/activities` | 任务动态时间线 |
| `/api/admin/tasks/{id}/comments` | 任务评论列表与发表评论 |
| `/api/admin/tasks/{id}/comments/{commentId}` | 编辑/删除评论 |
| `/api/admin/tasks/{id}/comments/{commentId}/attachments` | 上传评论附件 |
| `/api/admin/tasks/{id}/comments/{commentId}/attachments/{attachmentId}` | 下载/删除评论附件 |
| `/api/admin/task-folders` | 清单文件夹 CRUD |
| `/api/admin/task-filters` | 保存过滤器 CRUD |
| `/api/admin/task-tags` | 标签统计、重命名、删除 |
| `/healthz` | 健康检查 |

支持的方法：`OPTIONS`、`PROPFIND`、`PROPPATCH`、`MKCALENDAR`、`MKCOL`、`REPORT`、`GET`、`HEAD`、`PUT`、`DELETE`。

REPORT 支持：

- `calendar-query`
- `calendar-multiget`
- `sync-collection`
- `free-busy-query`

### 手动验证

```bash
BASE=http://localhost:5232
AUTH='alice:your-password'

# 发现当前 principal
curl -su "$AUTH" -X PROPFIND -H 'Depth: 0' "$BASE/"

# 创建日历
curl -su "$AUTH" -X MKCALENDAR \
  -H 'Content-Type: application/xml' \
  --data '<C:mkcalendar xmlns:C="urn:ietf:params:xml:ns:caldav" xmlns:D="DAV:"><D:set><D:prop><D:displayname>Work</D:displayname></D:prop></D:set></C:mkcalendar>' \
  "$BASE/calendars/alice/work/"

# 上传事件
curl -su "$AUTH" -X PUT \
  -H 'Content-Type: text/calendar; charset=utf-8' \
  --data-binary @event.ics \
  "$BASE/calendars/alice/work/event.ics"

# 时间范围查询
curl -su "$AUTH" -X REPORT -H 'Depth: 1' \
  -H 'Content-Type: application/xml' \
  --data '<C:calendar-query xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav"><D:prop><D:getetag/><C:calendar-data/></D:prop><C:filter><C:comp-filter name="VCALENDAR"><C:comp-filter name="VEVENT"><C:time-range start="20260101T000000Z" end="20270101T000000Z"/></C:comp-filter></C:comp-filter></C:filter></C:calendar-query>' \
  "$BASE/calendars/alice/work/"
```

## 架构

```
cmd/caldav-free/       启动入口、配置、优雅关闭
internal/auth          PBKDF2 密码哈希、随机 token
internal/store         GORM + SQLite 数据层（用户/日历/对象/同步日志）
internal/ical          iCalendar 解析、序列化、时区、重复展开、过滤、free-busy
internal/dav           CalDAV/WebDAV HTTP 处理器、XML、属性、REPORT
internal/tasks         任务快速添加的自然语言解析（日期、时间、标签、优先级）
internal/tasksync      任务与 CalDAV VTODO 集合的双向同步、冲突处理与对象恢复
internal/web           管理后台（模板、会话、CSRF、静态资源 embed）
```

数据表：

- `users`：principal 与凭据
- `calendars`：日历集合、时区、组件、sync 序号
- `objects`：ICS 原文、ETag、时间范围缓存、墓碑
- `sync_changes`：每次变更的序号日志，用于 sync-collection
- `settings`：服务端设置
- `task_folders`：清单文件夹
- `task_lists`：任务清单（每个用户一个收集箱，可归属文件夹）
- `task_filters`：保存的过滤器条件（JSON）
- `task_list_shares`：清单共享成员与角色（viewer/editor）
- `tasks.assignee`：指派人用户名
- `notifications`：站内通知（任务指派、评论、@提及、日程提醒）
- `event_reminder_deliveries`：服务端日程提醒成功投递去重记录
- `task_activities`：任务动态（创建、指派、完成、重新打开）
- `task_tag_colors`：用户标签颜色
- `matrix_views`：保存的四象限视图名称、simple/complex/custom 规则和排序
- `matrix_rule_templates`：用户保存的四象限规则模板
- `habits` / `habit_sections` / `habit_checkins` / `habit_records` / `habit_preferences`：习惯、分组、打卡、日志和偏好
- `task_comments`：任务评论与作者
- `comment_attachments`：评论附件元数据与文件内容（SQLite BLOB）
- `summary_documents`：摘要模板与历史文档（Markdown / HTML）
- `push_subscriptions`：浏览器 Web Push 订阅（endpoint、p256dh、auth）
- `reminder_deliveries`：服务端提醒成功投递记录
- `reminder_attempts`：失败投递的退避重试状态
- `tasks`：任务、备注、日期、优先级、标签、子任务、重复规则、提醒偏移、软删除标记，以及 `vtodo_uid` / `vtodo_href` / `vtodo_etag` / `sync_pending` 同步字段

### 同步模型

每次对象 PUT/DELETE 会在同一事务中：

1. 更新 `objects`；
2. `calendars.sync_seq + 1`；
3. 写入 `sync_changes(calendar_id, seq, href, op)`。

`sync-collection` 返回自 token 之后每个 href 的最新变更；删除以 `404 Not Found` 响应表示。
同步日志目前永久保留，适合个人/小团队规模。

## 备份与迁移

- 停止服务后复制 `data/caldav-free.db` 即可（WAL 模式下建议同时复制 `-wal` / `-shm`，或先停服务）。
- 也可以在运行中执行 `sqlite3 data/caldav-free.db ".backup 'backup.db'"`。
- 迁移到新机器：复制整个 data 目录，保持文件权限，重新启动。

## 反向代理与 HTTPS

强烈建议在公网部署时使用 HTTPS。Basic Auth 密码仅应通过 TLS 传输。

### Caddy

```caddyfile
dav.example.com {
    reverse_proxy 127.0.0.1:5232
}
```

### Nginx

```nginx
server {
    listen 443 ssl;
    server_name dav.example.com;
    client_max_body_size 20m;

    location / {
        proxy_pass http://127.0.0.1:5232;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_read_timeout 120s;
    }
}
```

启动时加 `-external-url https://dav.example.com`，让管理后台显示正确的接入地址（DAV 响应本身使用相对路径，不受影响）。

### systemd

```ini
[Unit]
Description=caldav-free
After=network.target

[Service]
User=caldav
ExecStart=/usr/local/bin/caldav-free -addr 127.0.0.1:5232 -data /var/lib/caldav-free -external-url https://dav.example.com
Restart=on-failure
NoNewPrivileges=true
ProtectSystem=strict
ReadWritePaths=/var/lib/caldav-free

[Install]
WantedBy=multi-user.target
```

### 局域网 HTTPS（自签名本地 CA）

如果没有公网域名，公共 CA 无法为 `192.168.x.x` 这类私有地址签发证书。可以生成一个本地 CA，并把 CA 证书安装到手机/客户端：

```bash
make tls
# 或者：./scripts/gen-local-tls.sh ./data 192.168.124.8 my-mac
```

这会生成：

```text
data/tls/ca.crt        # 安装到手机/客户端
data/tls/server.crt    # 服务端证书
data/tls/server.key    # 服务端私钥（不要外传）
```

启动 HTTPS：

```bash
./bin/caldav-free \
  -addr :5232 \
  -data ./data \
  -tls-cert ./data/tls/server.crt \
  -tls-key ./data/tls/server.key \
  -external-url https://192.168.124.8:5232
```

客户端访问：

```text
https://192.168.124.8:5232/calendars/admin/
```

手机必须先信任 `ca.crt`。以 HarmonyOS 为例：设置 → 安全 → 更多安全设置 → 加密和凭据 → 安装证书 → CA 证书。不同版本菜单名称可能略有差异。

如果手机不方便传文件，可以在电脑上临时开一个只包含 CA 证书的 HTTP 下载页：

```bash
mkdir -p data/tls/public
cp data/tls/ca.crt data/tls/public/
python3 -m http.server 8081 --bind 0.0.0.0 --directory data/tls/public
```

手机浏览器打开 `http://<电脑IP>:8081/ca.crt` 下载后安装。

> 部分系统的内置日历可能不信任用户安装的 CA。如果安装后仍提示证书错误，可改用 Cloudflare Tunnel / 反向代理 + 公网域名证书，或使用支持自定义 CA 的客户端。

### 临时公网 HTTPS（Cloudflare Quick Tunnel）

如果客户端只信任公共 CA（例如部分华为日历），又没有自己的域名，可以用 Cloudflare Quick Tunnel 临时获得一个受信任的 HTTPS 地址：

```bash
brew install cloudflared
./scripts/start-quick-tunnel.sh
```

脚本会：

- 在 `127.0.0.1:5233` 启动一个只转发 CalDAV/WebDAV 的本地代理；
- 屏蔽 `/admin`、`/login`、`/assets` 和所有 POST 请求；
- 通过 Cloudflare 生成一个 `https://xxxx.trycloudflare.com` 地址。

注意：

- 该地址会临时把 CalDAV 暴露到公网，必须使用强密码；
- URL 每次重启都会变化；
- 管理后台仍只能在局域网内访问；
- 本机休眠、断网或关闭 `cloudflared` 后隧道失效；
- 测试完成后执行 `pkill -f 'cloudflared tunnel --url'` 和 `lsof -ti tcp:5233 | xargs kill` 关闭。

## 测试

```bash
go test ./... -v
go vet ./...
```

覆盖：

- iCalendar 解析/序列化、折叠行、时区、DST、VTIMEZONE 回退
- RRULE/RDATE/EXDATE/RECURRENCE-ID、COUNT/UNTIL、全天事件
- 时间范围过滤、文本过滤、free-busy 合并
- CalDAV 发现、MKCALENDAR、PROPFIND/PROPPATCH、PUT/GET/DELETE、ETag 条件请求
- calendar-query、calendar-multiget、sync-collection（初始/增量/删除）、free-busy
- 时区属性、组件限制、extended MKCOL、管理员跨用户访问、改密后缓存失效
- GORM 数据层事务与同步日志
- 管理后台登录、CSRF、用户/日历/事件 CRUD（JSON API）
- 任务清单/任务 CRUD、智能视图计数、完成/删除、快速添加解析
- 重复任务推进、提醒字段、垃圾桶恢复/彻底删除、批量操作、手动排序
- 文件夹归类、保存过滤器条件应用、标签重命名/删除
- 日历事件范围展开、周/日/日程视图、跨日历事件叠加
- 重复 VEVENT 范围展开、跨日历事件查询与非法范围校验
- 统计接口的总数、逾期、完成率、每日趋势、清单/标签/优先级分布
- 摘要范围筛选、完成/未完成分组、下一周期、清单/标签/优先级筛选
- AI 设置保存与 Key 脱敏、服务商预设、模型列表拉取、无配置时的 503、工具调用创建任务、Mock OpenAI 上游往返
- VTODO 推送、客户端修改导入、客户端删除识别、任务日历重建
- Vue SPA 路由回退与静态资源嵌入

## 安全说明

- 密码使用 PBKDF2-SHA256（210,000 次迭代，随机盐）存储。
- 管理后台会话为服务端内存会话，12 小时过期；重启后需重新登录。
- 所有管理 POST 请求校验 CSRF token。
- 响应带 CSP、`X-Frame-Options: DENY`、`X-Content-Type-Options: nosniff`。
- 路径分段校验，拒绝 `..`、斜杠、控制字符；对象名长度限制。
- 请求体上限 12 MiB；XML 解析不启用外部实体。
- Basic Auth 失败统一返回 401，未知用户也执行一次等价开销的校验。
- 公网部署请务必配置 HTTPS，并定期备份数据库。

## 已知限制

- 任务工作台通过自动创建的 `caldav-tasks` 日历同步 `VTODO`；任务日历被客户端删除后，下次打开工作台会自动重建并恢复任务对象。
- 工作台与客户端同时修改同一任务时采用“工作台优先”的最后写入策略，不做字段级合并。
- 重复任务在完成时会把当前 VTODO 的 `DTSTART` / `DUE` 推进到下一次，不保留每次完成的历史实例；带 `COUNT` / `UNTIL` 的复杂规则会以当前到期时间重新锚定。
- 手动排序只保证当前筛选结果内的相对顺序；跨日期分组的排序在重新加载后仍以手动顺序为准。
- 服务端 Web Push 需要 HTTPS（或 localhost）、浏览器允许通知并完成设备订阅；浏览器完全退出时通知可能延迟到下次启动。
- 邮件提醒需要可用 SMTP；SMTP 密码以明文保存在 SQLite 中，建议使用应用专用授权码并限制数据库访问权限。
- 失败投递按 1 分钟、2 分钟、4 分钟…最长 2 小时退避重试，超过 6 小时补发窗口后不再发送。
- CalDAV `VALARM` 仍由客户端负责触发；页面内浏览器提醒依赖页面保持打开。
- 垃圾桶没有自动清理期限，需要手动彻底删除或清空。
- 保存过滤器、清单文件夹与标签管理属于工作台组织能力，不映射到 CalDAV 日历结构。
- 标签颜色保存在工作台，不写入 CalDAV `CATEGORIES`。
- 工作日历中的多日定时事件会按天拆分为多个片段，在月/周/日视图中分别显示。
- 工作台支持日程的结构化新建、编辑、删除、拖拽改期和 `VALARM` 提醒；重复日程编辑/删除可选“仅此次”或“整个系列”，拖拽/调整时长仍默认修改整个系列。
- 日程提醒同时支持页面内通知和服务端 Web Push/邮件；页面关闭时仍可收到服务端提醒。
- 服务端日程推送/邮件包含日历、事件文件和实例时间深链，点击后打开对应日程编辑弹窗。
- 结构化编辑会重建 VEVENT 的标准字段，客户端额外写入的自定义属性或参与者可能丢失；需要保留原始 ICS 时使用管理后台事件编辑页。
- 清单共享支持只读和编辑，并支持清单内任务指派；指派人不会写入 CalDAV。
- 指派通知包含站内消息、Web Push 和邮件，但推送/邮件依赖设备订阅和 SMTP 配置；通知不是实时推送，前端每 60 秒刷新未读数。
- 还没有评论编辑、富文本、附件和协作动态；评论不写入 CalDAV。
- 日历事件查询窗口一次最多 120 天，最多返回 2000 个实例。
- 统计基于当前仍保留的任务数据；彻底删除或清空垃圾桶会移除对应历史。
- 统计不含习惯打卡、番茄专注与 CalDAV 事件时长，仅覆盖任务工作台数据。
- 摘要编辑器为 Markdown 所见即所得（Tiptap），模板与历史文档以 Markdown 保存在服务端 SQLite；旧 HTML 文档会在打开时转换为 Markdown。
- 摘要“下一周期任务”追加的是当前范围之后同等长度时间段内到期的未完成任务，不是重复任务实例展开。
- 摘要暂不支持指派人、专注数据、进度等字段；AI 内容优化需要先配置模型。
- 摘要导出支持 HTML、PNG 图片、打印/PDF、邮件（mailto）；图片通过 SVG foreignObject + canvas 在浏览器端生成。
- AI 助手需要兼容 OpenAI Chat Completions 且支持 tools/function calling 的接口；Ollama 等本地接口也需开启对应能力。
- AI 对话通过 SSE 流式显示；工具调用轮次在服务端完成后继续流式输出最终回复，工具执行期间显示“思考中”。对话记录只保存在浏览器 localStorage，不写入服务端。
- AI 会按你的指令直接创建/修改/完成任务；删除任务会进入垃圾桶，但模型是否先确认取决于其遵循系统提示的程度。
- AI 请求会把对话、任务、清单和统计数据发送到你配置的模型服务；API Key 以明文保存在 SQLite 中，请限制数据库访问权限。
- 暂不支持录音转写/会议摘要、MCP / CLI / OpenClaw 自动化，也未内置模型额度计费。
- 子任务与标签分别存储在 `X-CALDDAV-CHECKLIST`、`CATEGORIES`；少数不保留扩展属性的客户端在编辑后可能丢失子任务，备注与完成状态不受影响。
- 任务智能视图的“今天”边界使用服务端默认时区 `Asia/Shanghai`；快速添加会按浏览器的时区解析自然语言日期。
- 任务工作台仅管理员可用，且只展示当前登录管理员自己的任务。
- 不实现 CardDAV（联系人）。
- 不实现 RFC 6638 日程邀请/调度（iTIP/iMIP）、scheduling inbox/outbox。
- 不实现 WebDAV 锁（LOCK/UNLOCK）与细粒度 ACL；权限模型为“所有者读写，管理员全权”。
- 同步日志不自动清理；大量历史变更后建议在维护窗口重建或归档。
- `RECURRENCE-ID;RANGE=THISANDFUTURE` 按单次覆盖处理，不扩展后续实例。
- 时区回退对无法识别的自定义 TZID 使用 VTIMEZONE 的固定偏移，跨 DST 的极少数事件可能有 1 小时偏差；常见 IANA / Windows 时区不受影响。

## License

未指定。使用前请根据你的项目需要补充许可证。
