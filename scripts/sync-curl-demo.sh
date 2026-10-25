#!/usr/bin/env bash
# End-to-end demo of the caldav-free client sync protocol.
#
#   CALDAV_SYNC_PASS=your-password ./scripts/sync-curl-demo.sh http://127.0.0.1:5232 admin
#
# It simulates two devices editing the same task, proves conflict detection and
# idempotent retries, and shows a CalDAV-side write appearing in the next pull.
set -euo pipefail

BASE="${1:-http://127.0.0.1:5232}"
USER_NAME="${2:-${CALDAV_SYNC_USER:-admin}}"
PASS="${CALDAV_SYNC_PASS:?set CALDAV_SYNC_PASS to the account password}"
BASE="${BASE%/}"
STAMP="$(date +%s)"
LIST_ID="01curl${STAMP}list"
TASK_ID="01curl${STAMP}task"

need() { command -v "$1" >/dev/null || { echo "missing dependency: $1" >&2; exit 1; }; }
need curl
need jq

say() { printf '\n== %s\n' "$*"; }

pull() {
  curl -sS -u "${USER_NAME}:${PASS}" "${BASE}/api/sync/pull?since=${1}&limit=500${2:-}"
}

push() {
  curl -sS -u "${USER_NAME}:${PASS}" -H 'Content-Type: application/json' \
    -X POST "${BASE}/api/sync/push" --data-binary @-
}

fail() { echo "ASSERTION FAILED: $*" >&2; exit 1; }

say "1. initial pull (also creates the inbox on first use)"
INITIAL="$(pull 0 '&refresh=1')"
echo "$INITIAL" | jq -c '{cursor, hasMore, lists: (.lists|length), tasks: (.tasks|length), tombstones: (.tombstones|length)}'
CURSOR="$(echo "$INITIAL" | jq -r '.cursor')"
INBOX_ID="$(echo "$INITIAL" | jq -r '.lists[] | select(.isInbox == true) | .id' | head -1)"
[ -n "$INBOX_ID" ] || fail "no inbox in pull response"
echo "inbox=$INBOX_ID cursor=$CURSOR"

say "2. device A creates a list and a task"
LIST_RESULT="$(push <<JSON
{"deviceId":"device-a","ops":[
  {"opId":"list-${STAMP}","entity":"list","entityId":"${LIST_ID}","action":"create",
   "patch":{"name":"curl 清单 ${STAMP}","color":"#0ea5e9"}}
]}
JSON
)"
echo "$LIST_RESULT" | jq -c '.results[] | {opId, status, etag, id: .entity.id}'
[ "$(echo "$LIST_RESULT" | jq -r '.results[0].status')" = "ok" ] || fail "list create"

TASK_RESULT="$(push <<JSON
{"deviceId":"device-a","ops":[
  {"opId":"task-${STAMP}","entity":"task","entityId":"${TASK_ID}","action":"create",
   "patch":{"listId":"${LIST_ID}","title":"两端并发修改","notes":"初始备注",
            "due":"2026-10-26T09:00:00Z","priority":2,"tags":["sync"],
            "reminderOffsets":[30]}}
]}
JSON
)"
echo "$TASK_RESULT" | jq -c '.results[] | {opId, status, etag, title: .entity.title, version}'
CREATE_ETAG="$(echo "$TASK_RESULT" | jq -r '.results[0].etag')"
[ "$(echo "$TASK_RESULT" | jq -r '.results[0].status')" = "ok" ] || fail "task create"
[ -n "$CREATE_ETAG" ] || fail "missing create etag"

say "3. device B performs a full pull and sees the same entities"
FULL="$(pull 0)"
echo "$FULL" | jq -c --arg id "$TASK_ID" '.tasks[] | select(.id==$id) | {id, listId, title, notes, etag, version}'
B_CURSOR="$(echo "$FULL" | jq -r '.cursor')"
[ "$(echo "$FULL" | jq -r --arg id "$TASK_ID" '[.tasks[] | select(.id==$id)] | length')" = "1" ] || fail "device B did not see the task"

say "4. both devices edit the same revision: first wins, second conflicts"
A_RESULT="$(push <<JSON
{"deviceId":"device-a","ops":[
  {"opId":"a-${STAMP}","entity":"task","entityId":"${TASK_ID}","action":"update",
   "baseEtag":"${CREATE_ETAG}","patch":{"title":"A 改的标题"}}
]}
JSON
)"
echo "$A_RESULT" | jq -c '.results[] | {opId, status, etag, title: .entity.title}'
ETAG_A="$(echo "$A_RESULT" | jq -r '.results[0].etag')"
[ "$(echo "$A_RESULT" | jq -r '.results[0].status')" = "ok" ] || fail "A update"

