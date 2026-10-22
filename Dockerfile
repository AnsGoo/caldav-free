# syntax=docker/dockerfile:1

FROM golang:1.26-alpine AS build
WORKDIR /src
RUN apk add --no-cache ca-certificates
COPY go.mod go.sum ./
RUN go mod download
COPY . .
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
