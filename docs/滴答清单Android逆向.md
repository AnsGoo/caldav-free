# 滴答清单 Android 8.2.2.0 逆向报告

> 目标：`app/E5A9E31447FABA8FA6ED0F27D250A680.apk`
> 目的：为「用 Flutter 重写 Android / iOS / macOS / Windows / HarmonyOS Next 客户端」提供事实依据
> 本轮边界：**只做静态逆向 + 架构方案**，不写业务代码、不抓包、不登录、不运行 APK

---

## 0. 结论摘要

| # | 结论 | 置信度 | 依据 |
| --- | --- | --- | --- |
| 1 | 原生 Kotlin/Java 应用，非 React Native / Flutter / WebView 壳 | 高 | 4 个 dex、13,337 个类、无 JS bundle、原生 View/Activity |
| 2 | 本地库是 **SQLDelight（主）+ greenDAO（历史遗留）**，离线优先 | 高 | `AppDatabase`/`DatabaseDriverFactory`、`greendao/`、建表 SQL 内嵌在 dex |
| 3 | 同步是 **checkPoint 增量拉取 + 本地 outbox 推送**，不是整表重拉 | 高 | `SyncService.pull()/commit()`、`SYNC_STATUS` 表 |
| 4 | 任务/清单/标签/过滤器/看板列各有独立 `batch` 写接口，返回 `id2etag` + `id2error` | 高 | `BatchApi`、`BatchUpdateResult` |
| 5 | 支持离线：本地先写、打脏标记，联网后批量补传；冲突用 ETag + 上次同步快照 | 高 | `TASK_SYNCED_JSON`、`skipETagCheck`、`handleExistedError` |
| 6 | 客户端自带自然语言解析（JNI），不依赖服务端 | 高 | `libnative_parser.so` 导出 `TitleParserLib.parseTitle` |
| 7 | 应用级证书固定（pinning）未观察到 | 中 | dex 中仅 OkHttp 自带 `CertificatePinner`，无 app 侧 pin 配置 |
| 8 | 资源路径被混淆（`res/-2.xml` 这类），常规 `res/xml/...` 已不存在 | 高 | APK 条目清单 |

**对自研客户端的直接影响**：照抄「checkPoint + outbox + ETag 回写」这套模型即可，但当前 `caldav-free` 后端还没有等价接口，需要补 3 个 API（见 §11）。

---

## 1. 取证方式与可复现性

| 项 | 内容 |
| --- | --- |
| REA | `open_binary` + `inspect_artifact`，证据 `ev_17c6517b4f5ccd0e99ef8605688455d495992a05f45da0ca4d8398968b90bb05`；成员清单 `ev_c7827812a462fb23083eb6225a6da8a356a54b3a3eb179e456b92147eedb64f7` |
| APK SHA-256 | `841c8c44192d994b0e07c4ebe1cb1c70844e0be1485f5ba2ccf2451cd395805a` |
| 体积 | 43,543,178 字节；18,419 个 zip 条目（REA coverage: examined 18419 / total 18419） |
| 反编译 | JADX 1.5.6 + OpenJDK 17.0.21（`jadx -d out --no-res`，13,337 个类，138 个类反编译失败） |
| 清单解析 | 自写 AXML 解析器（二进制 `AndroidManifest.xml`） |
| 字符串取证 | 自写 DEX string pool 提取（4 个 dex 合计 299,986 条，去重 213,703 条；37,071 个类型描述符，其中 `com.ticktick.task.*` 13,647 个） |
| 运行时 | **未执行**：无模拟器、无账号、未抓包 |

> REA 的 Android provider 需要 `REA_JADX_MCP_JAR`（jadx-headless-mcp 0.7.1）与 JDK 17，本轮只装了 JDK/JADX CLI，因此代码级取证用 JADX 直接完成；REA 仍用于产物身份与成员清单。这是工具链差异，不是证据强度差异。

**证据分级约定**：本文用「实测/观察到」表示直接读到的代码或产物；「推断」表示由命名或结构推出、未验证；「未知」明确列出。

---

## 2. 产物画像

### 2.1 身份

| 字段 | 值 |
| --- | --- |
| package | `cn.ticktick.task`（中国版「滴答清单」，国际版为 `com.ticktick.task`） |
| versionName | `8.2.2.0` |
| versionCode | `8220` |
| minSdkVersion | 26（Android 8.0） |
| targetSdkVersion | 37 |
| compileSdk / platformBuildVersion | 37 |
| Application 类 | `cn.ticktick.task.TickTickApplication` |
| ABI | `arm64-v8a`、`armeabi-v7a` |
| dex | `classes.dex` ~ `classes4.dex`，合计 39.2 MB |

