# syntax=docker/dockerfile:1

# 管理后台（web/）默认打进镜像：镜像必须自带前端，不能依赖宿主机先跑一遍
# 构建、也不能依赖仓库里已有的 internal/web/dist（.dockerignore 刻意把它排除）。
# 用 bookworm-slim 而不是 alpine：vite-plus(rolldown) 的 native binding 是 glibc 构建。
FROM node:24-bookworm-slim AS frontend
WORKDIR /src/web
COPY web/package.json web/package-lock.json ./
RUN npm ci
COPY web/ ./
RUN npm run build

# 产物必须真的落到 internal/web/dist，否则 go:embed 打进去的是空目录，
# 镜像能起来但 /admin/ 会 500。这里提前失败，比发布后才发现好。
RUN test -s /src/internal/web/dist/index.html \
    && ls /src/internal/web/dist/assets/*.js >/dev/null 2>&1 \
    || { echo "前端产物缺失：internal/web/dist 没有 index.html 或 JS bundle" >&2; exit 1; }

FROM golang:1.26.10-alpine AS build
WORKDIR /src
RUN apk add --no-cache ca-certificates
COPY go.mod go.sum ./
RUN go mod download
COPY . .
COPY --from=frontend /src/internal/web/dist ./internal/web/dist
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o /out/caldav-free ./cmd/caldav-free

FROM alpine:3.22
RUN apk add --no-cache ca-certificates tzdata \
    && addgroup -S caldav \
    && adduser -S -G caldav -h /data caldav \
    && mkdir -p /data \
    && chown caldav:caldav /data
COPY --from=build /out/caldav-free /usr/local/bin/caldav-free
USER caldav
VOLUME ["/data"]
EXPOSE 5232
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -qO- http://127.0.0.1:5232/healthz || exit 1
ENTRYPOINT ["caldav-free"]
CMD ["-addr", ":5232", "-data", "/data"]
