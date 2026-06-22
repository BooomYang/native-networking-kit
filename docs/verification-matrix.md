# 验证矩阵

## 必需入口

| 区域 | 命令 | Phase 1 预期结果 |
| --- | --- | --- |
| Environment | `./scripts/doctor.sh` | 打印发现到的 toolchain versions 和缺失的 optional tools |
| iOS tests L1/L2 | `./scripts/verify-ios-tests.sh` | 运行 Swift Package tests，覆盖 client contract 和 engine adapter unit tests |
| iOS build L4 | `./scripts/verify-ios.sh` | 运行 iOS tests，并构建通过 local Swift Package 集成 library 的 Xcode host example app |
| iOS PR preflight | `./scripts/verify-ios-pr.sh` | 运行 iOS tests、Xcode host app build、Swift host loopback check |
| Android library/example | `./scripts/verify-android.sh` | 当 Android SDK 可用时，运行 Gradle tests、lint、example assemble 和 local Maven publishing；Android Studio/模拟器直接验收需单独记录 |
| Harmony skeleton | `./scripts/verify-harmony.sh` | 如果 Hvigor 可用则运行；否则以 pending 状态退出并给出清晰信息 |
| All local | `./scripts/verify-local.sh` | 按顺序运行 doctor、iOS、Android 和 Harmony checks |

## 三端测试层级

| 层级 | iOS | Android | Harmony |
| --- | --- | --- | --- |
| L1 Client contract tests | `swift test` 已有 | Gradle tests 目标 | Hvigor/ArkTS tests 待 toolchain |
| L2 Engine adapter unit tests | `URLProtocol` stub 已有 | OkHttp adapter stub 待补 | ArkTS adapter stub 待补 |
| Swift host loopback check | `./scripts/verify-ios-network-harness.sh` 已有；不计作 iOS runtime L3 | 待补对应 loopback check | 待 DevEco/Hvigor 验证后补 |
| L3 Platform loopback integration harness | iOS Simulator/device pending | Android emulator/device pending | Harmony device/runtime pending |
| L4 Package/example integration build | `./scripts/verify-ios.sh` | `./scripts/verify-android.sh` | `./scripts/verify-harmony.sh` pending |
| L5 Runtime E2E | Manual/optional | Manual/optional | Manual/pending |
| L6 Weak network | 后续扩展 | 后续扩展 | 后续扩展 |
| L7 Perf/leak/reliability | 后续扩展 | 后续扩展 | 后续扩展 |

## 当前本地工具链

| 工具 | 状态 |
| --- | --- |
| Swift | 可用：当前 Codex shell 中为 Apple Swift 6.3.2 |
| Xcode | 可用：当前 Codex shell 中为 Xcode 26.5 |
| Java | 可用：OpenJDK 17 |
| Node | 可用：Node 24.2.0 |
| Gradle | 不要求全局安装；使用 `platforms/android/gradlew` |
| Harmony Hvigor | Pending；当前 `hvigorw` 不在 PATH 上 |

## 平台说明

- iOS tests 使用 mock engine，不执行 network I/O。
- Android unit tests 使用 mock engine，不执行 network I/O。
- Swift host loopback check 只访问 `127.0.0.1`，不等于 iOS Simulator/device runtime L3。
- Examples 只有在用户操作触发时才可能执行 real network requests。
- Verification scripts 会把工具写入重定向到 `.tmp/`，包括 SwiftPM caches、Gradle home、Android user state 和 Maven local output。
- `./scripts/verify-local.sh` 不等于三端 IDE/device runtime 通过。
- Android 的 Gradle verification 和 Android Studio/模拟器手动运行是两个验收层级；未实际执行后者时不要写成 IDE 通过。
- 在 DevEco/Hvigor 验证准确生成的 project metadata 之前，Harmony files 会刻意保持最小化。

## 手动验收

- 在 Android Studio 中打开 Android project，并确认 Gradle sync。
- 如需要 Android example 体验，创建或选择 Run Configuration，并在模拟器或真机上运行 `:example`。
- 在 Xcode 中打开 `platforms/ios/Package.swift`，确认 library tests 可见。
- 在 Xcode 中打开 `platforms/ios/Examples/NativeNetKitExample/NativeNetKitExample.xcodeproj`，确认 `NativeNetKitExample` scheme 可运行。
- 在 DevEco Studio 中打开 Harmony project，并确认 HAR 和 example modules 可被识别。