### 2.2 组件规模

| 类型 | 数量 |
| --- | --- |
| Activity | 231（另有 27 个 activity-alias） |
| Service | 43 |
| BroadcastReceiver | 49 |
| 权限 | 55（含华为/小米/OPPO/vivo/荣耀 推送与角标权限、Any.do / Google Tasks 任务读取权限） |

组件数量本身就是功能复杂度的侧写：25 个桌面小组件、悬浮球、快捷设置磁贴、手表/穿戴、打印、课程表、自习室、年度报告都在壳内。

### 2.3 原生库

| so | 作用 | 依据 |
| --- | --- | --- |
| `libnative_parser.so` | 自然语言任务解析（JNI） | `Java_com_ticktick_task_utils_TitleParserLib_parseTitle` 等导出 |
| `libsecuritychecknativelib.so` | 安全时间戳/完整性校验 | `getSecurityTimestamp` |
| `libmmkv.so` | KV 存储（偏好/设备 ID） | MMKV 官方 so |
| `libmsc.so` | 科大讯飞语音识别 | `msp_*`、`luaopen_http_*` |
| `libbugsnag*.so` | 崩溃上报 / ANR / root 检测 | `performNativeRootChecks` |
| `libweibosdkcore.so` | 微博 SDK 签名 | `calcOauthSignNative` |

---

## 3. 技术栈

| 层 | 选型 | 观察点 |
| --- | --- | --- |
| 语言 | Kotlin（metadata `mv=1.7/1.9`）+ Java | 大量 `@kotlin.Metadata`、`kotlin.jvm.internal.m` 空检查 |
| UI | 原生 View/Activity + Fragment（非 Compose） | 231 Activity + 27 alias、`androidx.appcompat`、自定义 `actionbar/` |
| 本地库 | **SQLDelight 2.x** | `AppDatabaseQueries`、`DatabaseDriverFactory`、`createDriver$schemaProxy` |
| 历史库 | greenDAO + SQLCipher 可选 | `greendao/`、`dao/`、`SqlCipherEncryptedHelper` |
| 序列化 | kotlinx.serialization | `$$serializer`、`@bk.g`（`kotlinx.serialization.Serializable`） |
| 网络 | OkHttp（`gl.*` 混淆映射）+ Retrofit 注解（`mm.*`） | `HttpRequestInterceptor` 直接改 `Request.Builder` |
| 异步 | 响应式包装 `k8.a<T>`（推断为 RxJava/Flow 适配）+ Kotlin 协程 | `k8.a<SignUserInfo>` |
| 后台 | WorkManager + AlarmManager 精确闹钟 | `WorkSpec` 表、`setExactAndAllowWhileIdle` |
| 偏好 | MMKV | `libmmkv.so`、`com.ticktick.kernel.preference` |
| 监控 | Bugsnag（含 NDK/ANR/root detection） | so + `Bugsnag` 类 |
| 推送 | 自建 `PushJobService` + 华为/小米/OPPO/vivo/荣耀通道 | manifest receiver + `push/register` 接口 |
| 支付 | 微信 / 支付宝 / Stripe / PayPal | `wxapi/`、`api/v2/payment/*` |
| 语音 | 讯飞 | `libmsc.so`、`assets/iflytek/` |
| AI | 自研 `ai/` 模块 + 独立 `ai.dida365.com` / `agent.dida365.com` | 端点 + 260 个类 |

---

## 4. 模块地图

`com.ticktick.task` 下 83 个一级子包，按 dex 类型条目排序（含内部类/匿名类，不等于源文件数）：

```
activity 4632   view 993    sync 977     helper 759   network 593
controller 556  adapter 521 data 479     utils 385    ai 260
filter 235      sort 217    service 215  greendao 212 dialog 209
watch 203       dao 199     eventbus 195 focus 186    constant 183
model 148       manager 118 share 105    timeline 53  reminder 53
quickadd 48     search 54   cache 56     theme 20     tabbars ...
```

按职责归类：

