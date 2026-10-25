# caldav-free mobile (P0)

Android-first Flutter client for the `caldav-free` sync protocol. The UI reads
only the local store; every write goes to a local outbox and the sync engine
pushes it in the background.

## What works

- Login with the CalDAV username/password against `/api/sync/pull`.
- Offline task create, rename, complete/uncomplete, edit notes, delete.
- Due date/time + all-day, priority, tags, subtasks, local search.
- Smart views: all, today (including overdue), next 7 days.
- List create/rename/delete, folders, moving lists into folders, and moving a task between lists.
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

Android toolchain used locally: JDK 17 at `~/development/jdk17`, SDK 36 at
`~/development/android-sdk`.

```bash
export JAVA_HOME="$HOME/development/jdk17/Contents/Home"
export ANDROID_HOME="$HOME/development/android-sdk"
flutter build apk --debug
# -> build/app/outputs/flutter-apk/app-debug.apk (~159 MB)
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
