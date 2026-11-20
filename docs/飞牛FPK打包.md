# 飞牛 fnOS FPK 打包

把服务端打成飞牛 NAS 的原生 `.fpk` 安装包：应用中心手动安装后，桌面出现「历记」入口，点开即用，不需要 Docker。

## 产物

| 架构 | 文件名 | 体积 |
|---|---|---|
| x86（Intel/AMD NAS） | `caldav-free-<version>-amd64.fpk` | 8.0 MB |
| ARM（RK3588 等） | `caldav-free-<version>-arm64.fpk` | 7.4 MB |

两个包共用同一份代码，区别只在 `app/server/caldav-free` 的 `GOARCH`，以及 `manifest` 里的 `platform=x86|arm`。

## 包结构

```
packaging/fnos/caldav-free/
├── manifest                     # appname/version/display_name/service_port...
├── ICON.PNG                     # 90×90
├── ICON_256.PNG                 # 256×256
├── config/
│   ├── privilege                # run-as: package，用户 caldavfree
│   └── resource                 # 目前为空对象
├── app/                         # 载荷：安装后落到 TRIM_APPDEST（target/）
│   ├── server/caldav-free       # 构建产物，不进 git
│   └── ui/
│       ├── config               # 桌面入口（端口 5232、url /）
│       └── images/icon_{64,256}.png
├── cmd/                         # 生命周期脚本
│   ├── common.sh                # 公共函数（路径解析、日志、端口探测）
│   ├── main                     # start / stop / status / log
│   ├── install_init, install_callback
│   ├── upgrade_init, upgrade_callback
│   ├── uninstall_init, uninstall_callback
│   └── config_init, config_callback
└── wizard/
    ├── install                  # 管理员用户名 + 密码
    └── uninstall                # 保留 / 删除数据
```

打包后的 `.fpk` 是 `gzip(tar)`，根目录为：`manifest`、`app.tgz`、`cmd/`、`config/`、`wizard/`、`ICON.PNG`、`ICON_256.PNG`。其中 `app.tgz` 由 `app/` 目录压缩而来，解压后就是安装后的 `target/`。

## 本地打包

```bash
# x86
./scripts/build-fnos-fpk.sh amd64
# ARM
./scripts/build-fnos-fpk.sh arm64
# 两个都打
./scripts/build-fnos-fpk.sh all
```

脚本会依次做三件事：构建前端（`web/` → `internal/web/dist`，被 `go:embed` 打进二进制）→ 交叉编译服务端 → 组装并压缩 fpk。

可用环境变量：

| 变量 | 作用 |
|---|---|
| `FPK_VERSION` | 覆盖版本号，默认取 `manifest` 里的 `version` |
| `SKIP_WEB_BUILD=1` | 跳过前端构建，复用已有 `internal/web/dist` |
| `FNPAC_BIN` | 指定官方 `fnpack`；未指定且 PATH 里也没有时，退化为等价的 `tar` 打包 |
| `FPK_GOOS=darwin` | 仅用于本机验证冒烟脚本，正式产物固定 `linux` |

服务端用的是纯 Go 的 `modernc.org/sqlite`，`CGO_ENABLED=0` 即可编译，因此 arm64 可以直接在 x86 机器上交叉编译，不需要 aarch64 工具链。

## 校验与冒烟

```bash
# 结构校验（不产出包，CI 首个 job 就是它）
./scripts/validate-fnos-fpk.sh

# 真实安装冒烟：解包 → install_init → install_callback → start → HTTP 200 → status → stop
./scripts/smoke-test-fpk.sh packaging/fnos/dist/caldav-free-2.7.1-amd64.fpk
```

冒烟测试会检查四件事：首页返回 200、`var/caldav-free.db` 已创建、日志里有 `created initial admin account`、停止后 `status` 返回 3。

## CI 流水线

飞牛包已经并进主发布流水线 `.github/workflows/release-mobile.yml` 的 `fnos` job：
发布 Release 时和六端客户端一起出包，产物统一由 `publish` job 挂到该 Release。

