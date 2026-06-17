# Phase 1 简报

## 目标

为三端原生网络库建立第一个 loop-engineering-ready monorepo。第一个有用里程碑是在每个平台上提供一个薄的、可构建的底座，并包含 native packaging、examples、tests 和清晰的 verification commands。

## 用户和使用场景

- 后续会实现 optimization layers 的 library maintainers。
- 需要 Android、iOS 和 HarmonyOS 原生接入示例的 app engineers。
- 需要稳定 context、commands 和 acceptance criteria 来处理后续 requirement loops 的 Codex 或其他 AI coding agents。

## 范围内

- Monorepo project structure。
- 持久化 project guidance 和 requirement entry rules。
- 每个平台最小化的 request、response、client、engine 和 error concepts。
- 用于 mock-based tests 的 engine injection。
- 每个平台的 native package/test/example surfaces。
- Verification scripts 和 platform readiness matrix。

## 范围外

- QUIC、HTTPDNS、address racing、Happy Eyeballs、multi-network recovery、connection governance、degradation policies、full observability、KMP bridge、performance tuning 和 release automation。
- Internal infrastructure integrations。
- 超出 Phase 1 smoke usage 的 public API stability promises。

## 当前约束

- 当前 Codex shell 中，iOS 可通过 Xcode 26.5 和 Swift 6.3.2 做本地验证。
- Java 17 可用。
- 因为没有全局 `gradle`，Android 必须使用 Gradle Wrapper。
- 因为当前 `hvigorw` 不可用，Harmony build 仍为 pending。

## 验收标准

- 新的 Codex thread 读取 `README.md`、`AGENTS.md` 和 `docs/verification-matrix.md` 后，可以恢复项目目的和命令。
- iOS package tests 和 SwiftUI example build 通过 `./scripts/verify-ios.sh`。
- Android 的 standard library、example、test、lint、debug assemble 和 local Maven publishing tasks 由 `./scripts/verify-android.sh` 覆盖。
- Harmony 具备 DevEco/Hvigor 风格 skeleton，并有明确的 pending verification notes。