| 域 | 关键包 / 类 | 说明 |
| --- | --- | --- |
| 壳与导航 | `activity/`、`tabbars/`、`actionbar/` | 单 Activity 壳 + 大量二级 Activity |
| 同步内核 | `sync/`（`SyncService`、`sync/handler/*`）、`sync/utils/SyncStatusHandler` | 拉取、合并、提交、脏队列 |
| 数据访问 | `sync/db/*`（SQLDelight）、`dao/`+`greendao/`（遗留） | 两套 ORM 并存 |
| 网络 | `sync/network/*`、`sync/platform/*` | `BatchApi`/`TaskApi`/`GeneralApi`/`KanbanApi` |
| 任务视图 | `view/`、`adapter/`、`sort/`、`model/` | 列表/看板/时间线/矩阵的 ViewModel 与排序器 |
| 过滤器 | `filter/`（含 `FilterParseUtils`） | 规则 DSL 解析 + 编辑 UI |
| 自然语言 | `quickadd/`、`utils/TitleParser(Lib)` | 快捷添加与 `#tag`/`!优先级`/日期识别 |
| 提醒 | `reminder/`、`compat/service/job/*Alert*` | 任务/日历/每日提醒 + 稍后提醒 |
| 日历 | `calendar/`、`activity/CalendarViewActivity` 等 | 本地日历、Google/iCloud/Exchange/CalDAV 绑定 |
| 习惯 | `activity/habit/`、`utils/Habit*` | 打卡、热力、统计 |
| 专注 | `focus/`（番茄 + 正计时，前台 Service） | `PomodoroControlService` |
| 倒数日 | `activity/countdown/` | 独立模块 |
| 矩阵 | `matrix/` | 四象限视图与条件 |
| 课程表/自习室 | `activity/course/`、`cn/ticktick/task/studyroom` | 学生场景 |
| AI | `ai/` | 对话、拆解、改写 |
| 小组件 | `activity/widget/` | 25 个 AppWidgetProvider |
| 分享/协作 | `share/`、`api/v2/project/*/share` | 清单共享、任务指派、评论 |
| 安全 | `securitychecknativelib/`、`fakeapk/` | 完整性、模拟器/改包对抗 |

---

## 5. 账号与鉴权

### 5.1 登录

| 用途 | 方法与路径 | 参数 |
| --- | --- | --- |
| 账号密码登录 | `POST api/v2/user/signon` | body `NamePasswordData{username,password,phone,verCode,verKey}`，header `x-timestamp` |
| 注册 | `POST api/v2/user/signup` | 同上 + `code`（短信） |
| 短信验证码 | `POST api/v2/user/sms/code` | `SmsBindBean` |
| 第三方 OAuth | `GET/POST api/v2/user/sign/OAuth2?site=&accessToken=[&uId=]` | 微信/Apple/Google 等 |
| 微博 | `GET api/v2/user/sign/weibo/validate?code=` | |
| 登出 | `GET api/v2/user/signout` | |
| MFA | `api/v2/user/mfa/code`、`api/v2/user/sign/mfa/code/verify` | |

登录响应 `SignUserInfo` 关键字段：

```text
token, userId, username, inboxId, pro, proStartDate, proEndDate,
teamUser, activeTeamUser, subscribeType, freeTrial, gracePeriod,
phone, userCode
```

- 密码是**明文提交**（TLS 保护），客户端不做预哈希（`xf/l.java` 直接 `setPassword(...)`）。
- 请求头 `x-timestamp` 由 `SecurityHelper.getTimestamp()` 生成（具体算法未展开，属未知）。

### 5.2 请求头（`l8/a.java`，OkHttp Interceptor）

```http
Authorization: OAuth <accessToken>
X-Device: <deviceInfoWithCampaign>
x-tz: Asia/Shanghai
traceid: <generated objectId>
hl: <locale>
Accept-Language: zh-CN, zh;q=0.8, en-US;q=0.6, en;q=0.4
User-Agent: <appMessage> <version>
```

- 单用户单 token；token 存在 `AccountManager`，随 `SignUserInfo.token` 更新。
- 国际版/中国版通过域名区分（`api.ticktick.com` / `api.dida365.com`），另有 `-dev`、`-test`、`-future-test` 环境。

---

## 6. 同步协议（核心）

### 6.1 一次同步的完整顺序（`SyncService.doSync(type)`）

```text
initTaskServiceSyncStatusHandler()
pullOtherData(type)                 # 团队、用户设置、通知未读、限额……
if type != 1（非手动）: BatchCalendarSubscribeSyncManager.sync()
pullColumns()                       # 看板列，单独 checkPoint（偏好 Key: ColumnCheckPoint）
pull()                              # 主增量：/api/v3/batch/check/{point}
pullTasksOfOpenedProjects()         # 对当前打开的清单补拉任务
commit()                            # 本地脏数据逐实体批量上传
```

`type == 1` 表示手动同步，会跳过日历订阅同步。

### 6.2 拉取：`GET api/v3/batch/check/{checkPoint}?syncToken=&lastVersion=`

响应 `SyncBean`：