- **触发**：发布 Release（`release: published`）或手动 `workflow_dispatch`（补 `tag` 输入框可挂到已有 Release）。
- **版本**：直接复用 `version` job 从 `mobile/pubspec.yaml` 读到的版本号，通过 `FPK_VERSION` 传给打包脚本，和客户端产物的版本永远一致；不再单独从 ref 推导，避免两处漂移。
- **矩阵**：`amd64` 跑 `ubuntu-latest`、`arm64` 跑 `ubuntu-24.04-arm`（原生架构，冒烟测试才有意义）。
- **步骤**：结构校验 → 装 Go/Node → `build-fnos-fpk.sh <arch>` → `smoke-test-fpk.sh` → 上传 artifact。
- **产物**：`fnos-release-amd64` / `fnos-release-arm64` 两个 artifact（保留 7 天，仅作中转）；Release 事件下作为附件上传。
- **冒烟**：每个架构都跑一次真实安装启动（首页 200、数据库创建、管理员初始化、停止后 `status=3`），失败即中断。
- **开关**：仓库变量 `FNOS_CI=false` 可整体跳过这个 job，不影响其他平台。

`.github/workflows/fnos-fpk-release.yml` 保留为**手动**入口（不监听 release 事件），
只在"只想单独重打一个 FPK、不想等客户端那几条流水线"时用。

## Docker 镜像

同一条流水线的 `docker-meta` → `docker-build` → `docker-merge` 三个 job 负责镜像，
镜像本身也在 `release-mobile.yml` 里，详见 [Docker镜像.md](Docker镜像.md)。

## 安装后的路径与行为

| 项 | 值 |
|---|---|
| 访问地址 | `http://NAS_IP:5232` |
| 数据目录 | `TRIM_PKGVAR`（`/var/apps/caldav-free/var`，实际指向 `/vol{n}/@appdata/...`） |
| 数据库 | `$TRIM_PKGVAR/caldav-free.db` |
| 业务日志 | `$TRIM_PKGVAR/caldav-free.log` |
| 生命周期日志 | `$TRIM_PKGVAR/install.log` |
| 管理员口令 | `$TRIM_PKGETC/admin.env`（`chmod 600`，启动时以环境变量注入，不出现在 `ps` 里） |
| PID | `$TRIM_PKGVAR/caldav-free.pid` |

端口取自 `TRIM_SERVICE_PORT`，缺省 5232；`manifest` 里 `checkport=true`，端口被占用时应用中心会在启动前提示。

口令注入走环境变量而不是命令行参数，是为了避免 `ps`/`/proc/*/cmdline` 泄露。`install_callback` 用 `printf %q` 转义后写入，`cmd/main` 再 `source` 回来，含空格、`!`、`@` 的口令也安全（实测 `Te st@1234!` 可用）。

## 已验证

- 本机（macOS）用 `FPK_GOOS=darwin` 打同构包并跑通冒烟：首页 200、数据库创建、管理员初始化、停止后 `status=3`。
- 两架构 `app/server/caldav-free` 均为 `ELF 64-bit LSB executable, statically linked, stripped`（x86-64 / ARM aarch64）。
- 包内 `manifest` 的 `version`/`platform`/`checksum` 与产物一致；源 `manifest` 不会被打包过程改写（版本与平台只在临时暂存目录改写）。

## 已知限制

- **未在真实飞牛设备上安装验证**。结构、脚本逻辑、启动链路都在本机与 CI Linux runner 上验证过，但 fnOS 的应用中心安装流程（权限交接、端口检查、桌面入口）只能在真机确认。
- 未使用官方 `fnpack` 做最终打包（本机是 macOS，`fnpack` 只有 Linux 二进制）。当前用等价 `tar` 结构，`checksum` 字段自行按 `app.tgz` 的 md5 写入；CI 里如果想用 `fnpack`，把二进制下载到 `FNPAC_BIN` 即可，脚本会自动切换。
- `config/resource` 目前是空对象：没有声明 `data-share`，所以数据不出现在「共享文件夹」里，卸载时按向导选择保留/删除。若要暴露数据库目录，可加 `data-share` 并把 `-data` 指到 `$TRIM_PKG/shares/...`。
- 应用只有单端口 5232，没有走 HTTPS；反向代理与证书由飞牛侧或其他网关负责。
