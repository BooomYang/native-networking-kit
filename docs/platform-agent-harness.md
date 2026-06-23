# 平台 Agent Harness

本文记录三端平台技能和工具如何进入 NativeNetKit harness。它不是安装教程，也不是验证矩阵；验证是否通过仍以 `docs/verification-matrix.md` 和实际执行命令为准。

## 原则

- `scripts/` 中的 shell scripts 继续作为 canonical verification commands。
- Agent 技能用于提升实现、审查、诊断和 runtime evidence 采集，不直接替代已稳定的 scripts。
- 本文的“已采纳”和“候选”只表示本仓库的触发规则或评估意向，不表示对应 skill、plugin、MCP server 或 CLI 已安装到本仓库。
- 后续如果需要让这些规则脱离当前用户环境稳定生效，应在专门 PR 中补项目级安装、引用方式或降级 fallback checklist。
- 候选能力必须通过专门 PR 实测后，才能升级为正式 opt-in harness。
- 未真实执行前，不把 Simulator、emulator、device、DevEco、Hvigor、weak-network、performance 或 reliability 写成已通过。

## 已采纳规则

### iOS / Swift

| 场景 | 使用 | 边界 |
| --- | --- | --- |
| public API shape、initializer、method naming、argument labels、documentation comments、call-site fluency | `swift-api-design-guidelines-skill` | 用于 `NativeRequest`、`NativeResponse`、`NativeNetworkError`、`NativeHttpEngine`、`NativeNetClient` 等 public surface；纯内部实现重排不强行触发。 |
| module boundary、engine adapter ownership、dependency injection、package target、`request lifecycle` ownership 或较大结构调整 | `swift-architecture-skill` | 做 fit check 和边界审查；不要把网络 SDK 强行套入 MVVM/TCA 等 App 架构 playbook。 |
| async/await、cancellation、`Sendable`、actor 隔离、AsyncSequence、callback-to-async adapter、并发测试调度 | `swift-concurrency-pro` | 用于实现和审查 Swift 并发正确性；不替代 `swift test` 或 `xcodebuild test`。 |
| 新增或修改 Swift Testing tests、async/network tests、mock engine tests、XCTest 到 Swift Testing 迁移 | `swift-testing-pro` | 用于写和审查测试代码；不用于执行测试命令，UI tests 仍使用 XCTest / Xcode runtime 工具。 |

### Android / Kotlin

| 场景 | 使用 | 边界 |
| --- | --- | --- |
| module/API/engine boundary、OkHttp adapter ownership、dependency injection、`request lifecycle` ownership、public API semantics、error mapping 或测试边界变化 | `android-architecture` | 做 Android library 结构 fit check；不默认引入 Hilt、Room、ViewModel 或业务 App 分层。 |
| coroutine execution、cancellation、timeout、dispatcher、callback-to-suspend adapter、Flow、shared mutable state 或并发测试调度 | `android-coroutines` | 用于实现和审查 coroutine 正确性；不替代 Gradle test execution。 |
| 新增或修改 unit tests、后续 `androidTest`、fake/mock boundary、dispatcher/coroutine test rule、error mapping、cancellation、timeout 或 request lifecycle tests | `android-testing` | 用于写和审查测试代码；不用于执行测试命令。 |
| Gradle Kotlin DSL、settings、module build files、wrapper、plugin/dependency 配置、publication、consumer rules、lint/test task、Android SDK 设置或 `./scripts/verify-android.sh` 的 Gradle invocation | `android-gradle-logic` | 用于减少 Gradle 和 Android library publishing 错误；不代表默认引入 `build-logic`、version catalog 或复杂多模块治理。 |

### Harmony / ArkTS

Harmony/ArkTS 的 Promise、TaskPool、worker、RCP callback 等语义先使用 DevEco / HarmonyOS 知识工具确认；待稳定 skill 后再固化。

### 不可用 fallback

如果已采纳 skill 在当前线程或仓库中不可用，应明确报告不可用状态，并按本节场景做人工 checklist 审查；不要假装已经执行了对应 skill。

