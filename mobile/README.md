# caldav-free mobile (P0/P1)

Android-first Flutter client for the `caldav-free` sync protocol. The UI reads
only the local store; every write goes to a local outbox and the sync engine
pushes it in the background.

## What works

- Login with the CalDAV username/password against `/api/sync/pull`.
- Offline task create, rename, complete/uncomplete, edit notes, delete.
- Start time, due date/time + all-day, priority, tags, subtasks, local search.
- Smart views: all, today (including overdue), next 7 days.
- List create/rename/delete, folders, moving lists into folders, and moving a task between lists.
- Reminders: presets and custom minutes, Android local notifications with exact
  alarms when permitted, channel `任务提醒`.
- Recurring tasks: daily/weekdays/weekly/monthly/yearly presets, custom RRULE,
  complete/skip the current occurrence.
- Trash: restore a deleted task or purge it permanently.
- Global search across all open lists; pinned tasks sort first.
- Calendar entry in the task app bar: month/week/day/agenda views, CalDAV/iCal/
  holiday events, task occurrences and task completion from the calendar.
- Create/edit/delete calendar events from the mobile app, with “this occurrence
  / entire series” handling for recurring events, and manage iCal subscriptions.
- Bottom navigation with Tasks / Calendar / Habits / Focus; habits support
  today check-in, create/edit/delete, streaks and a 30-day heatmap.
- Focus/Pomodoro timer with 25/45/60-minute sessions, pause/reset, today and
  total stats, and recent session records.
- Countdowns with solar dates, countdown/anniversary/birthday/festival types,
  yearly repeat, pinning, colors and notes.
- 2026-10 UI passes: paper-layer design tokens, icon-only five-tab navigation,
  borderless cards, underline view tabs, large focus ring, dark mode and
  1.3x font-scale support. A second pass adds eight persisted accent colors,
  a calendar view menu, 3-day and year views, holiday labels, and per-day
  lunar/solar-term/festival labels. Habits now have a week strip, per-day
  check-in history and section grouping. See `docs/客户端UI设计.md`.
- P2 views: Kanban board with custom synced columns, drag-reordered columns,
  drag-between-columns and manual card ordering; Eisenhower matrix;
  day/week/month timeline with custom start date and drag-to-reschedule.
- Multi-select in the list view for batch complete, move, delete, priority,
  due date, tags, title prefix/suffix and appended notes.
- Manual list ordering with drag handles; order is field-synced and restored
  across clients.
- Incremental pull by cursor, batched push, ETag conflicts, `opId` idempotency.
- Local write debounce, 15 s foreground polling, pull-to-refresh, manual and
  full sync.
- CalDAV-origin VTODO changes appear on the next pull (`refresh` on full sync).
- Field-level patches: the editor sends only fields changed from its opening
  snapshot, so a concurrent server edit to an untouched field survives.
- Sync diagnostics: cursor, pending/failed/conflict counts, last error.
- Logout wipes local data, cancels pending reminders, and clears credentials.

P1 intentionally does **not** include habits, focus, countdowns, attachments,
comments, sharing, SSE, background sync, or a drift/secure-storage migration.
P2 is feature-complete. P3 adds calendar views with tasks on the same timeline,
CalDAV/iCal/holiday events, event create/edit/delete and iCal subscription
management and per-occurrence recurring edits. P4 first slice adds habits;
focus, countdowns, statistics and remaining calendar polish are next.

## Run

```bash
cd mobile
flutter pub get          # add --offline when pub.dev is unreachable
flutter test
flutter run              # requires an Android device/emulator + SDK
```

Android toolchain used locally: JDK 17 at `~/development/jdk17`, SDK 36 at
`~/development/android-sdk`.

```bash
export JAVA_HOME="$HOME/development/jdk17/Contents/Home"
export ANDROID_HOME="$HOME/development/android-sdk"
flutter build apk --debug
# -> build/app/outputs/flutter-apk/app-debug.apk (~160 MB)
flutter build apk --release
# -> build/app/outputs/flutter-apk/app-release.apk (~55 MB, debug signing for now)
```

Use the **arm64** Flutter SDK on Apple Silicon (the x64 zip runs under Rosetta
and breaks `xcrun`). After switching SDKs or installing the NDK, stop stale
Gradle daemons first:

```bash
(cd android && ./gradlew --stop)
```

This network cannot reach `services.gradle.org` (redirects to GitHub) or Maven
Central directly, so:

- `android/gradle/wrapper/gradle-wrapper.properties` uses the Tencent Gradle mirror.
- `android/settings.gradle.kts` / `android/build.gradle.kts` list Aliyun Google
  and Central mirrors before the official repositories.
- The local Flutter SDK's included Gradle build
  (`packages/flutter_tools/gradle/settings.gradle.kts` and
  `resolve_dependencies.gradle.kts`) was patched the same way; a clean SDK may
  need the same mirror lines or a Gradle init script.
