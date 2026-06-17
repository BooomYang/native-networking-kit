# NativeNetKit

NativeNetKit 是 iOS、Android、HarmonyOS 三端原生高性能网络库的 Phase 1 monorepo。

本阶段目标是跑通三端原生网络库的工程底座：三端同仓管理，但保持各自原生工程、构建发布、example 和测试入口。当前代码范围只覆盖框架底座层与最薄 engine adapter，后续优化能力通过明确 requirement loop 进入。

## 快速开始

从 repository root 运行：

```bash
./scripts/doctor.sh
./scripts/verify-local.sh
```

`./scripts/verify-local.sh` 会依次运行 doctor、iOS、Android 和 Harmony 检查。当前已知结果是：iOS 和 Android 已通过，Harmony 因本地 `hvigorw` 不可用保持 pending，但不会被写成已构建通过。

## 前置条件

| 平台 | 要求 |
| --- | --- |
| iOS | 当前 Codex shell 中可用 Xcode 26.5 和 Swift 6.3.2 |
| Android | Java 17；Android SDK 位于 `ANDROID_HOME`、`ANDROID_SDK_ROOT` 或 `~/Library/Android/sdk`；构建使用 `platforms/android/gradlew` |
| HarmonyOS | DevEco/Hvigor 或 `hvigorw`；当前本地 toolchain 仍待配置 |

验证脚本会把 tool cache、SwiftPM cache、Android user state 和 Maven local output 重定向到 `.tmp/`，使本地验证尽量保持在仓库目录内。

## 验证命令

| 命令 | 作用 | 当前状态 |
| --- | --- | --- |
| `./scripts/doctor.sh` | 打印发现到的 toolchain versions 和缺失工具 | 已可运行 |
| `./scripts/verify-ios.sh` | 运行 Swift Package tests，并构建 SwiftUI example | 已通过 |
| `./scripts/verify-android.sh` | 运行 Gradle tests、lint、example assemble 和 local Maven publishing | 已通过 |
| `./scripts/verify-harmony.sh` | 若 Hvigor 可用则运行 HAR/HAP 验证，否则输出 pending | Pending：本地缺少 `hvigorw` |
| `./scripts/verify-local.sh` | 依次运行 doctor、iOS、Android 和 Harmony 检查 | 已通过；Harmony 输出 pending |

## Phase 1 范围

- 在三端提供对齐的原生 API 命名：`NativeNetClient`、`NativeHttpEngine`、`NativeRequest`、`NativeResponse` 和 `NativeNetworkError`。
- 支持 engine injection，使 unit tests 可以使用 mock engine，examples 可以使用真实 engine。
- 采用各平台原生集成路径：
  - Android：Gradle Kotlin DSL、AAR library、local Maven publishing、Android example app。
  - iOS：Swift Package Manager library 与 test target、SwiftUI example app package。
  - HarmonyOS：DevEco/Hvigor 风格的 HAR module skeleton 与 ArkUI example shell。
- Phase 1 不实现 QUIC、HTTPDNS、IP 竞速、多网恢复、连接治理、完整可观测模型或 KMP。
- 任何暗示后续优化能力的字段或 adapter，除非后续需求明确实现，都必须保持 inert。

## 示例入口

- Android library：[`platforms/android/native-netkit`](platforms/android/native-netkit)
- Android example：[`platforms/android/example`](platforms/android/example)
- iOS Swift Package：[`platforms/ios`](platforms/ios)
- iOS example：[`platforms/ios/Examples/NativeNetKitExample`](platforms/ios/Examples/NativeNetKitExample)
- Harmony HAR skeleton：[`platforms/harmony/native-netkit`](platforms/harmony/native-netkit)
- Harmony example shell：[`platforms/harmony/example`](platforms/harmony/example)

## 项目结构

```text
native-networking-kit/
  platforms/
    android/   Android Gradle library + example app
    ios/       Swift Package library + SwiftUI example
    harmony/   Harmony/ArkTS HAR skeleton + example shell
  docs/        Phase 1 brief、verification matrix、AI environment notes 和 ADR
  scripts/     doctor 与验证入口
  AGENTS.md    Codex 项目协作指引
```

## 更多文档

- [Phase 1 简报](docs/phase-1-brief.md)
- [验证矩阵](docs/verification-matrix.md)
- [AI 环境说明](docs/ai-environment.md)
- [ADR 0001: Phase 1 使用 native monorepo](docs/decisions/0001-monorepo-phase-1.md)
- [ADR 0002: Phase 1 只保留 thin engine adapter](docs/decisions/0002-thin-engine-adapter.md)
- [Codex 项目协作指引](AGENTS.md)

## Roadmap 输入

Phase 1 roadmap 来自本仓库外部的参考设计文档：

- `../三端原生网络库重写-技术方案/00-需求与目标.md`
- `../三端原生网络库重写-技术方案/01-总体设计.md`
- `../三端原生网络库重写-技术方案/02-子设计-统一数据模型与可观测.md`

这些文档只能作为 roadmap context，不能视为已经实现的行为。

## 当前成熟度

Phase 1 bootstrap 已具备 README、AGENTS.md、docs、scripts、platform project skeleton、examples 和 unit-test entrypoints。iOS 与 Android 已通过本地验证；Harmony 仍是 DevEco/Hvigor 待验证骨架。
