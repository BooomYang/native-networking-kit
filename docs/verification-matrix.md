# 验证矩阵

## 必需入口

| 区域 | 命令 | Phase 1 预期结果 |
| --- | --- | --- |
| Environment | `./scripts/doctor.sh` | 打印发现到的 toolchain versions 和缺失的 optional tools |
| iOS tests L1/L2 | `./scripts/verify-ios-tests.sh` | 运行 Swift Package tests，覆盖 client contract 和 engine adapter unit tests |
| iOS build L4 | `./scripts/verify-ios.sh` | 运行 iOS tests，并构建通过 local Swift Package 集成 library 的 Xcode host example app |
| iOS PR preflight | `./scripts/verify-ios-pr.sh` | 覆盖 L1、L2、L3 和 L4；其中 L3 是 Swift host loopback check，不覆盖 platform runtime readiness check 或 L5 |
| Android library | `./scripts/verify-android-library.sh` | 当 Android SDK 可用时，运行 `:native-netkit:test`、`:native-netkit:lint` 和 `:native-netkit:publishToMavenLocal`，覆盖 L1/L2 并验证组件可独立构建和发布 |
| Android example | `./scripts/verify-android-example.sh` | 当 Android SDK 可用时，运行 `:example:lint` 和 `:example:assembleDebug`，验证 example 通过本地 project dependency 集成 library |
| Android aggregate | `./scripts/verify-android.sh` | 聚合运行 Android library 和 example 验证；Android Studio/模拟器直接验收需单独记录 |
| Android host loopback | `./scripts/verify-android-network-harness.sh` | 启动共享 Node mock server，并运行 `:native-netkit:networkHarnessTest`，覆盖 L3 host loopback；不计入 L5 |
| Android PR preflight | `./scripts/verify-android-pr.sh` | 覆盖 L1、L2、L3 和 L4；其中 L3 是 JVM host loopback check，不覆盖 platform runtime readiness check 或 L5 |
| Android runtime readiness | `./scripts/verify-android-emulator.sh` | Opt-in；先运行 Android library/example baseline，再用 ADB 安装启动 example，采集 foreground、UI dump 和 bounded logcat；不计入 L5 |
| Harmony skeleton | `./scripts/verify-harmony.sh` | 使用 DevEco Studio bundled `hvigorw` 运行 HAR/HAP build；当前本机已通过 |
| All local | `./scripts/verify-local.sh` | 按顺序运行 doctor、iOS、Android 和 Harmony checks |

## 三端测试层级

| 层级 | iOS | Android | Harmony |
| --- | --- | --- | --- |
| L1 Client contract tests | `swift test` 已有 | `:native-netkit:test` 已有 | Hvigor/ArkTS tests 待 toolchain |
| L2 Engine adapter unit tests | `URLProtocol` stub 已有 | `:native-netkit:test` fake `Call.Factory` 已有 | ArkTS adapter stub 待补 |
| L3 Host loopback integration | `./scripts/verify-ios-network-harness.sh` 已有 | `./scripts/verify-android-network-harness.sh` 已有 | 待 DevEco/Hvigor 验证后补 |
| L4 Package/example integration build | `./scripts/verify-ios.sh` | `./scripts/verify-android-library.sh` + `./scripts/verify-android-example.sh`，或 aggregate `./scripts/verify-android.sh` | `./scripts/verify-harmony.sh` 已通过 |
| L5 Platform runtime validation | Simulator/device controlled runtime behavior pending | emulator/device controlled runtime behavior pending | device/runtime pending |
| L6 Weak network | 后续扩展 | 后续扩展 | 后续扩展 |
| L7 Perf/leak/reliability | 后续扩展 | 后续扩展 | 后续扩展 |

## iOS 测试健康矩阵

Android/Harmony 在补齐平台专属测试健康矩阵前，review 先按“三端测试层级”检查 pending gap；未真实验证前，不要把 pending 写成 covered。