| 字段 | 类型 | 含义 |
| --- | --- | --- |
| `checkPoint` | long | 服务端游标，客户端保存后下次带上 |
| `syncToken` | string | 分页令牌 |
| `syncTaskBean` | object | 任务增量（见下） |
| `projectProfiles` | list | 清单/文件夹变更 |
| `projectGroups` | list | 清单分组 |
| `filters` | list | 保存过滤器 |
| `tags` | list | 标签 |
| `syncTaskOrderBean` / `syncOrderBean` / `syncOrderBeanV3` | object | 手动排序、置顶、看板列排序 |
| `checks` | list | 同步校验信息（`SyncCheckInfo`） |
| `remindChanges` | list | 稍后提醒变更 |
| `inboxId` | string | 收集箱 ID |

`SyncTaskBean`：

```text
add, update            : Task[]         # 新增 / 更新
delete                 : TaskProject[]  # 删除进回收站
deletedInTrash         : TaskProject[]
deletedForever         : TaskProject[]  # 彻底删除
addAttachments,
deleteAttachments      : Task[]         # 附件变更（挂在任务上）
tagUpdate              : TagUpdate[]
```

分页逻辑（`SyncService.pull()`，实测）：

```text
loop:
  bean = batchCheck(checkPoint, lastVersion, syncToken)
  handleSyncStatus()                    # 处理本地脏标记队列
  merge projectGroups/filters/tags/projects
  merge tasks (skipETagCheck = 版本变化)
  merge pinned/order/section/delayReminder
  handleRemoteSyncCheck(bean.checks)
  if bean.checkPoint != checkPoint: saveCheckPoint(bean.checkPoint)
  if bean.syncToken 为空 或 bean.checkPoint != 本次起点: break
  else: syncToken = bean.syncToken      # 游标未推进，继续取下一页
```

> 注意：循环里用的 `checkPoint` 是进入 `pull()` 时读到的局部值，不会被 `saveCheckPoint` 改写；所以「服务端游标 == 起点 + 有 token」才继续翻页，否则结束本轮。

- `lastVersion` = 当前 App 版本号；服务端版本变化时客户端把 `skipETagCheck` 置真，做一次「不校验 ETag」的全量合并。这是**升级后的自愈机制**。
- 看板列不在这条流里，走独立的 `ColumnCheckPoint`，按时间戳拉取。

### 6.3 推送：逐实体 batch 接口

`commit()` 的顺序（实测）：

```text
commitProjectGroup → commitAddAndUpdateProject → commitColumns
→ commitFilter → commitMoveColumn → commitMoveProject → commitAssignTask
→ commitTask → commitOrderByType → commitOrderByTypeV3
→ commitSortOrderTask → commitDeleteProject → commitRestore
→ commitTaskParent → commitDeleteForever → commitPomodoro → commitTiming
→ commitTags → commitDelayReminders → tryToClearTrash → saveSyncStatusInDB
```

| 实体 | 方法与路径 | 请求体 |
| --- | --- | --- |
| 任务 | `POST api/v2/batch/task` | `SyncTaskBean` |
| 任务删除 | `POST api/v2/tasks/delete?forever=` | `TaskProject[]` |
| 清单 | `POST api/v2/batch/project` | `SyncProjectBean{add,update,delete,exceed}` |
| 清单分组 | `POST api/v2/batch/projectGroup` | `SyncProjectGroupBean` |
| 看板列 | `POST api/v2/batch/columnProject` | `MoveColumn[]` |
| 标签 | `POST api/v2/batch/tag` | `SyncTagBean` |
| 过滤器 | `POST api/v2/batch/filter` | `SyncFilterBean` |
| 移动任务到清单 | `POST api/v2/batch/taskProject` | `MoveProject[]` |
| 父子关系 | `POST api/v2/batch/taskParent` | `TaskParent[]` |
| 手动排序 | `POST api/v2/batch/taskOrder`、`api/v2/batch/taskProjectSortOrder` | `SyncTaskOrderBean` |
| 置顶/列排序 | `POST api/v3/batch/order` | `SyncOrderBean` |
| 指派 | `POST api/v2/task/assign` | `Assignment[]` |
| 回收站恢复 | `POST api/v2/trash/restore` | `MoveProject[]` |
| 稍后提醒 | `POST api/v2/reminder/delay` | `SyncDelayReminderBean` |
| 番茄 | `POST api/v2/batch/pomodoro`、`.../pomodoro/timing` | `SyncPomodoroBean` / `SyncTimingBean` |

统一响应 `BatchUpdateResult`：

```json
{ "id2etag": { "<entityId>": "<etag>" }, "id2error": { "<entityId>": {"code": ..., "message": ...} } }
```

