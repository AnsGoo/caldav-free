#!/usr/bin/env bash
# End-to-end check of the P0 mobile network layer against a real backend.
#
#   ./scripts/p0-client-e2e.sh
#
# Requires Go and Flutter. Uses a throwaway database and admin password.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PORT="${CALDAV_P0_PORT:-5297}"
BASE="http://127.0.0.1:${PORT}"
PASSWORD="p0-e2e-$(date +%s)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/caldav-p0-e2e.XXXXXX")"
BIN="$WORK/caldav-free"
LOG="$WORK/server.log"
DATA="$WORK/data"
SERVER_PID=""

cleanup() {
  if [ -n "$SERVER_PID" ] && kill -0 "$SERVER_PID" 2>/dev/null; then
    kill "$SERVER_PID" 2>/dev/null || true
    wait "$SERVER_PID" 2>/dev/null || true
  fi
  rm -rf "$WORK"
}
trap cleanup EXIT INT TERM

FLUTTER="${FLUTTER_BIN:-}"
if [ -z "$FLUTTER" ]; then
  if command -v flutter >/dev/null 2>&1; then
    FLUTTER="$(command -v flutter)"
  elif [ -x "$HOME/development/flutter/bin/flutter" ]; then
    FLUTTER="$HOME/development/flutter/bin/flutter"
  else
    echo "flutter not found; set FLUTTER_BIN" >&2
    exit 1
  fi
fi

mkdir -p "$DATA"
echo "==> building backend"
(cd "$ROOT" && go build -o "$BIN" ./cmd/caldav-free)

echo "==> starting backend on $BASE"
CALDAV_REMINDERS=off "$BIN" \
  -data "$DATA" \
  -addr "127.0.0.1:${PORT}" \
  -admin-pass "$PASSWORD" >"$LOG" 2>&1 &
SERVER_PID=$!

for _ in $(seq 1 50); do
  if curl -fsS --max-time 1 "$BASE/healthz" >/dev/null 2>&1; then
    break
  fi
  sleep 0.2
done
if ! curl -fsS --max-time 1 "$BASE/healthz" >/dev/null 2>&1; then
  echo "backend did not start; log:" >&2
  tail -40 "$LOG" >&2
  exit 1
fi

echo "==> running mobile integration test"
(
  cd "$ROOT/mobile"
  CALDAV_SYNC_BASE="$BASE" \
    CALDAV_SYNC_USER=admin \
    CALDAV_SYNC_PASS="$PASSWORD" \
    "$FLUTTER" test --no-pub test/integration/real_server_test.dart
)

echo "==> P0 server/client e2e passed"