B_RESULT="$(push <<JSON
{"deviceId":"device-b","ops":[
  {"opId":"b-${STAMP}","entity":"task","entityId":"${TASK_ID}","action":"update",
   "baseEtag":"${CREATE_ETAG}","patch":{"notes":"B 改的备注"}}
]}
JSON
)"
echo "$B_RESULT" | jq -c '.results[] | {opId, status, error, serverTitle: .entity.title, serverEtag: .etag}'
[ "$(echo "$B_RESULT" | jq -r '.results[0].status')" = "conflict" ] || fail "B should conflict"

say "5. device B retries on top of A's ETag; both fields now survive"
B_RETRY="$(push <<JSON
{"deviceId":"device-b","ops":[
  {"opId":"b-retry-${STAMP}","entity":"task","entityId":"${TASK_ID}","action":"update",
   "baseEtag":"${ETAG_A}","patch":{"notes":"B 改的备注"}}
]}
JSON
)"
echo "$B_RETRY" | jq -c '.results[] | {opId, status, etag, title: .entity.title, notes: .entity.notes}'
ETAG_B="$(echo "$B_RETRY" | jq -r '.results[0].etag')"
[ "$(echo "$B_RETRY" | jq -r '.results[0].status')" = "ok" ] || fail "B retry"

say "6. replaying an acknowledged opId is a no-op"
REPLAY="$(push <<JSON
{"deviceId":"device-a","ops":[
  {"opId":"a-${STAMP}","entity":"task","entityId":"${TASK_ID}","action":"update",
   "baseEtag":"${CREATE_ETAG}","patch":{"title":"A 改的标题"}}
]}
JSON
)"
echo "$REPLAY" | jq -c '.results[] | {opId, status, etag}'
[ "$(echo "$REPLAY" | jq -r '.results[0].etag')" = "$ETAG_A" ] || fail "replay should return the stored result"

say "7. a CalDAV client writes the same task collection"
curl -sS -o /dev/null -w 'CalDAV PUT status=%{http_code}\n' \
  -u "${USER_NAME}:${PASS}" -H 'Content-Type: text/calendar; charset=utf-8' \
  -X PUT "${BASE}/calendars/${USER_NAME}/caldav-tasks/curl-demo-${STAMP}.ics" --data-binary @- <<ICS
BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//caldav-free//sync-demo//EN
BEGIN:VTODO
UID:curl-demo-${STAMP}
DTSTAMP:20261025T000000Z
SUMMARY:来自 CalDAV 的任务 ${STAMP}
STATUS:NEEDS-ACTION
END:VTODO
END:VCALENDAR
ICS
CALDAV_PULL="$(pull "$B_CURSOR" '&refresh=1')"
echo "$CALDAV_PULL" | jq -c '.tasks[] | select(.title | startswith("来自 CalDAV")) | {id, title, etag}'
[ "$(echo "$CALDAV_PULL" | jq -r '[.tasks[] | select(.title | startswith("来自 CalDAV"))] | length')" -ge 1 ] \
  || fail "CalDAV-side task was not imported into the sync journal"
B_CURSOR="$(echo "$CALDAV_PULL" | jq -r '.cursor')"

say "8. delete with a stale ETag conflicts, then succeeds"
STALE_DELETE="$(push <<JSON
{"deviceId":"device-a","ops":[
  {"opId":"delete-stale-${STAMP}","entity":"task","entityId":"${TASK_ID}","action":"delete",
   "baseEtag":"${CREATE_ETAG}"}
]}
JSON
)"
echo "$STALE_DELETE" | jq -c '.results[] | {opId, status, error}'
[ "$(echo "$STALE_DELETE" | jq -r '.results[0].status')" = "conflict" ] || fail "stale delete should conflict"

DELETE_RESULT="$(push <<JSON
{"deviceId":"device-a","ops":[
  {"opId":"delete-${STAMP}","entity":"task","entityId":"${TASK_ID}","action":"delete",
   "baseEtag":"${ETAG_B}"}
]}
JSON
)"
echo "$DELETE_RESULT" | jq -c '.results[] | {opId, status, etag}'
DELETE_ETAG="$(echo "$DELETE_RESULT" | jq -r '.results[0].etag')"
[ "$(echo "$DELETE_RESULT" | jq -r '.results[0].status')" = "ok" ] || fail "delete"

say "9. the deletion is visible to the other device"
AFTER_DELETE="$(pull "$B_CURSOR")"
echo "$AFTER_DELETE" | jq -c --arg id "$TASK_ID" '.tasks[] | select(.id==$id) | {id, deleted, deletedAt, etag}'
[ "$(echo "$AFTER_DELETE" | jq -r --arg id "$TASK_ID" '[.tasks[] | select(.id==$id and .deleted==true)] | length')" = "1" ] \
  || fail "deleted task not visible"

say "done"
echo "task=$TASK_ID finalEtag=$DELETE_ETAG"
