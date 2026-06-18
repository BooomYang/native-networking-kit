# 验证矩阵

## 必需入口

| 区域 | 命令 | 预期 |
| --- | --- | --- |
| Environment | `./scripts/doctor.sh` | 打印 toolchain versions、optional tools 和 pending tools |
| iOS tests L1+L2 | `./scripts/verify-ios-tests.sh` | 运行 Swift Package tests，覆盖 client contract 和 engine adapter unit tests |
| iOS build L4 | `./scripts/verify-ios.sh` | 运行 iOS tests，并构建 Xcode host example app |
| iOS PR preflight L1-L4 | `./scripts/verify-ios-pr.sh` | 运行 iOS tests、Xcode host app build、loopback network harness |
| Android L1/L4 | `./scripts/verify-android.sh` | Android SDK 可用时运行 Gradle tests、lint、example assemble、local Maven publishing |
| Harmony L4 | `./scripts/verify-harmony.sh` | Hvigor 可用则验证 HAR/HAP；否则输出 pending |
| All local | `./scripts/verify-local.sh` | 运行 doctor、iOS build、Android、Harmony checks |

## 三端测试层级

| 层级 | iOS | Android | Harmony |
| --- | --- | --- | --- |
| L1 Client contract tests | `swift test` 已有 | Gradle tests 目标 | Hvigor/ArkTS tests 待 toolchain |
| L2 Engine adapter unit tests | `URLProtocol` stub 已有 | OkHttp adapter stub 待补 | ArkTS adapter stub 待补 |
| L3 Loopback integration harness | `./scripts/verify-ios-network-harness.sh` | 待补 `127.0.0.1` harness | 待 DevEco/Hvigor 验证后补 |
| L4 Package/example integration build | `./scripts/verify-ios.sh` | `./scripts/verify-android.sh` | `./scripts/verify-harmony.sh` pending |
| L5 Runtime E2E | Manual/optional | Manual/optional | Manual/pending |
| L6 Weak network | 后续扩展 | 后续扩展 | 后续扩展 |
| L7 Perf/leak/reliability | 后续扩展 | 后续扩展 | 后续扩展 |

## 当前本地工具链

| 工具 | 状态 |
| --- | --- |
| Swift | 可用：Apple Swift 6.3.2 |
| Xcode | 可用：Xcode 26.5 |
| Java | 可用：OpenJDK 17 |
| Node | 可用：Node 24.2.0 |
| XcodeBuildMCP | Optional；不是 required toolchain |
| Gradle | 不要求全局安装；使用 `platforms/android/gradlew` |
| Harmony Hvigor | Pending；当前 `hvigorw` 不在 PATH 上 |

## 规则

- Unit tests 不访问 public network。
- L3 loopback harness 只能访问 `127.0.0.1`。
- `./scripts/verify-local.sh` 不等于三端 IDE/device runtime 通过。
- Simulator/emulator/device、弱网、perf/leak/debug 未实际执行时，只能写 manual、optional 或 pending。
- 通用 review 指引见 `docs/review-guidelines.md`；测试质量规则和 PR 独立审阅见 `docs/testing-strategy.md`。
