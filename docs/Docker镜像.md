# Docker 镜像

服务端是一个静态编译的 Go 二进制，镜像很小（约 30 MB），跑起来只需要一个数据目录和一个端口。

## 镜像构成

`Dockerfile` 是三段式：

| 阶段 | 基础镜像 | 干什么 |
|---|---|---|
| `frontend` | `node:24-bookworm-slim` | `npm ci` + `npm run build`，产物落到 `/src/internal/web/dist`（Vite 的 `outDir` 指到仓库内的 `internal/web/dist`） |
| `build` | `golang:1.26.10-alpine` | 先 `go mod download` 单独成层（改代码不会重下依赖），再 `CGO_ENABLED=0` 编译，静态链接，不挑 libc |
| 运行 | `alpine:3.22` | 只有二进制 + `ca-certificates` + `tzdata`，以非 root 用户 `caldav` 运行 |

前端产物是被 `internal/web/spa.go` 用 `go:embed` 打进二进制的，所以运行阶段只有一个可执行文件，不需要再带静态目录。

**管理后台默认随镜像分发**，不依赖任何宿主机产物：`.dockerignore` 刻意排除了仓库里可能存在的 `internal/web/dist`，`web/` 源码在 `frontend` 阶段现场构建。构建结束后还有一道断言（`test -s …/index.html` + `assets/*.js`）——产物缺失会让构建当场失败，而不是发出去一个 `/admin/` 500 的镜像。

前端基础镜像用 `node:24-bookworm-slim`（glibc）而不是 alpine：vite-plus / rolldown 的 native binding 是 glibc 构建，在 musl 上会挂。

```dockerfile
USER caldav
VOLUME ["/data"]
EXPOSE 5232
HEALTHCHECK ... CMD wget -qO- http://127.0.0.1:5232/healthz || exit 1
ENTRYPOINT ["caldav-free"]
CMD ["-addr", ":5232", "-data", "/data"]
```

`/healthz` 是服务自身的健康检查端点（返回 200 即就绪），不是 TCP 探活。

## 本地构建与运行

```bash
# 构建
docker build -t caldav-free:dev .

# 跑起来（首次启动会在日志里打印初始化管理员口令）
docker run -d --name caldav-free \
  -p 5232:5232 \
  -e CALDAV_ADMIN_PASSWORD='换成你的口令' \
  -v caldav-data:/data \
  caldav-free:dev

docker logs -f caldav-free
```

或者直接用仓库里的 `docker-compose.yml`：

```bash
docker compose up -d --build
docker compose logs -f
```

访问 `http://localhost:5232/admin/` 进管理后台，`http://localhost:5232/healthz` 看状态。

## 配置

所有参数都支持 `-flag` 和同名环境变量，环境变量优先（`flag` 的默认值就是读环境变量）。

| 环境变量 | 命令行参数 | 默认值 | 说明 |
|---|---|---|---|
| `CALDAV_ADDR` | `-addr` | `:5232` | 监听地址 |
| `CALDAV_DATA` | `-data` | `./data` | 数据目录（镜像里是 `/data`） |
| `CALDAV_ADMIN_USER` | `-admin-user` | `admin` | 初始化管理员用户名 |
| `CALDAV_ADMIN_PASSWORD` | `-admin-pass` | 空 | **只在数据库为空时生效**；留空则随机生成并打印到日志 |
| `CALDAV_ADMIN_EMAIL` | `-admin-email` | 空 | 初始化管理员邮箱 |
| `CALDAV_EXTERNAL_URL` | `-external-url` | 空 | 对外地址，如 `https://dav.example.com` |
| `CALDAV_PUBLIC_URL` | `-caldav-url` | 空 | 管理后台里展示的 CalDAV 地址，默认取请求来源 |

`CALDAV_ADMIN_PASSWORD` 只在首次启动（数据库不存在）时使用，之后改它不会改口令，要用管理后台重置。

## CI 多架构构建

在 `.github/workflows/release-mobile.yml` 里，和客户端、飞牛包同一条发布流水线：

| Job | 作用 |
|---|---|
| `docker-meta` | 决定推哪个仓库、生成标签清单 |
| `docker-build` | 矩阵双跑：`linux/amd64` 在 `ubuntu-latest`、`linux/arm64` 在 `ubuntu-24.04-arm`，各推一个 `temp-<arch>-<run_id>` |
| `docker-smoke` | 两架构各拉自己的 `temp-*` 镜像起容器，验证 `/healthz` 200、`/admin/` 返回管理后台页面且 JS bundle 可取 —— 保证前端真的打进了镜像 |
| `docker-merge` | 用 `docker buildx imagetools create` 把两个镜像合并成多架构 manifest list（smoke 不过不会合并） |

**为什么不用一个 job 走 QEMU**：Dockerfile 里有 `npm ci` 和 `go build` 两次真编译，模拟 arm64 会慢一个量级；两个原生 runner 并行反而更快更稳。

**推到哪**：

- 仓库配了 `secrets.DOCKERHUB_USERNAME` + `secrets.DOCKERHUB_TOKEN` → `docker.io/<user>/caldav-free`
- 没配 → `ghcr.io/<owner>/caldav-free`，用 `GITHUB_TOKEN` 推送（job 已声明 `packages: write`），不需要额外 secret

**标签策略**：

| 标签 | 何时出现 |
|---|---|
| `<tag>`（如 `v2.7.1`） | 总是 |
| `<version>`（如 `2.7.1`） | 总是 |
| `sha-<7 位>` | 总是 |
| `latest` | 仅正式 tag —— tag 名里带 `-`（`-rc`、`-beta` 之类）时不覆盖 |

**缓存**：只用 `type=registry`（缓存存在镜像仓库里，每个架构独立 tag），不占 GitHub Actions 的缓存额度 —— 这个仓库整体禁用 Actions 缓存。冷构建约 2~3 分钟，命中后 30 秒级。

**注意**：手动 `workflow_dispatch` 也会推镜像，版本号取 `mobile/pubspec.yaml` 里的当前值。只想试跑流水线又不想动 `latest` 时，先把仓库变量 `DOCKER_CI` 设为 `false`。

**开关**：仓库变量 `DOCKER_CI=false` 跳过整组 job（和 `HARMONY_CI`、`FNOS_CI` 一个套路）。

## 使用镜像

```bash
# 多架构，装的时候自动取对应架构
docker pull ghcr.io/ansgoo/caldav-free:latest

# 或者钉版本
docker pull ghcr.io/ansgoo/caldav-free:2.7.1
```

`docker-compose.yml` 里把 `build: .` 换成 `image: ghcr.io/ansgoo/caldav-free:2.7.1`，就是纯拉取部署。

## 已知限制

- **镜像里没有 HTTPS**。服务本身支持 `-tls-cert` / `-tls-key`，但更常见的做法是前面挂一层反向代理（Caddy / Nginx / Traefik）终止 TLS。CalDAV 客户端走 Basic Auth，明文 HTTP 下凭据是裸的。
- **GHCR 包默认私有**。第一次推送后要在 GitHub → Packages 里把可见性改成 public，否则 `docker pull` 需要登录。
- **临时标签不清理**。`temp-*` 与 `buildcache-*` 标签会留在仓库里：Docker Hub 和 GHCR 都没有删标签的 CLI，而它们只是 manifest 指针，几乎不占空间。
- **镜像只包含服务端**。客户端（Windows / macOS / Android / iOS / 鸿蒙）不在镜像里，见各自的打包文档。
