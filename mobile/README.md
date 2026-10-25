# caldav-free mobile (P0)

Android-first Flutter client for the `caldav-free` sync protocol. The UI reads
only the local store; every write goes to a local outbox and the sync engine
pushes it in the background.

## What works

- Login with the CalDAV username/password against `/api/sync/pull`.
- Offline task create, rename, complete/uncomplete, edit notes, delete.
- Due date/time + all-day, priority, tags, subtasks, local search.
- List create/rename/delete and moving a task between lists.
- Incremental pull by cursor, batched push, ETag conflicts, `opId` idempotency.
- Local write debounce, 15 s foreground polling, pull-to-refresh, manual and
  full sync.
- CalDAV-origin VTODO changes appear on the next pull (`refresh` on full sync).
- Field-level patches: the editor sends only fields changed from its opening
  snapshot, so a concurrent server edit to an untouched field survives.
- Sync diagnostics: cursor, pending/failed/conflict counts, last error.
- Logout wipes local data and credentials.

P0 intentionally does **not** include boards, timeline, matrix, habits, focus,
countdowns, attachments, comments, sharing, SSE, background sync, or local
notifications.

## Run

```bash
cd mobile
flutter pub get          # add --offline when pub.dev is unreachable
flutter test
flutter run              # requires an Android device/emulator + SDK
```

Android emulator → host machine: use `http://10.0.2.2:5232`.
Physical device: use the LAN address, e.g. `http://192.168.1.10:5232`.
Public deployments must use HTTPS.

## End-to-end check

From the repository root:

```bash
./scripts/p0-client-e2e.sh
```

The script starts a throwaway Go backend, then runs
`test/integration/real_server_test.dart`, covering create, conflict/retry,
idempotent replay, CalDAV import, and delete. Requires Go + Flutter.

## Layout

```text
lib/core/                 models, ULID, pure merge functions
lib/data/db/              atomic JSON local store + outbox + cursor
lib/data/remote/          pull/push HTTP client and DTOs
lib/data/engine/          SyncEngine + SyncController
lib/data/session/         credentials and session
lib/data/tasks_repository.dart  local writes + outbox enqueue
lib/features/             login, tasks, diagnostics
lib/app_state.dart        session + sync wiring
```

## P0 environment deviations

This machine could not reach `pub.dev` (the Clash node was down) and has no
Android SDK/JDK/Xcode. To keep P0 runnable and testable, the implementation
uses only packages already present in the local pub cache:

| Planned | P0 shipped | Migration |
| --- | --- | --- |
| drift + SQLite | `LocalStore` over an atomic JSON file | replace `lib/data/db/local_store.dart`; engine API unchanged |
| Riverpod | `provider` + `ChangeNotifier` | move `AppState`/`SyncController` to providers |
| flutter_secure_storage | app-private `credentials.json` (plaintext) | first item of the P1 security pass |
| go_router | session-based `home` switch | add routes when the page count grows |

`android/app/src/main/kotlin/.../MainActivity.kt` exposes the app `filesDir` on
a `caldav_free/paths` MethodChannel, replacing `path_provider` (whose native
build hook required Xcode and blocked `flutter test`).

## Security notes

- P0 stores the account password in plaintext inside the app-private support
  directory. Use a dedicated account and HTTPS; migrate to Keystore/Keychain in
  P1.
- `android:usesCleartextTraffic="true"` is enabled for local development. Turn
  it off (or restrict it with a network security config) for production.
- Logout clears the local task database, outbox, and credentials.
