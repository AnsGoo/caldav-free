#!/usr/bin/env bash
# Start a CalDAV-only Cloudflare Quick Tunnel.
#
# Requires:
#   - caldav-free running locally (default https://127.0.0.1:5232)
#   - cloudflared installed
#
# The admin UI is blocked by the local proxy. Only CalDAV/WebDAV paths are
# forwarded. The generated https://*.trycloudflare.com URL changes whenever
# this script is restarted.
set -euo pipefail

cd "$(dirname "$0")/.."

if ! command -v cloudflared >/dev/null 2>&1; then
  echo "cloudflared is required: brew install cloudflared" >&2
  exit 1
fi

if ! curl -sk --max-time 3 https://127.0.0.1:5232/healthz >/dev/null; then
  echo "caldav-free does not appear to be running on https://127.0.0.1:5232" >&2
  exit 1
fi

python3 scripts/cloudflared-caldav-proxy.py \
  --listen 127.0.0.1:5233 \
  --upstream 127.0.0.1:5232 &
PROXY_PID=$!
trap 'kill "$PROXY_PID" 2>/dev/null || true' EXIT INT TERM

exec cloudflared tunnel --url http://127.0.0.1:5233 --no-autoupdate --protocol http2
