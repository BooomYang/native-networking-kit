# AGENTS.md

## 仓库预期

- 目标：本仓库是 iOS、Android、HarmonyOS 三端原生网络库的 Phase 1 monorepo。
- 非目标：没有明确的后续 requirement loop 时，不要实现 QUIC、HTTPDNS、IP racing、multi-network recovery、connection governance、full observability、KMP 或 shared runtime code。

## 仓库结构

```text
native-networking-kit/
├── platforms/android/   # Android Gradle library、example app 和 tests
├── platforms/ios/       # Swift Package library、tests、Xcode host app 和 host harnesses
├── platforms/harmony/   # DevEco Studio 26 / Harmony ArkTS HAR skeleton 和 example shell
├── docs/                # Phase 1 context、verification matrix、testing strategy 和 decisions
├── scripts/             # 供人类和 Codex 使用的稳定命令入口
└── AGENTS.md            # 持久化 Codex guidance
```

- 平台打开方式、IDE 验收和常见问题写在各平台 README。
- 长测试策略、验证矩阵和设计意图放在 `docs/`，不要塞进本文件。

## 命令

- Doctor：`./scripts/doctor.sh`
- iOS tests L1/L2：`./scripts/verify-ios-tests.sh`
- iOS build L4：`./scripts/verify-ios.sh`
- iOS PR preflight：`./scripts/verify-ios-pr.sh`
- Swift host loopback check：`./scripts/verify-ios-network-harness.sh`
- Android library verification：`./scripts/verify-android-library.sh`
- Android example verification：`./scripts/verify-android-example.sh`
- Android aggregate verification：`./scripts/verify-android.sh`
- Harmony verification：`./scripts/verify-harmony.sh`
- Local verification：`./scripts/verify-local.sh`

## 工程约定

- Phase 1 的共享行为通过 naming、docs、tests 和 verification 对齐，不通过 shared runtime code 对齐。
- 三端 public concepts 保持对齐：`NativeNetClient`、`NativeHttpEngine`、`NativeRequest`、`NativeResponse` 和 `NativeNetworkError`。
- Unit tests 使用 injected 或 mockable boundary，不依赖 public network access。
- 三端新增或修改 tests / harness scenarios 时，必须写精简中文“验证意图”注释，说明要保护的 public behavior 和回归风险，不描述实现步骤。
- 避免新增 production dependency，除非它是当前层的 native-platform standard practice。
- 平台 skill 采纳范围、项目特定触发语义和不可用 fallback 见 `docs/platform-agent-harness.md`；触及 public API semantics、engine boundary、`request lifecycle`、测试或平台构建配置时，按该文档选择对应 skill。

## 风险热区

- Public API semantics 和 aligned concepts 的 error mapping。
- Platform engine boundary，尤其是 iOS `URLSessionNativeHttpEngine`、Android OkHttp adapter work 和 Harmony adapter skeleton。
- Tests、harness、verification scripts、build manifests、package metadata、README、`AGENTS.md` 和 truth-bearing docs。
- 任何暗示 pending Android Studio、device、Simulator、DevEco、Hvigor、weak-network、performance 或 reliability validation 已通过的代码或文档。

## 验证

- 从受影响平台或层级的最小相关脚本开始验证。
- iOS PR work 默认运行 `./scripts/verify-ios-pr.sh`。
- Android library/package changes 优先运行 `./scripts/verify-android-library.sh`；example 宿主集成变化优先运行 `./scripts/verify-android-example.sh`；Android aggregate 用 `./scripts/verify-android.sh`。
- `./scripts/verify-local.sh` 是稳定 local aggregate，不运行 Swift host loopback check。
- 如果 toolchain 缺失，要报告具体缺失工具和 residual risk。不要把 pending validation 写成 passed。
- 测试分层和验证意图注释规则见 `docs/testing-strategy.md`；当前平台状态见 `docs/verification-matrix.md`。

## Review 指引

- 先 review behavior regression，再看 style。
- 检查 changed behavior 是否有位于最低有效层级的有价值测试。
- Review 涉及 `NativeNetClient`、`NativeRequest`、`NativeResponse`、`NativeNetworkError`、`NativeHttpEngine`、engine adapter、`request lifecycle`、tests、harness 或 verification scripts 的变更时，按 `docs/testing-strategy.md` 的 L1-L7 和 `docs/verification-matrix.md` 的测试健康矩阵检查测试缺口。
- 命中上述热区时，review 结论应明确说明命中层级、已有验证、测试缺口或无需补测原因。
- Review 新增或修改 tests / harness scenarios 时，检查是否有精简验证意图注释，且注释描述 behavior intent 而不是实现步骤。
- Hot-zone changes 需要明确 validation evidence，或清楚说明 residual risk。
- 对 platform-specific changes，即使不修改其他平台，也要确认未修改平台的描述仍然真实且 conceptually aligned。

## 安全与 Secrets

- 不要提交 local caches、credentials、generated packages 或 machine state；脚本输出优先保留在 `.tmp/`。
- 不要把 internal-company dependencies 或 private infrastructure assumptions 放进 library。
- Public-network behavior 属于 examples 或 opt-in harnesses，不属于 unit tests。

## 禁止事项

- 未明确批准时，不要运行 destructive commands。
- 窄范围任务不要重写无关 platform code。
- 不要削弱 verification scripts 或 tests 来让命令通过。
- 本轮 clean harness foundation 不新增 review router workflows、GitHub state parsers、attention labels 或 merge automation。
- 未真实执行前，不要声称 Harmony HAR/HAP、Android IDE/device 或 iOS Simulator/device runtime validation 已通过。

## Guidance 维护

- 只有 durable、project-wide 且可能影响未来 agent work 的规则，才加入 `AGENTS.md`。
- 长流程和细策略链接到 canonical docs，不复制进 `AGENTS.md`。
- 只有当子目录出现稳定且不同的本地规则时，才新增 nested `AGENTS.md`。

## Agent skills

### Issue tracker

Issues 和 PRDs 使用 GitHub Issues。见 `docs/agents/issue-tracker.md`。

### Triage labels

Triage label vocabulary 先采用默认五角色映射。见 `docs/agents/triage-labels.md`。

### Domain docs

本 repo 是 single-context；术语表在 `CONTEXT.md`，ADR-style decisions 在 `docs/decisions/`。见 `docs/agents/domain.md`。

## Git 与交付

- Git commit message、PR title、PR description、GitHub comment、review text 和 delivery summary 默认中文。
- Branch names、commands、file paths、code identifiers、product names 和必要 technical terms 保持 English 或 ASCII。
- Commit message 使用简短动宾结构，例如：`补充 iOS harness 分层`。
