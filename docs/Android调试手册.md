# Android 调试手册

本文记录本项目在 macOS 上构建、安装、启动、调试 Flutter Android 客户端，以及连接模拟器/真机和验证后端的完整方法。

适用范围：

- 本机 macOS（Apple Silicon）
- Flutter Android 客户端（`mobile/`）
- Go 后端（`cmd/caldav-free`）
- Android 模拟器 `p0` 或同一局域网内的 Android 真机
- 当前包名：`com.caldavfree.caldav_free`
- 当前入口 Activity：`com.caldavfree.caldav_free.MainActivity`

> 本文命令均在项目根目录 `/Users/chenghaiwen/Documents/code/caldav-free` 或其 `mobile/` 子目录执行。路径按当前机器记录，换机器时替换为实际路径。

---

## 1. 环境变量

建议每个新终端先执行：

```bash
export JAVA_HOME="$HOME/development/jdk17/Contents/Home"
export ANDROID_HOME="$HOME/development/android-sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export FLUTTER="$HOME/development/flutter/bin/flutter"
export PATH="$JAVA_HOME/bin:$HOME/development/flutter/bin:$ANDROID_HOME/platform-tools:$PATH"
```

检查：

```bash
java -version
flutter --version
adb version
adb devices -l
```

当前环境预期：

- JDK 17
- Flutter stable（arm64）
- Android SDK / Build-Tools / Platform-Tools 36
- adb 可用
- 模拟器 `emulator-5554` 或真机在 `adb devices` 中显示为 `device`

---

## 2. 最短调试流程

### 2.1 启动后端

```bash
cd /Users/chenghaiwen/Documents/code/caldav-free

go build -o /tmp/caldav-free-emu ./cmd/caldav-free

# 如果已经启动过，先停掉旧进程
pkill -f '^/tmp/caldav-free-emu ' || true

nohup /tmp/caldav-free-emu \
  -data /tmp/caldav-emu-data \
  -addr :5296 \
  -admin-pass p0emupass \
  > /tmp/caldav-emu.log 2>&1 &

# 等 2 秒后检查
curl -fsS http://127.0.0.1:5296/healthz
```

模拟器内登录地址：

```text
http://10.0.2.2:5296
```

测试账号：

```text
用户名：admin
密码：p0emupass
```

> 这是本地测试账号，不要用于公网部署。

### 2.2 构建、安装、启动

```bash
cd /Users/chenghaiwen/Documents/code/caldav-free/mobile

flutter analyze --no-pub
flutter test --no-pub

flutter build apk --debug --no-pub

adb -s emulator-5554 install -r \
  build/app/outputs/flutter-apk/app-debug.apk

adb -s emulator-5554 shell am force-stop \
  com.caldavfree.caldav_free

adb -s emulator-5554 shell am start -n \
  com.caldavfree.caldav_free/.MainActivity
```

如果依赖已经解析好，统一使用 `--no-pub`，避免 `pub.dev` 握手不稳定导致构建失败。

---

## 3. 后端服务

### 3.1 常用命令

```bash
# 查看日志
tail -f /tmp/caldav-emu.log

# 直接运行（开发调试可选）
go run ./cmd/caldav-free \
  -data /tmp/caldav-emu-data \
  -addr :5296 \
  -admin-pass p0emupass

# 停止
pkill -f '^/tmp/caldav-free-emu '
```

### 3.2 健康检查与 API

```bash
curl -fsS http://127.0.0.1:5296/healthz

# Basic Auth，检查同步接口
curl -u admin:p0emupass \
  http://127.0.0.1:5296/api/sync/focus

# 检查倒数
curl -u admin:p0emupass \
  http://127.0.0.1:5296/api/sync/countdowns

# 检查农历
curl -u admin:p0emupass \
  'http://127.0.0.1:5296/api/sync/calendar/almanac?from=2026-10-01&to=2026-10-10'
```

### 3.3 数据目录

```text
/tmp/caldav-emu-data
```

删除数据目录会清空后端测试数据；需要干净环境时：

