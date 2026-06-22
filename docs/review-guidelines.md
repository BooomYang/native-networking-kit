# Review 指引

本文定义 NativeNetKit 的通用 PR review 入口。测试质量审阅是测试、harness、verification 相关 PR 的附加门，不替代这里的 general review。

## Project hot zones

触碰以下区域时，PR 作者和 reviewer 都要显式说明风险和验证证据：

- Public concepts 和 behavior：`NativeNetClient`、`NativeHttpEngine`、`NativeRequest`、`NativeResponse`、`NativeNetworkError` 的语义、错误映射和三端命名对齐。
- Platform engine boundary：iOS `URLSession` adapter、Android OkHttp adapter、Harmony/ArkTS adapter skeleton，以及所有 injected/mockable boundary。
- Test、harness 和 verification：`platforms/**/Tests/**`、`test`、`androidTest`、`ohosTest`、`Harnesses`、`scripts/verify-*.sh`、`scripts/doctor.sh`、`scripts/check-test-quality-review.sh`、`.github/workflows/**`。
- Build、package 和 publishing manifests：`Package.swift`、`.xcodeproj`、`build.gradle.kts`、`settings.gradle.kts`、`gradle.properties`、`gradle/wrapper/**`、`AndroidManifest.xml`、`hvigorfile.ts`、`build-profile.json5`、`oh-package.json5`、`module.json5`。
- Project truth docs：`README.md`、platform README、`AGENTS.md`、`docs/verification-matrix.md`、`docs/testing-strategy.md`、本文和 ADR。
- Scope boundary：任何暗示 QUIC、HTTPDNS、IP racing、multi-network recovery、connection governance、full observability 或 KMP 已实现的代码或文档。

## General PR review priorities

按风险优先，而不是按文件顺序：

1. Public API semantics 或 platform behavior 是否回退。
2. Phase 1 scope 是否仍只停留在 framework base 和 thin engine adapter。
3. 变更行为是否有足够测试，验证层级是否合理。
4. Dependency、SDK、toolchain、package、publishing 和 CI/harness 风险是否被覆盖。
5. 三端 aligned concepts 是否仍可理解，未修改的平台是否被错误暗示为已验证。
6. 文档状态是否保持真实：`pending` 不能写成 `passed`，manual/optional/device 结果不能替代实际执行。

## Author PR packet

PR 作者在 description 或交付总结中提供：

- 改了什么、为什么改，以及触碰了哪些 hot zones。
- Public behavior/API、package/build 或 verification 入口是否变化。
- 跑过的命令和结果；未跑的命令、原因和 residual risk。
- 测试/验证相关 PR 还要按 `docs/testing-strategy.md` 说明测试层级、验证意图和测试质量审阅需求。

## Reviewer independent risk assessment

Reviewer 不能只复述作者 packet；需要独立判断：

- 变更是否实际触碰 hot zones，作者是否漏报风险。
- 测试层级是否过高或过低，是否存在低价值覆盖率测试。
- 验证证据是否覆盖受影响平台；缺失工具链是否被如实标记为 pending/residual risk。
- 文档、脚本和 workflow 是否会改变未来 agent 或 CI 的行为。
- 测试质量确认通过时，必须确认 marker 来自维护者本人，且符合 `docs/testing-strategy.md` 的模板；AI agent 不能代替维护者确认。

## Hot-zone escalation

触碰 hot zones 时默认升级 review 严格度：

- Ambiguous、cross-platform、harness、CI 或 package/build 变更先做只读探索和计划。
- 测试、harness、verification scripts、测试策略或 `AGENTS.md` 变更必须触发维护者测试质量确认。
- 缺少 iOS Simulator、Android emulator/device、DevEco/Hvigor 或其他 toolchain 时，不阻塞所有工作，但必须在 PR packet 中写明未验证内容和 residual risk。
- 无法判断平台风险时，请求熟悉该平台或该 hot zone 的 reviewer；不要用其他平台通过来替代当前平台验证。