- NDK 28.2.13676358 is installed because Flutter's Gradle plugin provisions it
  for the synthetic native build, even in a pure-Dart app. The NDK was fetched
  from the Tencent Android SDK mirror because sdkmanager's Google download kept
  truncating the archive.

Both are China-first workarounds; remove them once the official endpoints are
reachable. The app itself has no China-specific dependency.

### Emulator

An API 36 AOSP arm64 AVD named `p0` was used for the P0 smoke test:

```bash
$ANDROID_HOME/emulator/emulator -avd p0 -no-window -no-audio \
  -no-boot-anim -gpu swiftshader_indirect -no-snapshot
adb install -r build/app/outputs/flutter-apk/app-debug.apk
adb shell am start -n com.caldavfree.caldav_free/.MainActivity
```

`adb emu kill` stops it. The backend ran on the host at `:5296`; the app
connected to `http://10.0.2.2:5296`. For repeated automation, credentials can be
seeded through `run-as com.caldavfree.caldav_free` into
`files/credentials.json` (debug builds only).

The AVD/system image were installed manually from the Tencent AndroidSDK mirror
because `sdkmanager` could not fetch Google manifests reliably in this network;
`avdmanager create avd` also returned `null`, so `config.ini` was written by
hand. A normal Android Studio/SDK install can replace this setup.

### Huawei P20 over Wi-Fi ADB

The P20 runs Android 9/10, so it has no Android 11 `adb pair` flow. Enable USB
debugging, connect the USB cable once, accept the RSA prompt, then run:

```bash
./scripts/p20-wifi-adb.sh
```

The script switches adbd to TCP port 5555, reads `wlan0`, connects to the phone
and prints the install/run commands. After that the USB cable can be removed;
TCP mode resets on reboot, so rerun the script with USB after a reboot.

On the phone, use the Mac's LAN address (not `10.0.2.2`):

```text
http://192.168.124.8:5296
```

Both devices must be on the same Wi-Fi; guest networks with client isolation
will block ADB and the backend. Huawei may need "Install via USB" enabled and
"Monitor ADB installation" disabled.

Android emulator → host machine: use `http://10.0.2.2:5232`.
Physical device: use the LAN address, e.g. `http://192.168.1.10:5232`.
Public deployments must use HTTPS.

If no USB data cable is available, sideload the release APK over the LAN:

```bash
cd mobile/build/app/outputs/flutter-apk
python3 -m http.server 8000
# phone browser: http://<mac-lan-ip>:8000/app-release.apk
```

On Android 9/10, allow installing from the browser and disable Huawei
"纯净模式" if it blocks the APK. The release APK is signed with the Android
debug certificate for now, so it can be sideloaded but not published.

## Reminders and Android permissions

Reminders are scheduled with `flutter_local_notifications`. The app declares:

- `POST_NOTIFICATIONS` (requested on Android 13+ at runtime);
- `SCHEDULE_EXACT_ALARM` (requested when adding a reminder on Android 12+; if
  denied, scheduling falls back to inexact alarms);
- `RECEIVE_BOOT_COMPLETED` plus the plugin's boot/update receiver so pending
  notifications survive a reboot.

`android/app/build.gradle.kts` enables core-library desugaring for the plugin.
The notification small icon is `res/drawable/ic_notification.xml`. Reminder
offsets are synced as "minutes before due"; the scheduler rebuilds the pending
set only when reminder-relevant task fields change, so 15 s polling does not
cancel and recreate alarms continuously.

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

## P0/P1 environment deviations

This machine initially could not reach `pub.dev`; several P0 decisions were made
to keep the app runnable. `pub.dev` is reachable again, and P1 added
`flutter_local_notifications` + `timezone`, but the foundational migrations are
still open:

| Planned | Shipped | Migration |
| --- | --- | --- |
| drift + SQLite | `LocalStore` over an atomic JSON file | replace `lib/data/db/local_store.dart`; engine API unchanged |
| Riverpod | `provider` + `ChangeNotifier` | move `AppState`/`SyncController` to providers |
| flutter_secure_storage | app-private `credentials.json` (plaintext) | first item of the security pass |
| go_router | session-based `home` switch | add routes when the page count grows |

`android/app/src/main/kotlin/.../MainActivity.kt` exposes the app `filesDir` on
a `caldav_free/paths` MethodChannel, replacing `path_provider` (whose native
build hook required Xcode and blocked `flutter test`).

## Security notes

- P0 stores the account password in plaintext inside the app-private support
  directory. Use a dedicated account and HTTPS; Keystore/Keychain migration is
  still required before a public release.
- `android:usesCleartextTraffic="true"` is enabled for local development. Turn
  it off (or restrict it with a network security config) for production.
- Logout clears the local task database, outbox, and credentials.