```bash
pkill -f '^/tmp/caldav-free-emu ' || true
rm -rf /tmp/caldav-emu-data
# 重新启动后端
```

---

## 4. 模拟器

### 4.1 启动 headless 模拟器

AVD：`p0`（API 36，arm64）。

```bash
$ANDROID_HOME/emulator/emulator \
  -avd p0 \
  -no-window \
  -no-audio \
  -no-boot-anim \
  -gpu swiftshader_indirect \
  -no-snapshot
```

等待启动：

```bash
adb wait-for-device
adb shell getprop sys.boot_completed
# 返回 1 表示已启动
```

### 4.2 查看设备

```bash
adb devices -l
```

预期：

```text
emulator-5554 device product:sdk_phone64_arm64 ...
```

### 4.3 投屏到 Mac 窗口

headless 模拟器没有窗口，使用 scrcpy 投屏：

```bash
brew install scrcpy

scrcpy -s emulator-5554 \
  --window-title "caldav-free emulator" \
  --stay-awake \
  --max-size 1080
```

把窗口切到前台：

```bash
osascript -e 'tell application "System Events" to set frontmost of first process whose name is "scrcpy" to true'
```

用户可以直接在 scrcpy 窗口里点击、输入、登录。

---

## 5. 构建与安装

### 5.1 Debug APK

```bash
cd mobile
flutter build apk --debug --no-pub
```

产物：

```text
mobile/build/app/outputs/flutter-apk/app-debug.apk
```

### 5.2 Release APK

```bash
cd mobile
flutter build apk --release --no-pub
```

产物：

```text
mobile/build/app/outputs/flutter-apk/app-release.apk
```

当前 release 使用 debug 签名，只能侧载测试，不能上架。

### 5.3 安装与启动

```bash
cd mobile

adb -s emulator-5554 install -r \
  build/app/outputs/flutter-apk/app-debug.apk

adb -s emulator-5554 shell am force-stop \
  com.caldavfree.caldav_free

adb -s emulator-5554 shell am start -n \
  com.caldavfree.caldav_free/.MainActivity
```

安装 release：

```bash
adb -s emulator-5554 install -r \
  build/app/outputs/flutter-apk/app-release.apk
```

如果签名不一致：

```bash
adb -s emulator-5554 uninstall com.caldavfree.caldav_free
```

> `uninstall` 会清空 App 本地数据和登录态。

### 5.4 检查版本

```bash
adb -s emulator-5554 shell dumpsys package \
  com.caldavfree.caldav_free | grep versionName
```

### 5.5 热重载

```bash
cd mobile
flutter devices
flutter run -d emulator-5554 --no-pub
```

或已有进程时：

```bash
flutter attach -d emulator-5554
```

注：headless 模拟器同样支持 `flutter run`，画面通过 scrcpy 查看。

---

## 6. 测试与质量门

```bash
cd mobile
flutter analyze --no-pub
flutter test --no-pub
```

后端：

```bash
cd /Users/chenghaiwen/Documents/code/caldav-free
go test ./...
```

真实后端 E2E：

```bash
./scripts/p0-client-e2e.sh
```

脚本会：

- 在临时目录构建 Go 后端
- 启动临时端口（默认 5297）
- 运行 `test/integration/real_server_test.dart`
- 结束后清理临时数据

只跑真实服务端测试（已有后端）：

```bash
cd mobile
CALDAV_SYNC_BASE=http://127.0.0.1:5296 \
CALDAV_SYNC_USER=admin \
CALDAV_SYNC_PASS=p0emupass \
flutter test --no-pub test/integration/real_server_test.dart
```

---

## 7. 设备交互与 UI 自动化

### 7.1 截图

```bash
adb -s emulator-5554 exec-out screencap -p > /tmp/screen.png
```

### 7.2 获取控件坐标

```bash
adb -s emulator-5554 shell uiautomator dump /sdcard/window.xml
adb -s emulator-5554 pull /sdcard/window.xml /tmp/window.xml
```

