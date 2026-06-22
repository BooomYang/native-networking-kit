# AGENTS.md

## 仓库预期

- 本仓库是 iOS、Android、HarmonyOS 三端原生网络库的 Phase 1 monorepo。
- 三端保持原生实现；共享行为通过文档、命名、测试分层和 review 规则对齐，不引入 shared runtime code。
- 重要目录：`platforms/ios/`、`platforms/android/`、`platforms/harmony/`、`docs/`、`scripts/`。

## 必读入口

- 项目概览：`README.md`
- 验证矩阵：`docs/verification-matrix.md`
- 测试策略：`docs/testing-strategy.md`
- Review 指引：`docs/review-guidelines.md`
- iOS network harness：`docs/ios-network-harness.md`
- 平台说明：`platforms/ios/README.md`、`platforms/android/README.md`、`platforms/harmony/README.md`

## 核心命令

- Doctor：`./scripts/doctor.sh`
- iOS tests：`./scripts/verify-ios-tests.sh`
- iOS network harness：`./scripts/verify-ios-network-harness.sh`
- iOS PR preflight：`./scripts/verify-ios-pr.sh`
- iOS build：`./scripts/verify-ios.sh`
- Android verification：`./scripts/verify-android.sh`
- Harmony verification：`./scripts/verify-harmony.sh`
- Local verification：`./scripts/verify-local.sh`

工具链缺失必须报告具体缺失项和 residual risk。pending check 不能写成 passed。

## 工程约定

- Phase 1 只实现 framework base 和 thin engine adapter。没有新 requirement loop 时，不实现 QUIC、HTTPDNS、IP racing、multi-network recovery、connection governance、full observability 或 KMP。
- 避免新增 production dependency，除非是当前 native platform standard practice。
- 三端 public concepts 保持对齐：`NativeNetClient`、`NativeHttpEngine`、`NativeRequest`、`NativeResponse`、`NativeNetworkError`。
- Unit tests 必须使用 injected/mockable boundary，不依赖 public network。
- 不写无意义覆盖率测试；测试分层、注释模板和 PR review packet 见 `docs/testing-strategy.md`。

## AI 编码流程

- 开始前读取相关平台文件、`docs/verification-matrix.md` 和 `docs/testing-strategy.md`。
- ambiguous、cross-platform、high-risk 或 harness 变更先做只读探索并制定计划。
- 改动范围保持在一个 requirement loop 内。
- 完成前运行对应层级 verification；无法运行时说明原因和 residual risk。
- 测试、harness、verification 或 `AGENTS.md` 变更进入 PR 时，必须触发维护者测试质量确认；GitHub check 规则见 `docs/testing-strategy.md`。

## Review 入口

- Code review 先读 `docs/review-guidelines.md`；测试、harness、verification 或测试策略相关 review 还要读 `docs/testing-strategy.md`。
- Review 优先级：public behavior/API semantics、Phase 1 scope、测试与验证证据、dependency/toolchain/package 风险、三端 concept 对齐、文档状态真实性。
- 测试质量审阅是附加硬门，不替代 general PR review。

## Git workflow language

- Git commit message、PR title、PR description、GitHub comment 和交付总结默认中文。
- 分支名、命令、文件路径、代码标识符、外部产品名和必要技术术语保持 English/ASCII。
- Commit message 用简短动宾结构，例如：`补充三端测试分层规则`。

## 禁止事项

- 未明确批准时不运行 destructive commands。
- 窄范围任务不重写无关 platform code。
- 不把 internal-company dependencies 放进 library。
- 不把 public network 请求写进 unit tests。
- 未实际执行 Simulator/emulator/device/Hvigor/DevEco 验证时，不写成 passed。
