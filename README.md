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

- 内置滴答清单风格的任务管理界面：图标栏 + 清单侧栏 + 任务列表 + 详情面板
- 智能视图：所有、今天、最近 7 天、收集箱、已完成；支持清单、标签与关键词筛选
- 三种视图模式：清单 / 看板（按清单分列，支持拖拽移动）/ 月历
- 快速添加支持自然语言：`明天下午 3 点和张三开会 #工作 !!`
  - 中文相对日期：今天、明天、后天、今晚、周一…周日、下周一、10 月 25 日
  - 时间：`下午 3 点`、`15:30`、`3 点半`；无日期时默认当天
  - `#标签`、`!` / `!!` / `!!!` 优先级
- 任务详情：标题、备注、日期/全天、清单、优先级、标签、子任务，输入后自动保存
- 逾期任务一键顺延到今天；已完成任务自动归档；删除清单时任务移入收集箱
- 深色 / 浅色主题跟随系统并可手动切换；响应式布局支持手机浏览器
- 管理员账号拥有自己的任务空间；数据独立于 CalDAV 日历对象

### 管理后台

- Vue 3 + Vite+ + Arco Design Vue 单页应用，Go `embed` 进单个二进制
- 用户创建、资料修改、密码重置、管理员权限、删除
- 日历创建、颜色、排序、时区、描述、组件类型、删除
- 新建日历时区默认 `Asia/Shanghai`（东八区），已有日历保持原时区
- 事件列表、创建（含重复规则与全天事件）、原始 ICS 编辑、查看源码、删除
- 控制台统计、客户端接入地址一键复制
- JSON API + HttpOnly/SameSite 会话、CSRF、CSP、登录限速
- 响应式布局，手机浏览器可直接管理

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
| `/api/admin/task-lists` | 清单 CRUD |
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
internal/web           管理后台（模板、会话、CSRF、静态资源 embed）
```

数据表：

- `users`：principal 与凭据
- `calendars`：日历集合、时区、组件、sync 序号
- `objects`：ICS 原文、ETag、时间范围缓存、墓碑
- `sync_changes`：每次变更的序号日志，用于 sync-collection
- `settings`：服务端设置
- `task_lists`：任务清单（每个用户一个收集箱）
- `tasks`：任务、备注、日期、优先级、标签、子任务与软删除标记

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

- 任务工作台的数据暂未映射为 CalDAV `VTODO` 对象，因此不会自动同步到手机端日历/待办应用；日历视图展示的是任务自身的到期日，与 CalDAV 事件相互独立。
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