查看文本和 `bounds`：

```bash
python3 - <<'PY'
import re
s = open('/tmp/window.xml').read()
for attr in ('text', 'content-desc'):
    for m in re.finditer(attr + r'="([^"]*)"[^>]*bounds="([^"]*)"', s):
        if m.group(1):
            print(attr, repr(m.group(1)), m.group(2))
PY
```

**重要**：截图实际分辨率通常是 `1080x2400`，聊天工具显示时会缩小。`uiautomator` 返回的是**物理像素坐标**，点击时以它为准，不要按缩放后的肉眼坐标点击。

### 7.3 点击、滑动、长按

```bash
# 点击
adb -s emulator-5554 shell input tap 540 1200

# 滑动
adb -s emulator-5554 shell input swipe 900 1200 300 1200 400

# 长按（起点和终点相同，持续时间 1000ms）
adb -s emulator-5554 shell input swipe 400 600 400 600 1000
```

### 7.4 文本输入

```bash
# ASCII
adb -s emulator-5554 shell input text 'Server'

# 空格可写成 %s
adb -s emulator-5554 shell input text 'Server%stask'
```

限制：当前 adb 输入法对中文不稳定；自动化验证优先用英文/数字关键词。中文输入建议在 scrcpy 窗口手动输入。

### 7.5 删除/清空输入

```bash
# 光标移到末尾
adb -s emulator-5554 shell input keyevent 123

# 删除 20 次
for i in $(seq 1 20); do
  adb -s emulator-5554 shell input keyevent 67
done
```

常用 keycode：

| keycode | 含义 |
|---|---|
| `4` | 返回 |
| `66` | 回车 |
| `67` | 删除 |
| `123` | 移到行尾 |

### 7.6 返回与键盘

- 如果软键盘打开，第一次 `keyevent 4` 通常先收键盘。
- 如果底部 Sheet 还开着，再按一次返回。
- headless 模拟器可能使用硬件键盘输入，软键盘不一定弹出；以截图和 `uiautomator` 为准。

---

## 8. 常见调试场景

### 8.1 深色模式

```bash
adb -s emulator-5554 shell cmd uimode night yes
adb -s emulator-5554 shell cmd uimode night no
# 恢复跟随系统
adb -s emulator-5554 shell cmd uimode night auto
```

### 8.2 字体缩放

```bash
adb -s emulator-5554 shell settings put system font_scale 1.3
# 验证后恢复
adb -s emulator-5554 shell settings put system font_scale 1.0
```

### 8.3 清空 App 本地数据

用于重新验证登录页、空状态和首次同步：

```bash
adb -s emulator-5554 shell pm clear com.caldavfree.caldav_free
```

> 会清空本地任务、outbox、主题色和登录态。服务端数据不受影响。

### 8.4 通知权限

Android 13+ 首次启动会弹通知权限。自动化可显式授予：

```bash
adb -s emulator-5554 shell pm grant \
  com.caldavfree.caldav_free \
  android.permission.POST_NOTIFICATIONS
```

检查通知/闹钟：

```bash
adb -s emulator-5554 shell dumpsys alarm | grep -i caldav
adb -s emulator-5554 shell dumpsys notification --noredact | grep -i caldav
```

### 8.5 网络地址

| 场景 | 后端地址 |
|---|---|
| 模拟器访问宿主机 | `http://10.0.2.2:5296` |
| 真机访问 Mac | `http://<Mac 的局域网 IP>:5296` |
| Mac 本机 curl | `http://127.0.0.1:5296` |

查 Mac 局域网 IP：

```bash
ipconfig getifaddr en0 || ipconfig getifaddr en1
```

### 8.6 第三方对照 App 语言

如果只是测试第三方 App 的中文界面，可以按应用设置语言，不改系统语言：

```bash
adb -s emulator-5554 shell cmd locale set-app-locales \
  cn.ticktick.task --user 0 --locales zh-CN
adb -s emulator-5554 shell cmd locale get-app-locales \
  cn.ticktick.task --user 0
```