- 成功：把 `id2etag` 写回本地行，清脏标记。
- 失败：`handleErrorResult` 分类（已存在 / 不存在 / 已删除 / 其他）；同一次同步内**重试一次**（`if (!errorIds.isEmpty() && !tryAgain) commitXxx(true)`）。
- 这类「批量 + 逐条结果」设计是离线优先的关键：一次网络往返能提交几十条改动，并且只重传失败项。

### 6.4 本地 outbox：`SYNC_STATUS`

```sql
CREATE TABLE SYNC_STATUS (
  _id INTEGER PRIMARY KEY,
  USER_ID TEXT,
  ENTITY_ID TEXT NOT NULL,
  _type INTEGER NOT NULL,    -- 变更类型
  MOVE_FROM_ID TEXT,         -- 移动来源（清单/列）
  CREATE_TIME INTEGER
)
```

`SyncStatusHandler` 暴露的入队方法对应变更类型（实测方法名）：

```text
addSyncStatusContent   内容修改（标题/备注/日期/优先级/标签…）
addSyncStatusParent    父子关系
addSyncStatusMove      跨清单移动
addSyncStatusOrder     手动排序
addSyncStatusAssign    指派
addSyncStatusTrash     删除进回收站
addSyncStatusRestore   从回收站恢复
addSyncStatusContent + deleteSyncStatusForever   彻底删除
```

同一实体同一类型在表里**去重**（按 `USER_ID + ENTITY_ID + _type`），提交成功后清队列。这比「一条操作一行日志」更省空间，也更适合移动端。

### 6.5 冲突处理

观察到的机制：

1. 每行有 `_status`（脏标记）与 `ETAG`（服务端版本）。
2. `TASK_SYNCED_JSON` 表按任务保存**上次同步成功的服务端 JSON**：

   ```sql
   CREATE TABLE TASK_SYNCED_JSON (
     _id INTEGER PRIMARY KEY AUTOINCREMENT,
     USER_ID TEXT, TASK_SID TEXT, json TEXT
   )
   ```

3. `TaskBatchHandler` 里有 `skipETagCheck`、`handleExistedError`、`handleNotExistedError`、`handleDeletedError`、`mergeTasksOfOpenedProjects`。
4. 从命名与调用看，合并策略是「以服务端为基线，本地脏字段覆盖」的三方合并（推断），不是简单整行覆盖。
5. 服务端 `deletedInTrash` / `deletedForever` 分离，保证删除可回滚。

**未知**：字段级冲突的具体优先级（哪些字段服务端赢、哪些本地赢）无法在静态代码里一次性断言，需要构造并发修改才能验证；本文不作为结论。

---

## 7. 数据模型

### 7.1 任务（线上模型 `network.sync.entity.Task`）

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `id` | string | 任务 ID（客户端生成，24 位 objectId 风格） |
| `projectId` | string | 所属清单 |
| `title` / `content` / `desc` | string | 标题 / 富文本内容 / 备注 |
| `status` | int | 0 未完成，2 已完成（推断自 `COMPLETED_TIME` 与筛选；枚举未完整确认） |
| `priority` | int | 0 无，1 低，3 中，5 高（沿用滴答经典取值，与 Web 端一致） |
| `startDate` / `dueDate` | timestamp | 开始 / 截止 |
| `isAllDay` / `isFloating` | bool | 全天 / 浮动时间 |
| `timeZone` | string | 任务级时区 |
| `repeatFlag` | string | `RRULE:...` |
| `repeatFrom` / `repeatTaskId` / `repeatFirstDate` | | 重复来源与首次时间 |
| `exDate` | set | 重复例外日期 |
| `reminders` | list | `{id, trigger}`，`trigger` 形如 `TRIGGER:PT0S` |
| `reminder` | string | 兼容旧字段 |
| `items` | list | 子任务（`ChecklistItem`） |
| `childIds` / `parentId` | | 子任务关系 |
| `tags` | set | 标签名 |
| `columnId` | string | 看板列 |
| `sortOrder` | long | 手动排序（大整数步长） |
| `pinnedTime` | string | 置顶时间 |
| `progress` | int | 0–100 |
| `kind` | string | `TEXT` / `CHECKLIST` / `NOTE` |
| `taskType` | int | 任务子类型 |
| `attachments` | list | 附件元数据 |
| `commentCount` | int | 评论数 |
| `assignee` / `creator` / `completedUserId` | long | 协作 |
| `etag` | string | 服务端版本 |
| `modifiedTime` / `createdTime` / `completedTime` | timestamp | |
| `deleted` | int | 软删除标记 |