## 候选能力检查

### Skill / tool 接入状态

状态：已完成首轮盘点。已采纳规则对应的 iOS / Swift 与 Android / Kotlin skills 当前均安装在用户级 `~/.codex/skills`；本仓库不创建项目级 skills 目录。

目的：

- 确认已采纳和候选 skill、plugin、MCP server 或 CLI 是否需要项目级安装、引用说明或 fallback checklist。
- 避免 guidance 只在当前用户环境生效，换线程或换机器后失效。

已确认用户级 skills：

- iOS / Swift：`swift-api-design-guidelines-skill`、`swift-architecture-skill`、`swift-concurrency-pro`、`swift-testing-pro`。
- Android / Kotlin：`android-architecture`、`android-coroutines`、`android-testing`、`android-gradle-logic`。

当前决策：

- 已采纳 skills 先使用用户级安装；它们是跨项目 agent 能力，不作为 NativeNetKit repo 资产提交。
- 换机器、换用户环境或当前线程不可见时，按“不可用 fallback”做人工 checklist 审查。
- 候选能力仍需专门 PR 实测后，才能升级为正式 opt-in harness。

### iOS build-ios-apps capability check

状态：candidate，已完成首轮本机实测；仍不作为 canonical verification command。

角色边界：

- `build-ios-apps` 表示本仓库候选采用的 iOS app 构建、运行和调试 agent capability / skill。
- XcodeBuildMCP 是当前实际执行该 capability 的 tool backend。
- 谈验证覆盖时，二者不作为两套测试路径分别计数；统一映射到 `docs/testing-strategy.md` 的测试层级。

目的：

- 验证 `build-ios-apps` / XcodeBuildMCP 能否同等完成现有 `swift test`、`xcodebuild build` 的 agent-driven 执行路径。
- 验证它能否补充当前缺失的 Simulator runtime evidence，例如 app launch、UI snapshot、screenshot 和 runtime log。

边界：

- 不替代 `./scripts/verify-ios-tests.sh`、`./scripts/verify-ios.sh` 或 `./scripts/verify-ios-pr.sh`。
- 实测通过前，不写入 `docs/verification-matrix.md` 作为正式验证入口。
- 即使 Simulator evidence 通过，也不等于 iOS device validation。

本轮实测记录（2026-06-23）：

- 对照基线：`./scripts/verify-ios-pr.sh` 通过，覆盖 L1、L2、L3 和 L4；其中 L3 是 Swift host loopback check，不覆盖 platform runtime readiness check 或 L5。
- XcodeBuildMCP session defaults 使用 `NativeNetKitExample.xcodeproj`、`NativeNetKitExample` scheme、`iPhone 17` simulator、`com.aifirst.nativenetkit.example` bundle id 和 `.tmp/xcodebuildmcp-ios-example` DerivedData；未持久化 `.xcodebuildmcp/config.yaml`。
- `build_run_sim` 通过，完成 build、install 和 launch，返回 app path、build log、runtime log 与 OS log。
- `wait_for_ui` / `snapshot_ui` 能读取首屏 `NativeNetKit`、`https://example.com`、`GET` 和 `Ready`；未点击 `GET`，未触发 public network request。
- `screenshot` 通过，生成本机临时截图。
- runtime log 由 XcodeBuildMCP 写入 `~/Library/Developer/XcodeBuildMCP/workspaces/.../logs/com.aifirst.nativenetkit.example_*.log`；本轮只证明 platform runtime readiness check 可用，不计入 L5 platform runtime validation，也不能替代 scripts 的 canonical pass/fail 语义。

L5 升级条件：

- 在 iOS Simulator/device 中启动 `NativeNetKitExample`。
- 通过 `NativeNetClient` 发起 controlled network request，endpoint 使用本机或受控 mock server，不使用 public network endpoint。
- 用 UI、可观察状态或 runtime log 证明 response/error 行为。
- 保留 runtime log 作为失败诊断材料；weak network、performance、leak 和 reliability 仍属于 L6/L7。