重新启动该 App 后生效。

---

## 9. 真机 / Wi-Fi ADB

### 9.1 华为 P20（Android 9/10）

P20 不支持 Android 11 的无线调试配对，必须**先 USB 连接一次**：

1. 设置 → 关于手机 → 连续点版本号 7 次
2. 开发者选项 → 打开 USB 调试
3. 华为额外打开“仅充电模式下允许 ADB 调试”
4. USB 连接手机，解锁并允许 RSA 指纹
5. 执行：

```bash
./scripts/p20-wifi-adb.sh
```

脚本会：

- 找到 USB 设备
- 读取手机 Wi-Fi IP
- 执行 `adb tcpip 5555`
- 执行 `adb connect <手机IP>:5555`

连接后可以拔掉 USB。

```bash
adb devices -l
adb -s <手机IP>:5555 install -r \
  mobile/build/app/outputs/flutter-apk/app-debug.apk
```

真机不能使用 `10.0.2.2`，要用 Mac 的局域网 IP。后端需监听所有网卡：

```bash
/tmp/caldav-free-emu \
  -data /tmp/caldav-phone-data \
  -addr :5296 \
  -admin-pass p0emupass
```

如果暂时没有 USB 数据线，可以走 LAN APK 侧载（见下一节）。

### 9.2 无线 ADB 排障

- `unauthorized`：解锁手机，确认 RSA 弹窗；仍不行则撤销 USB 调试授权后重新连接。
- 安装被拦截：开发者选项里允许“通过 USB 安装”，关闭“监控 ADB 安装”。
- 重启手机后 TCP adbd 会失效，需要重新 USB 执行脚本。
- 手机和 Mac 必须在同一 Wi-Fi，且路由器未开启客户端隔离。

---

## 10. APK 局域网分发

把 release APK 放到局域网 HTTP 服务：

```bash
cd mobile/build/app/outputs/flutter-apk
python3 -m http.server 8000 --bind 0.0.0.0
```

查 Mac IP：

```bash
ipconfig getifaddr en0 || ipconfig getifaddr en1
```

手机浏览器打开：

```text
http://<Mac-IP>:8000/app-release.apk
```

当前环境曾使用：

```text
http://192.168.124.8:8000/app-release.apk
```

检查服务是否已经在跑：

```bash
lsof -nP -iTCP:8000 -sTCP:LISTEN
```

---

## 11. 日志与崩溃定位

### 11.1 Flutter / App 日志

```bash
adb -s emulator-5554 logcat -v time \
  | grep -E 'flutter|caldav_free|AndroidRuntime'
```

只看崩溃缓冲：

```bash
adb -s emulator-5554 logcat -b crash -v time
```

### 11.2 当前窗口与 Activity

```bash
adb -s emulator-5554 shell dumpsys window \
  | grep -E 'mCurrentFocus|mFocusedApp'

adb -s emulator-5554 shell dumpsys activity activities \
  | grep -E 'mResumedActivity|topResumedActivity'
```

### 11.3 后端日志

```bash
tail -n 100 /tmp/caldav-emu.log
tail -f /tmp/caldav-emu.log
```

### 11.4 App 版本与安装状态

```bash
adb -s emulator-5554 shell dumpsys package \
  com.caldavfree.caldav_free \
  | grep -E 'versionName|versionCode|firstInstallTime'
```

---

## 12. 常见问题

### `adb: no devices/emulators found`

```bash
adb devices -l
```

- 模拟器没启动：按第 4 节启动。
- 真机：检查 USB 调试、RSA 弹窗、Wi-Fi 是否同网段。
- 多设备：所有命令都加 `-s emulator-5554` 或 `-s <手机IP>:5555`。

### `INSTALL_FAILED_UPDATE_INCOMPATIBLE`

签名不同。开发阶段可卸载重装：

```bash
adb -s emulator-5554 uninstall com.caldavfree.caldav_free
adb -s emulator-5554 install -r \
  mobile/build/app/outputs/flutter-apk/app-debug.apk
```