### 7.2 清单（`ProjectProfile`）

```text
id, name, color, sortOrder, sortType, viewMode, kind(TASK/NOTE),
groupId, closed, muted, inAll, permission, isOwner, userCount,
defaultProject, notificationOptions, teamId, teamMemberPermission,
showType, reminderType, sortOption, timeline, background,
etag, modifiedTime, deleted, status
```

- `viewMode`：`list` / `kanban` / `timeline`（与 Web 端实测一致）。
- `kind`：普通任务清单 / 笔记清单。
- `timeline`：时间线配置（颜色、显示周等）。
- `sortOption`：**每个清单自己记住的分组/排序/视图配置**（`groupBy`、`orderBy`、`_order`、`viewMode`、`timeline*`）。

### 7.3 看板列（`Column`）

```text
id, projectId, name, sortOrder, status, taskCount, etag,
createdTime, modifiedTime, deleted, uniqueId, userId
```

与 Web 端结论一致：列只是「命名桶」，没有颜色/状态/WIP 上限。

### 7.4 子任务（`ChecklistItem`）

```text
id, taskSid, title, status, sortOrder, startDate, isAllDay,
completedTime, snoozeReminderTime, timeZone, modifiedTime, etag
```

注意：子任务**可以有开始时间和提醒**，不只是勾选框。

### 7.5 标签 / 过滤器

`Tag`：`name, color, parent, children, sortOrder, sortType, isFolded, type, label, background, viewMode, timeline, etag`（支持层级与视图记忆）。

`Filter`：`name, rule, sortOrder, sortType, viewMode, timeline, sortOption, background, etag`。

**过滤器规则 DSL**（`FilterParseUtils`，实测）：

```text
类别：list | listOrGroup | group | tag | priority | dueDate |
      status | keywords | assignee | calendar | calendarAccount |
      completedTime | taskType | team | showItem

日期取值：today | tomorrow | yesterday | nextweek | offset(1M) |
          offset(-1W) | ndays | ndaysfromtoday | ndayslater |
          -ndaysfromtoday | overdue | nodue | recurring | span

标签特殊值：all | !tag（无标签） | *withtags（含子任务标签）
指派特殊值：me | anyone | noassignee | other
```

规则支持版本升级（`upgradeFilterRuleVersion`）与新旧两种格式（`isNewRule`），解析后再做条件建模（`FilterConditionModel`）。这部分是**客户端独家逻辑**，服务端只存字符串。

---

## 8. 本地数据库

SQLDelight 的建表 SQL 以字符串形式内嵌在 dex 中，可直接还原（以下为实测片段）。

### 8.1 核心表

| 表 | 作用 | 关键列 |
| --- | --- | --- |
| `Tasks2` | 任务 | `SID`、`PROJECT_SID`、`SORT_ORDER`、`TASK_STATUS`、`DUE_DATE`、`REMINDER`、`repeatFlag`、`_deleted`、`_status`、`ETAG`、`PARENT_SID`、`COLUMN_ID`、`PINNED_TIME`、`EX_DATE`、`TAG`… |
| `PROJECT` | 清单 | `SID`、`SORT_ORDER`、`VIEW_MODE`、`KIND`、`DEFAULT_COLUMN`、`GROUP_BY`、`ORDER_BY`、`_status` |
| `COLUMN` | 看板列 | `SID`、`PROJECT_SID`、`SORT_ORDER`、`STATUS` |
| `checklist_item` | 子任务 | `TASK_SID`、`CHECKED`、`SORT_ORDER`、`START_DATE`、`_status` |
| `Tags` | 标签 | `TAG_NAME`、`SORT_ORDER`、`PARENT`、`COLOR`、`VIEW_MODE` |
| `FILTER` | 过滤器 | `RULE`、`SORT_TYPE`、`VIEW_MODE`、`GROUP_BY`、`ORDER_BY` |
| `TaskReminder` | 提醒 | `TASK_SID`、`DURATION` |
| `SYNC_STATUS` | outbox | `ENTITY_ID`、`_type`、`MOVE_FROM_ID` |
| `TASK_SYNCED_JSON` | 冲突基线 | `TASK_SID`、`json` |
| `User` | 账号与游标 | `ACCESS_TOKEN`、`check_point`、`list_point`、`task_point`、`settings_point`、`column_point`、`INBOX_ID`、`PRO_TYPE` |

`User` 表把**同步游标直接挂在账号行上**，多账号天然隔离；`PASSWORD` 也在本地表里（见 §10）。

### 8.2 其它业务表