后续 L5 controlled network 优先复用 `NativeNetKitExample`：通过 URL 输入框填入本机 mock server endpoint，点击 `GET`，再等待结果文本和 runtime log 证明请求行为。Phase 1 不新增第二个 iOS app 或专门 platform runtime harness；只有当 L5 场景明显增多时再拆分。

后续升级检查项：

- 发现 Xcode project、scheme 和 simulator。
- 配置 XcodeBuildMCP session defaults。
- 对照现有 scripts 跑 iOS library tests 或 host app build。
- 启动 `NativeNetKitExample`，采集 UI snapshot、screenshot 和 runtime log。
- 记录失败诊断是否比 shell scripts 更有价值。

### Android emulator capability check

状态：candidate，留待后续专门 PR 实测。

目的：

- 验证 `android-emulator-skill` 的 Gradle + ADB 路径能否稳定完成 install、start、foreground check、`uiautomator dump` 和 log capture。
- 补充 Android emulator runtime smoke evidence，但不替代 `./scripts/verify-android.sh`。

边界：

- 当前 `android-coroutines` 已作为并发规则采纳；`android-emulator-skill` 仍是待验证工具链。
- 优先使用本机 Android SDK 下的 `adb`，不要依赖不稳定的 IDE Run Configuration。
- emulator smoke 通过不等于 Android Studio 手动验收或真机 validation。

建议检查项：

- 使用 `./scripts/verify-android.sh` 保持 Gradle tests、lint、example assemble 和 local Maven publishing 基线。
- 使用 ADB 安装并启动 `:example`。
- 用 `dumpsys window` 确认前台 app。
- 用 `uiautomator dump` 采集可读 UI 信息。
- 用 bounded logcat 采集目标 package 日志，避免无限挂起。

### Harmony DevEco capability check

状态：candidate / pending。本机当前 `deveco` 和 DevEco Studio 可用，`devecocli` 与 `hvigorw` 当前不在 PATH。

目的：

- 验证 `devecocli build` 是否能成为 Harmony 的确定性构建入口。
- 保留 `hvigorw` 作为当前 `./scripts/verify-harmony.sh` 已表达的 fallback。
- 使用 DevEco Code 作为 HarmonyOS / ArkTS 知识与工具桥接，而不是自治 coding agent。

边界：

- DevEco Code 的回答不能替代 `devecocli build`、`hvigorw` 或 DevEco Studio 的真实构建结果。
- 不把 API key、模型配置或私有服务假设写入仓库。
- 在 DevEco/Hvigor 真实验证前，Harmony 继续保持 pending。

建议检查项：

- 安装或暴露 `devecocli` 后运行 `devecocli build`。
- 如 `hvigorw` 可用，继续运行 HAR/HAP build fallback。
- 用 DevEco Code 查询 ArkTS / RCP / module metadata 语义时，记录其为辅助诊断，不作为通过证据。

## 暂缓纳入

以下能力当前不作为默认 harness：

| 能力 | 暂缓原因 |
| --- | --- |
| `swiftdata-pro` | NativeNetKit Phase 1 没有 SwiftData 数据层。 |
| `ios-app-intents` | 当前不是 iOS App system surface 项目。 |
| `swiftui-liquid-glass`、深度 SwiftUI skill | 当前 iOS example 只是 host shell，不是复杂 SwiftUI 产品面。 |
| iOS memgraph / ETTrace | 当前没有泄漏、性能或稳定性专项目标。 |
| Android `android-viewmodel`、`android-data-layer` | 当前 Android 层是薄 networking library，不是业务 App 架构项目；后续真实 feature 需要时再触发。 |
| `compose-ui`、`compose-performance-audit` | 当前 example 不是 Compose 产品 UI，暂不需要 Compose 专项 harness。 |
| `gradle-build-performance` | 只有出现构建性能问题或 CI 基线需求后再引入。 |
| DevEco Code 自治 coding agent | Harmony 侧只把 DevEco Code 作为知识和工具桥接，不让它长期发散改代码。 |