### `flutter pub get` 卡住/握手失败

依赖已经解析时直接：

```bash
flutter build apk --debug --no-pub
flutter test --no-pub
```

### 登录页连不上后端

- 模拟器用 `10.0.2.2:5296`，不要用 `127.0.0.1`。
- 后端是否监听 `:5296`，不是只监听 `127.0.0.1`。
- Mac 防火墙是否拦截。
- 先在本机 `curl http://127.0.0.1:5296/healthz` 验证。

### 点击坐标总是点错

- 以 `uiautomator dump` 的 `bounds` 为准。
- 截图显示尺寸可能被聊天窗口缩小。
- 先点击元素中心，不要点边界。
- 点不到时先确认当前 Activity/Sheet 是否已经切换。

### 通知/提醒不出现

- Android 13+ 检查通知权限。
- 检查精确闹钟权限与 `dumpsys alarm`。
- 任务需要有截止时间 + 提醒偏移，且提醒时间在未来。
- App 是否被系统电池优化限制。

---

## 13. 安全与限制

- `p0emupass`、Basic Auth 和明文凭据配置只用于本地开发。
- 公网部署必须使用 HTTPS。
- 当前 release APK 使用 debug 签名，仅适合侧载测试。
- 模拟器数据目录 `/tmp/caldav-emu-data` 是临时数据，不要当生产库。
- 修改登录账号/密码后，App 本地旧会话需要重新登录或清除数据。
- 中国区网络下访问 Gradle / pub.dev 可能不稳定，构建失败先检查镜像和网络。

---

## 14. 命令速查

```bash
# 环境
export JAVA_HOME="$HOME/development/jdk17/Contents/Home"
export ANDROID_HOME="$HOME/development/android-sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export PATH="$JAVA_HOME/bin:$HOME/development/flutter/bin:$ANDROID_HOME/platform-tools:$PATH"

# 后端
go build -o /tmp/caldav-free-emu ./cmd/caldav-free
pkill -f '^/tmp/caldav-free-emu ' || true
nohup /tmp/caldav-free-emu -data /tmp/caldav-emu-data -addr :5296 -admin-pass p0emupass > /tmp/caldav-emu.log 2>&1 &

# 构建
cd mobile
flutter analyze --no-pub
flutter test --no-pub
flutter build apk --debug --no-pub
flutter build apk --release --no-pub

# 安装/启动
adb -s emulator-5554 install -r build/app/outputs/flutter-apk/app-debug.apk
adb -s emulator-5554 shell am force-stop com.caldavfree.caldav_free
adb -s emulator-5554 shell am start -n com.caldavfree.caldav_free/.MainActivity

# 截图/UI
adb -s emulator-5554 exec-out screencap -p > /tmp/screen.png
adb -s emulator-5554 shell uiautomator dump /sdcard/window.xml

# 点击/输入
adb -s emulator-5554 shell input tap 540 1200
adb -s emulator-5554 shell input swipe 900 1200 300 1200 400
adb -s emulator-5554 shell input text 'Server'
adb -s emulator-5554 shell input keyevent 4

# 深色/字体
adb -s emulator-5554 shell cmd uimode night yes
adb -s emulator-5554 shell settings put system font_scale 1.3
adb -s emulator-5554 shell settings put system font_scale 1.0

# 重置 App 数据
adb -s emulator-5554 shell pm clear com.caldavfree.caldav_free

# 真机 Wi-Fi ADB
./scripts/p20-wifi-adb.sh

# APK 分发
cd mobile/build/app/outputs/flutter-apk
python3 -m http.server 8000 --bind 0.0.0.0
```

---

## 15. 参考文件

- `scripts/p0-client-e2e.sh`：真实后端 E2E
- `scripts/p20-wifi-adb.sh`：华为 P20 Wi-Fi ADB
- `scripts/start-quick-tunnel.sh`：CalDAV 临时公网隧道
- `docs/客户端P0.md`：客户端实现、调试记录和已知限制
- `docs/客户端UI设计.md`：Android UI 设计规范
