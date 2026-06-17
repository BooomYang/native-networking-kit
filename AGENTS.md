# AGENTS.md

## 仓库预期

- 本仓库是 iOS、Android、HarmonyOS 三端原生网络库的 Phase 1 monorepo。
- 三个平台都保持原生实现。共享行为由对齐后的概念和文档定义，不通过共享 runtime code 实现。
- 重要目录：
  - `platforms/android/`：Android Gradle library、example app 和 tests。
  - `platforms/ios/`：Swift Package library、tests 和 Xcode host example app。
  - `platforms/harmony/`：Harmony/ArkTS HAR skeleton、example shell 和 pending validation notes。
  - `docs/`：持久化项目上下文、verification matrix、AI environment notes 和 decisions。
  - `scripts/`：供人类和 Codex 使用的稳定命令入口。

## 命令

- Doctor：`./scripts/doctor.sh`
- iOS test：`./scripts/verify-ios.sh`
- Android verification：`./scripts/verify-android.sh`
- Harmony verification：`./scripts/verify-harmony.sh`
- Local verification：`./scripts/verify-local.sh`

如果某条命令因为平台 toolchain 缺失而无法运行，要报告具体缺失工具和 residual risk。不要把 pending toolchain check 标记为 passed。

## Git workflow language

- Git commit message、PR title、PR description、GitHub comment 和交付总结默认使用中文。
- 分支名、命令、文件路径、代码标识符、外部产品名和必要技术术语保持英文或 ASCII。
- Commit message 使用简短动宾结构，例如：`补充 loop 需求入口决策流程`。
- PR title 可以使用 `[codex] 中文标题`；PR body 用中文说明改了什么、为什么改、如何验证和剩余风险。
- Codex review 正文默认使用中文，保留 P0/P1/P2、文件路径和符号名等英文标识。

## 工程约定

- Architecture：Phase 1 只实现 framework base 和 thin engine adapter。没有新的 requirement loop 时，不要实现 QUIC、HTTPDNS、IP racing、multi-network recovery、connection governance、full observability 或 KMP。
- Dependencies：避免新增 production dependency，除非它是当前层的 native-platform standard practice。Android 可以使用 OkHttp，因为这是设计中选定的 Android framework base。
- Testing：unit tests 必须使用 injected mock engine，不能依赖 public network access。
- Naming：三端 public concepts 保持对齐：`NativeNetClient`、`NativeHttpEngine`、`NativeRequest`、`NativeResponse` 和 `NativeNetworkError`。
- Error handling：尽可能保留 native/raw error details，但在 Phase 1 API 中只暴露小型 unified error category。

## 平台级 harness 规则

- 平台打开方式、IDE 验收和常见问题优先写在各平台 README：`platforms/ios/README.md`、`platforms/android/README.md`、`platforms/harmony/README.md`。
- 目前不为每个平台创建独立 `AGENTS.md`。只有当某个平台出现大量专属 agent 规则、重复误操作或独立维护边界时，再拆分子目录 `AGENTS.md`。
- iOS library + example 的标准形态是 `platforms/ios/Package.swift` 加 `Examples/NativeNetKitExample/NativeNetKitExample.xcodeproj`。不要把 SwiftPM executable example 当作 iOS host app，也不要让 app target 直接拖入 library 源码替代 package product dependency。
- 修改 iOS `.xcodeproj`、scheme、Package dependency 或 host app 结构前先做只读检查；完成前运行 `./scripts/verify-ios.sh`，或说明无法运行的具体原因。
- Android 以 `platforms/android` 为 Gradle root。没有实际执行 Android Studio sync、Run Configuration 或模拟器/真机运行时，不要声称 Android IDE/设备级验收通过。
- Harmony 仍是 DevEco/Hvigor pending skeleton。在 `hvigorw` 或 DevEco validation 真实运行前，不要声称 Harmony HAR/HAP build verification 已通过。

## AI 编码流程

- 开始前先阅读相关平台文件和 `docs/verification-matrix.md`。
- 对 ambiguous、cross-platform 或 high-risk 工作，先做只读探索并制定计划。
- 改动范围保持在一个 requirement loop 内。
- 完成前运行最相关的 verification；如果无法运行，说明原因和仍未验证的内容。
- 每个任务收尾时说明 verification results、residual risk，以及是否需要更新 durable asset。

## 需求入口

| 场景 | 默认入口 |
| --- | --- |
| 清晰、低风险改动 | 直接运行 Codex，并做 focused verification |
| 模糊、跨平台或高风险改动 | 先计划；编辑前进行只读探索 |
| 清晰的多步骤改动 | 使用带明确 done criteria 和 stop condition 的 goal loop |
| 需要 handoff、audit、reuse 或 long-context protection 的需求 | 在 `docs/` 中创建或更新 task brief |
| 重复工作流 | 再手动运行一次，然后考虑 template、skill、eval 或 automation |
| 外部触发工作 | 自动化前先定义 manual triage output 和 human acceptance |
| 缺少项目指引或验证入口 | 做最小 environment repair，然后回到原需求 |

## Review 指引

- 优先检查 public API semantics 的 behavior regression。
- 优先检查 changed behavior 缺失的 tests。
- 优先检查 dependency、publishing、SDK 和 toolchain risks。
- 对 platform-specific changes，即使不修改其他平台，也要确认其他平台的 aligned concepts 仍然可理解。

## 禁止事项

- 没有明确批准时，不要运行 destructive commands。
- 处理窄范围任务时，不要重写无关 platform code。
- 不要把 internal-company dependencies 放进 library。
- 不要编写 real-network unit tests。
- 在 `hvigorw` 或 DevEco validation 真实运行前，不要声称 Harmony build verification 已通过。