| 层级/检查 | Behavior intent / 行为意图 | Subject / 验证对象 | Network boundary / 网络边界 | Signal strength / 信号强度 | Determinism / 确定性 | Current status / 当前状态 | Gap / 缺口 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| L1 Client contract tests | 验证 `NativeNetClient` 转发 request，并透传 response/error | client contract | mock engine；不访问网络 | unit | 高；只依赖 Swift test runtime | covered：`./scripts/verify-ios-tests.sh` | 补更多 public client behavior 时按需增加 |
| L2 Engine adapter unit tests | 验证 `NativeRequest` 到 `URLRequest`、HTTP response、非 HTTP response 和 `URLSession` error mapping | engine adapter | `URLProtocol` stub；不访问 public network | adapter unit | 高；依赖 Foundation URL loading stub | covered：`./scripts/verify-ios-tests.sh` | cancellation、timeout 等 public error semantics 待后续 requirement |
| L3 Host loopback integration | 验证真实 `URLSessionNativeHttpEngine` 能访问 `127.0.0.1` mock server，并覆盖 success、delay、closed connection、unused port | host transport | host process + `127.0.0.1` loopback | host integration | 中；依赖本机 socket、Node mock server 和 Swift host process | covered：`./scripts/verify-ios-network-harness.sh` | 不覆盖 Simulator/device runtime |
| L4 Package/example integration build | 验证 Swift Package library 和 Xcode host app 可集成构建 | package/example build | none；不验证网络行为 | build integration | 中；依赖 Xcode、SwiftPM 和 package cache | covered：`./scripts/verify-ios.sh` | 不覆盖 app launch 或 runtime behavior |
| Platform runtime readiness check | 验证 Simulator app launch、UI snapshot、screenshot 和 runtime log 采集链路可用 | platform runtime tooling | none；未点击 `GET` | tooling readiness | 中低；依赖 Simulator、XcodeBuildMCP 和本机 runtime state | candidate：XcodeBuildMCP 首轮本机检查已完成 | 不计入 L5；不验证 networking behavior |
| L5 Platform runtime validation | 验证 Simulator/device 中通过 `NativeNetClient` 发起 controlled network request，并用 UI/状态/log 证明 response/error 行为 | platform runtime | Simulator/device controlled endpoint | platform runtime | 中低；依赖 Simulator/device、mock server、UI automation 和 runtime logs | pending | 最高价值下一步：复用 `NativeNetKitExample` 补 controlled network request |
| L6 Weak network | 验证弱网条件下的 public behavior | platform/runtime behavior | controlled endpoint + weak network | weak-network validation | 低；依赖网络条件控制和 runtime state | pending | L5 稳定后再补 |
| L7 Perf/leak/reliability | 验证 latency、memory、leak、stability | runtime quality | 按专项设计 | perf/leak/reliability | 低；依赖 profiling 工具和长时间运行条件 | pending | 有明确性能或稳定性目标后再补 |

## 当前本地工具链

| 工具 | 状态 |
| --- | --- |
| Swift | 可用：当前 Codex shell 中为 Apple Swift 6.3.2 |
| Xcode | 可用：当前 Codex shell 中为 Xcode 26.5 |
| Java | 可用：OpenJDK 17 |
| Node | 可用：Node 24.2.0 |
| Gradle | 不要求全局安装；使用 `platforms/android/gradlew` |
| Harmony Hvigor | 可用：PATH 上无 `hvigorw`，但 DevEco Studio bundled `hvigorw` 可被脚本发现；`DEVECO_SDK_HOME` 使用 `Contents/sdk` |

## 平台说明

- iOS tests 使用 mock engine，不执行 network I/O。
- Android L1 tests 使用 injected mock engine，不执行 network I/O；Android L2 tests 使用 fake `Call.Factory`，不访问 public network。
- Android L3 host loopback check 使用真实 `OkHttpNativeHttpEngine` 访问共享 Node mock server 的 `127.0.0.1` endpoint，不等于 emulator/device L5。
- Android library/package verification 和 example 宿主集成 verification 已拆分；改动只触及组件发布时优先跑 `./scripts/verify-android-library.sh`，改动触及 example 壳时优先跑 `./scripts/verify-android-example.sh`。
- Swift host loopback check 属于 L3，只访问共享 Node mock server 的 `127.0.0.1` endpoint，不等于 L5 iOS Simulator/device runtime validation。
- 非测试层级就绪检查：iOS XcodeBuildMCP candidate 已完成首轮本机 platform runtime readiness check，可 build/install/launch example app 并采集 UI snapshot、screenshot 和 runtime log；该检查不计入 L5。
- 非测试层级就绪检查：`./scripts/verify-android-emulator.sh` 可 install/launch Android example app 并采集 foreground、UI dump 和 bounded logcat；该检查不计入 L5。
- Examples 只有在用户操作触发时才可能执行 real network requests。
- Verification scripts 会把工具写入重定向到 `.tmp/`，包括 SwiftPM caches、Gradle home、Android user state 和 Maven local output。
- `./scripts/verify-local.sh` 不等于三端 IDE/device runtime 通过。
- Android 的 Gradle verification 和 Android Studio/模拟器手动运行是两个验收层级；未实际执行后者时不要写成 IDE 通过。
- `./scripts/verify-android-emulator.sh` 是 opt-in platform runtime readiness check，只验证 example 初始 UI 启动和证据采集；不点击 `GET`，不代表 Android Studio、真机、L5 platform runtime validation 或公网请求验证通过。
- Harmony project metadata 已对齐 DevEco Studio 26 / Hvigor `modelVersion: "26.0.0"` 最小结构；HAR/HAP CLI build 已通过，但不代表 DevEco Studio 手工验收、设备运行或 L5 platform runtime validation。

## 手动验收

- 在 Android Studio 中打开 Android project，并确认 Gradle sync。
- 如需要 Android example 体验，创建或选择 Run Configuration，并在模拟器或真机上运行 `:example`。
- 在 Xcode 中打开 `platforms/ios/Package.swift`，确认 library tests 可见。
- 在 Xcode 中打开 `platforms/ios/Examples/NativeNetKitExample/NativeNetKitExample.xcodeproj`，确认 `NativeNetKitExample` scheme 可运行。
- 在 DevEco Studio 中打开 Harmony project，并确认 HAR 和 example modules 可被识别。
