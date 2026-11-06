# macOS 打包（.app → .dmg）

## 一、结论先看

| 问题 | 答案 |
|---|---|
| 能不能出 DMG | 能。`hdiutil` 是系统自带，不需要额外工具，也不需要签名 |
| 要不要按架构分开打 | 默认不需要。通用二进制一份装两种机器 |
| 分架构能省多少 | 通用 25 MB → arm64 12 MB / x64 13 MB，约省一半 |
| 分架构怎么开 | 仓库变量 `MACOS_SPLIT_ARCH=true`，或本地脚本加 `--split` |

三种产物：

```
caldav-free-macos-universal-<tag>.dmg   25 MB   默认，Intel + Apple Silicon 都能跑
caldav-free-macos-arm64-<tag>.dmg       12 MB   --split 才有
caldav-free-macos-x64-<tag>.dmg         13 MB   --split 才有
```

## 二、为什么默认出通用版

Flutter 的 macOS Release 构建没开 `ONLY_ACTIVE_ARCH`，走 `ARCHS_STANDARD`，
所以在 arm64 的 `macos-15` runner 上产出的仍然是 `arm64 + x86_64` 通用二进制。
体积大头正是这两个通用二进制：

| 文件 | 大小 |
|---|---|
| `FlutterMacOS.framework/FlutterMacOS` | 29 MB |
| `App.framework/App`（Dart AOT） | 19 MB |
| `sqlite3.framework/sqlite3` | 3.2 MB |

一份通用包 = 用户不用认机型，不用点两次下载。分架构只在这两种情况下有意义：

- 下载体积敏感（12 MB vs 25 MB，对国内网络确实有感）
- 想按机型分别统计下载量

代价是用户得自己判断：Apple Silicon 选 arm64，Intel 选 x64，选错了打不开。

## 三、分架构是怎么做的

不是重新编译两遍，而是**对通用二进制瘦身**：

```bash
lipo -thin arm64 <binary> -output <binary>   # 逐个 Mach-O 裁掉另一片
codesign --force --sign - <framework>          # 裁完原签名失效，必须重签
codesign --force --sign - caldav-free.app
```

关键顺序是**先签内层 framework、再签外层 app**，反了会被内层覆盖掉。
漏掉重签步骤的话，包能打出来、能挂载、能拖进「应用程序」，
但一打开就崩溃——这是最容易踩的一个坑。

脚本 `mobile/scripts/package-macos.sh` 里对每个通用 Mach-O 先判断再裁：
`lipo -archs` 只有一片的直接跳过（对已经是单架构的文件执行 `-thin` 会报错），
裁完断言主二进制只剩目标架构。

实测裁剪了 4 个 Mach-O：`caldav-free`、`FlutterMacOS`、`App`、`sqlite3`。

## 四、DMG 是怎么打的

```bash
ditto app 到临时目录     # 不能用 cp -R：会展开 framework 里的符号链接，包体翻倍
ln -s /Applications 临时目录/Applications
hdiutil create -volname "Caldav Free" -srcfolder 临时目录 -format UDZO out.dmg
hdiutil verify out.dmg
```

挂载后是一个窗口：左边应用、右边「应用程序」文件夹，拖过去就装完。

没有做自定义背景图和图标位置——那需要 AppleScript 驱动 Finder，在无图形会话的
runner 上时好时坏。真要好看，本地用 `create-dmg` 做一次，或者用 `hdiutil` 建
读写镜像后 `bless` 配 `.DS_Store`，但那一步不适合放进 CI。

## 五、未签名会怎样

DMG 本身不需要签名，但里面的 app 没有 Developer ID，Gatekeeper 会拦：

```
$ spctl -a -vv caldav-free.app
caldav-free.app: rejected
```

用户第一次打开会看到「无法打开，因为 Apple 无法验证」。两条绕法：

1. 右键点应用 → 打开 → 再点「打开」
2. 或者终端执行：

```bash
xattr -dr com.apple.quarantine /Applications/caldav-free.app
```

想彻底解决要 Apple Developer Program（99 美元/年）：

```
codesign --deep --force --options runtime --sign "Developer ID Application: ..." caldav-free.app
xcrun notarytool submit out.dmg --apple-id ... --team-id ... --password ... --wait
xcrun stapler staple out.dmg
```

公证做在 DMG 上，Apple 会扫描其中的 app。这套要等有证书再加，现在加了也跑不通。

## 六、本地怎么跑

```bash
cd mobile
flutter build macos --release
./scripts/package-macos.sh \
  build/macos/Build/Products/Release/caldav-free.app \
  dist/macos v2.7.1            # 加 --split 出分架构
```

脚本会打印每个产物的 sha256 和体积。CI 里同一份脚本被
`.github/workflows/release-mobile.yml` 的 `Collect artifacts` 步骤调用，
没有第二套逻辑。

## 七、实测记录

在本机用 CI 产出的真实 `.app`（`run #5` 的 `macos-release` 产物）跑通：

| 检查项 | 结果 |
|---|---|
| 通用 DMG | 25 MB，`hdiutil verify` 通过 |
| arm64 DMG | 12 MB，挂载后主二进制 `arm64` |
| x64 DMG | 13 MB，挂载后主二进制 `x86_64` |
| 重签校验 | 三个包 `codesign --verify --strict` 均通过 |
| 实际启动 | arm64 与 x64（Rosetta）都能起，进程存活到超时被杀（exit 124） |
| Gatekeeper | `rejected`，符合预期（无 Developer ID） |
