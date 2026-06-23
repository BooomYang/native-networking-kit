# 验证矩阵

## 必需入口

| 区域 | 命令 | Phase 1 预期结果 |
| --- | --- | --- |
| Environment | `./scripts/doctor.sh` | 打印发现到的 toolchain versions 和缺失的 optional tools |
| iOS tests L1/L2 | `./scripts/verify-ios-tests.sh` | 运行 Swift Package tests，覆盖 client contract 和 engine adapter unit tests |
| iOS build L4 | `./scripts/verify-ios.sh` | 运行 iOS tests，并构建通过 local Swift Package 集成 library 的 Xcode host example app |
| iOS PR preflight | `./scripts/verify-ios-pr.sh` | 覆盖 L1、L2、L3 和 L4；其中 L3 是 Swift host loopback check，不覆盖 platform runtime readiness check 或 L5 |
| Android library/example | `./scripts/verify-android.sh` | 当 Android SDK 可用时，运行 Gradle tests、lint、example assemble 和 local Maven publishing；Android Studio/模拟器直接验收需单独记录 |
| Android runtime readiness | `./scripts/verify-android-emulator.sh` | Opt-in；先运行 Android library/example baseline，再用 ADB 安装启动 example，采集 foreground、UI dump 和 bounded logcat；不计入 L5 |
| Harmony skeleton | `./scripts/verify-harmony.sh` | 如果 Hvigor 可用则运行；否则以 pending 状态退出并给出清晰信息 |
| All local | `./scripts/verify-local.sh` | 按顺序运行 doctor、iOS、Android 和 Harmony checks |

## 三端测试层级

| 层级 | iOS | Android | Harmony |
| --- | --- | --- | --- |
| L1 Client contract tests | `swift test` 已有 | Gradle tests 目标 | Hvigor/ArkTS tests 待 toolchain |
| L2 Engine adapter unit tests | `URLProtocol` stub 已有 | OkHttp adapter stub 待补 | ArkTS adapter stub 待补 |
| L3 Host loopback integration | `./scripts/verify-ios-network-harness.sh` 已有 | 待补对应 host loopback check | 待 DevEco/Hvigor 验证后补 |
| L4 Package/example integration build | `./scripts/verify-ios.sh` | `./scripts/verify-android.sh` | `./scripts/verify-harmony.sh` pending |
| L5 Platform runtime validation | Simulator/device controlled runtime behavior pending | emulator/device controlled runtime behavior pending | device/runtime pending |
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
- Swift host loopback check 属于 L3，只访问 `127.0.0.1`，不等于 L5 iOS Simulator/device runtime validation。
- 非测试层级就绪检查：iOS XcodeBuildMCP candidate 已完成首轮本机 platform runtime readiness check，可 build/install/launch example app 并采集 UI snapshot、screenshot 和 runtime log；该检查不计入 L5。
- 非测试层级就绪检查：`./scripts/verify-android-emulator.sh` 可 install/launch Android example app 并采集 foreground、UI dump 和 bounded logcat；该检查不计入 L5。
- Examples 只有在用户操作触发时才可能执行 real network requests。
- Verification scripts 会把工具写入重定向到 `.tmp/`，包括 SwiftPM caches、Gradle home、Android user state 和 Maven local output。
- `./scripts/verify-local.sh` 不等于三端 IDE/device runtime 通过。
- Android 的 Gradle verification 和 Android Studio/模拟器手动运行是两个验收层级；未实际执行后者时不要写成 IDE 通过。
- `./scripts/verify-android-emulator.sh` 是 opt-in platform runtime readiness check，只验证 example 初始 UI 启动和证据采集；不点击 `GET`，不代表 Android Studio、真机、L5 platform runtime validation 或公网请求验证通过。
- 在 DevEco/Hvigor 验证准确生成的 project metadata 之前，Harmony files 会刻意保持最小化。

## 手动验收

- 在 Android Studio 中打开 Android project，并确认 Gradle sync。
- 如需要 Android example 体验，创建或选择 Run Configuration，并在模拟器或真机上运行 `:example`。
- 在 Xcode 中打开 `platforms/ios/Package.swift`，确认 library tests 可见。
- 在 Xcode 中打开 `platforms/ios/Examples/NativeNetKitExample/NativeNetKitExample.xcodeproj`，确认 `NativeNetKitExample` scheme 可运行。
- 在 DevEco Studio 中打开 Harmony project，并确认 HAR 和 example modules 可被识别。