`ATTACHMENT`、`LOCATION`、`COMMENT`、`Pomodoro`、`PomodoroSummary`、`POMODORO_TASK_BRIEF`、`CalendarEvent`、`CalendarEventBlocker`、`BindCalendar`、`BindCalendarAccount`、`CalendarSubscribeProfile`、`EventAttendee`、`ProjectGroup`、`TEAM`、`Ranking`、`FeaturePromptRecord`、`Preference`、`UserProfile`、`UserPublicProfile`；另有一批 `*_SYNCED_JSON`（清单/分组/标签/过滤器）。

历史 greenDAO 表仍在：`User`、`Task`、`Project`…（与 SQLDelight 并存，迁移期产物）。

### 8.3 观察

- 任务表列数多、语义密集：一个 `Tasks2` 覆盖了日期、重复、提醒、协作、看板、置顶、附件、评论、AI 识别标记等。
- `_status`（脏标记）与 `ETAG`（服务端版本）是同步的两根支柱。
- `SERVER_DUE_DATE` / `SERVER_START_DATE` 与客户端字段并存：用于识别「本地改过时间」还是「只是显示差异」。
- `LOCAL_UNPINNED`、`CURRENT_TASK_HAS_RECOGNIZED`、`ANNOYING_ALERT` 这类字段说明产品层有大量边界状态，不是通用 TODO 模型。

---

## 9. 功能清单（面向重写）

### 9.1 任务与组织

- 任务 CRUD、子任务、附件、评论、动态、模板、复制、置顶、放弃/重新开始、进度、笔记（`kind=NOTE`）
- 清单 / 文件夹 / 分组、清单共享与指派、清单置顶、清单复制（三种范围）
- 标签（层级、颜色、合并/重命名/删除）
- 保存过滤器（普通/高级规则、日期区间、指派、日历来源）
- 视图：列表、看板（自定义列）、时间线（日/周/月）、四象限、日历、笔记
- 排序/分组：`sort/` 217 个类，支持时间、创建、修改、标题、标签、优先级、自定义顺序

### 9.2 时间与提醒

- 开始/截止/全天/时区/浮动时间
- 重复：`RRULE` + `exDate` + `repeatFrom` + 下次实例生成
- 提醒：多提醒、`TRIGGER:PT0S` 风格、稍后提醒（10 分钟/30 分钟/1 小时/1 天）、每日提醒
- 系统能力：`AlarmManager.setExactAndAllowWhileIdle`、`TaskAlertReceiver`、`CalendarAlertReceiver`、`DailyReminderReceiver`、全屏提醒、通知按钮直接完成/稍后

### 9.3 日历

- 内置日历视图（月/周/日/议程）
- 外部绑定：Google、iCloud、Exchange、Outlook、CalDAV（`BindCalDavAccountsActivity`、`api/v4/calendar/bind/*`）
- 事件与任务同屏、拖拽改期

### 9.4 扩展模块

| 模块 | 观察到的入口 |
| --- | --- |
| 习惯 | `HabitRecordActivity`、`AppWidgetProviderHabit*`、`habitCheckins` 接口、热力图/统计 |
| 专注 | 番茄 + 正计时，前台 Service + 通知控制，`pomodoro/timing` 同步 |
| 倒数日 | `CountdownDetailActivity` / `CountdownEditActivity`、单卡片小组件 |
| 矩阵 | `matrix/ui/*`、`AppWidgetProviderMatrix` |
| 课程表 | `activity/course/*`（导入、OCR、分享、周视图小组件） |
| 自习室 | `studyroom/StudyRoomActivity` + Lottie |
| AI | 对话、任务拆解、改写（`/api/v1/conversations`、`ai.*` 域名） |
| 年度报告/勋章 | `annualreport/`、分享 Activity |
| 小组件 | 25 个 Provider（今天/周/月/矩阵/习惯/专注/倒数日/快速添加/滚动列表…） |
| 穿戴 | `wear/`、`watch/`、华为/小米/OPPO/vivo 健康通道 |
| 打印 | `GuGuPrintPreviewActivity`、喵喵机（memobird）接口 |
| 迁移 | 可读 Any.do / Google Tasks 数据（manifest 权限） |

### 9.5 交互细节

- 快捷添加：`quickadd/` 48 个类 + `TitleParserLib`（JNI）
- 全局快捷键/命令面板属于桌面端能力，Android 无
- 悬浮球：`QuickBallService`
- 快捷设置磁贴：`QuickSettingsTileService`、语音添加磁贴
- 撤销：`undo/` 包
- 主题：`theme/` 20 个类 + 服务端 `user/preferences/themes`

---

