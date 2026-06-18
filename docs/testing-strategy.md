# 测试策略

本文定义三端通用测试分层、测试用例质量标准和 PR 独立审阅规则。目标是支撑长期 AI coding，而不是追覆盖率。

通用 PR review 优先级、project hot zones 和作者 packet 见 [`docs/review-guidelines.md`](review-guidelines.md)。`TEST_QUALITY_REVIEWED` 是测试、harness、verification 相关 PR 的附加硬门，不替代 general PR review。

## 测试分层

| 层级 | 名称 | 目的 | 当前状态 |
| --- | --- | --- | --- |
| L1 | Client contract tests | client + injected engine，验证 request 构造、response/error 透传 | iOS 已有；Android/Harmony 目标一致 |
| L2 | Engine adapter unit tests | native engine adapter + platform stub，验证 status/header/body/error mapping | iOS 已有；Android/Harmony 待补 |
| L3 | Loopback integration harness | 真实平台网络栈 + `127.0.0.1` mock server，验证 socket/HTTP 路径 | iOS 已有；Android/Harmony 待补 |
| L4 | Package/example integration build | library package + example app build，防止集成编译坏 | iOS/Android 有入口；Harmony pending |
| L5 | Runtime E2E | Simulator/emulator/device UI 路径 | 按阶段人工判断 |
| L6 | Weak network | device/simulator weak network | 后续扩展 |
| L7 | Perf/leak/reliability | latency、memory、leak、stability | 后续扩展 |

默认 agent 编码完成必须跑 L1+L2。平台 PR 前必须跑该平台 L4；iOS PR 前默认跑 L1+L2+L3+L4。

## 测试用例准则

- 只测影响核心业务逻辑主线的行为，不写 setter/getter、字段搬运、永远绿测试。
- 测试验证 public behavior，不绑 private method、call count 或实现顺序。
- 使用最低有效层级：能在 L1/L2 验，不放 L3；L3 只放真实平台网络栈才有意义的场景。
- Mock 只放在系统边界或设计 seam。当前 `NativeHttpEngine` injection 是 client contract seam；HTTP mock server 是网络边界。
- 每条测试必须有中文验证意图注释，命令、路径、代码标识符、必要技术术语保持 English/ASCII。

注释模板：

```swift
// 验证意图：当 <场景> 时，<public interface> 应 <行为>；防止 <风险>。
```

## 分层选择例子

- HTTP `503` 仍应作为 `NativeResponse`：放 L2。原因：验证 adapter mapping，不需要真实 socket。
- connection closed、unused port、delay stimulation：放 L3。原因：需要真实 `URLSession` + socket/HTTP 行为。
- example app 是否能链接 package product：放 L4。原因：验证集成构建，不是 library unit behavior。
- UI 点击后显示状态：放 L5。原因：验证 runtime interaction，不进默认脚本。

## PR 作者说明

PR 改动测试、harness、verification/build scripts、workflow、build/package manifests、README、`AGENTS.md` 或测试/review 策略文档时，除 `docs/review-guidelines.md` 的通用 author PR packet 外，还必须包含：

- 改动涉及哪些测试层级。
- 每条新增测试的验证意图。
- 为什么没有放到更低层级。
- 跑过哪些命令，哪些未跑。
- residual risk。

## 独立测试质量审阅

相关 PR 必须有非作者 GitHub review，且 review body 包含：

```text
TEST_QUALITY_REVIEWED

- 测试意图清晰：是/否
- 层级选择合理：是/否
- 无低价值覆盖率测试：是/否
- 必要 L1/L2/L3/L4 验证证据充分：是/否
- residual risk 可接受：是/否
```

`.github/workflows/test-quality-review.yml` 会检查 marker。这是测试/验证相关 PR 的附加硬门：general PR review 仍按 [`docs/review-guidelines.md`](review-guidelines.md) 执行。要真正阻止 merge，repo owner 还必须在 GitHub branch protection 中把 `test-quality-review` 设为 required status check。