## 10. 安全与合规观察

| 项 | 观察 | 评价 |
| --- | --- | --- |
| 传输 | 全量 HTTPS；manifest 未声明 `usesCleartextTraffic`；`networkSecurityConfig` 指向混淆资源，内容未解析 | 正常（细节未知） |
| 证书固定 | dex 中只有 OkHttp 自带 `CertificatePinner` 类，无 app 侧 pin 配置 | 未观察到 pinning（不等于服务端没做） |
| Token | `Authorization: OAuth <token>` | 常规 |
| 本地密码 | `User.PASSWORD` 列存在，登录代码把明文密码写入账号对象 | **风险点**：依赖本地库加密 |
| 本地库加密 | 存在 `SqlCipherEncryptedHelper`，但是否启用未确认 | 未知 |
| 完整性 | `libsecuritychecknativelib.so` + `fakeapk/` 包 | 有改包/模拟器对抗 |
| Root | Bugsnag `performNativeRootChecks` | 仅上报 |
| 资源混淆 | `res/-2.xml`、`res/_1N.xml` 等 | 常规 AndResGuard 类处理 |
| 代码混淆 | 类名基本保留（`com.ticktick.task.*` 可读），仅少量包被混淆（`gl.*`/`mm.*`/`ek.*`） | 逆向门槛低 |
| 隐私 | 55 个权限，含通讯录、日历、录音、悬浮窗、通知监听类权限 | 功能驱动，但面很宽 |

---

## 11. 与 `caldav-free` 的差距

现有后端是 **REST + CalDAV**，没有等价增量协议。

| 能力 | 滴答 Android | caldav-free 现状 | 建议 |
| --- | --- | --- | --- |
| 增量拉取 | `GET /api/v3/batch/check/{checkPoint}` | 无（列表接口 + `TaskWorkspaceRevision`） | 新增 `GET /api/admin/sync/pull?since=&limit=` |
| 批量提交 | 每实体 `POST /api/v2/batch/*` | 单条 `PATCH /api/admin/tasks/{id}` | 新增 `POST /api/admin/sync/push`（ops 数组） |
| 版本控制 | `id2etag` + `ETag` | 任务无 ETag（CalDAV 对象有） | 任务加 `version`/`etag`，冲突返回 409 |
| 删除语义 | 回收站 / 彻底删除分离 | `deleted` + 回收站 | 已有，需在增量协议中区分 |
| 实时信号 | 无（客户端定时/推送） | **已有 SSE** `/api/admin/tasks/stream` | 直接复用，作为「该拉了」的唤醒 |
| 离线 | outbox + 脏标记 | 无客户端 | 客户端实现 |
| 排序/置顶 | 独立 order 接口 | `order_index` 字段 | 增量协议里带 `reordered` 列表 |
| 过滤器 | 客户端 DSL + 服务端存字符串 | `task_filters.conditions` JSON | 语义不同，需映射（见 §12） |

---

## 12. 证据、边界与未解问题

### 12.1 证据清单

| 证据 | 内容 |
| --- | --- |
| `ev_17c6517b…`（REA） | APK 身份、6,046 节点 / 18,419 条目的归档图、完整性 0 冲突 |
| `ev_c7827812…`（REA） | 归档成员清单 |
| 本地 AXML 解析 | package/version/SDK/231 Activity + 27 alias/43 Service/49 Receiver/55 权限 |
| 本地 DEX 字符串 | 299,986 条（去重 213,703）、289 条 `/api/*` 路径、252 条 URL |
| JADX 源码 | `SyncService`、`BatchApi`、`SyncBean`、`SyncTaskBean`、`Task`、`ProjectProfile`、`Column`、`FilterParseUtils`、`HttpRequestInterceptor` 等 |
| 既有文档 | `docs/滴答视图与组织逆向.md`（Web 端实测，字段与本文互证） |

### 12.2 明确未知

1. 服务端合并算法（只看得到客户端）。
2. 字段级冲突优先级。
3. `x-timestamp` 的具体构造。
4. 本地库是否真正启用 SQLCipher。
5. `status` / `priority` / `taskType` 的完整枚举。
6. 资源混淆后的具体主题、文案与网络配置内容。
7. 未做运行时验证（无模拟器、无账号、无抓包），所有结论均来自静态产物。
8. 国际版（`com.ticktick.task`）与国内版差异未比对。

### 12.3 合规提示

本次只做互操作性研究：不绕过付费、不破解签名、不提取用户数据。重写客户端应使用**自有后端**与自有账号体系；若未来要接官方账号，需另行评估服务条款与风控风险，本文不提供该路径的实现建议。
