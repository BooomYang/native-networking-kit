# 测试策略

本文定义三端通用测试分层、测试用例质量标准和 PR review attention routing。目标是支撑长期 AI coding，而不是追覆盖率。

通用 PR review 优先级、project hot zones 和作者 packet 见 [`docs/review-guidelines.md`](review-guidelines.md)。`review-attention-router` 是 advisory check：它不阻塞 PR，只把 Codex review 信号路由为 `attention:none`、`attention:ai-fixable` 或 `attention:human`。

## 测试分层

| 层级 | 名称 | 目的 | 当前状态 |
| --- | --- | --- | --- |
| L1 | Client contract tests | client + injected engine，验证 request 构造、response/error 透传 | iOS 已有；Android/Harmony 目标一致 |
| L2 | Engine adapter unit tests | native engine adapter + platform stub，验证 status/header/body/error mapping | iOS 已有；Android/Harmony 待补 |
| L3 | Platform loopback integration harness | 真实平台 runtime 网络栈 + `127.0.0.1` mock server，验证 socket/HTTP 路径 | 三端待补；当前 iOS 只有 Swift host loopback harness |
| L4 | Package/example integration build | library package + example app build，防止集成编译坏 | iOS/Android 有入口；Harmony pending |
| L5 | Runtime E2E | Simulator/emulator/device UI 路径 | 按阶段人工判断 |
| L6 | Weak network | device/simulator weak network | 后续扩展 |
| L7 | Perf/leak/reliability | latency、memory、leak、stability | 后续扩展 |

默认 agent 编码完成必须跑 L1+L2。平台 PR 前必须跑该平台 L4；iOS PR 前默认跑 L1+L2、Swift host loopback harness 和 L4。iOS Simulator/device L3 仍是 pending。

## 测试用例准则

- 只测影响核心业务逻辑主线的行为，不写 setter/getter、字段搬运、永远绿测试。
- 测试验证 public behavior，不绑 private method、call count 或实现顺序。
- 使用最低有效层级：能在 L1/L2 验，不放 L3；L3 只放真实平台 runtime 网络栈才有意义的场景。
- Mock 只放在系统边界或设计 seam。当前 `NativeHttpEngine` injection 是 client contract seam；HTTP mock server 是网络边界。
- 每条测试必须有中文验证意图注释，命令、路径、代码标识符、必要技术术语保持 English/ASCII。

注释模板：

```swift
// 验证意图：当 <场景> 时，<public interface> 应 <行为>；防止 <风险>。
```

## 分层选择例子

- HTTP `503` 仍应作为 `NativeResponse`：放 L2。原因：验证 adapter mapping，不需要真实 socket。
- connection closed、unused port、delay stimulation：当前放 Swift host loopback harness；真正覆盖 iOS runtime 网络栈时再升级为 iOS L3。
- example app 是否能链接 package product：放 L4。原因：验证集成构建，不是 library unit behavior。
- UI 点击后显示状态：放 L5。原因：验证 runtime interaction，不进默认脚本。

## PR 作者说明

PR 改动测试、harness、verification/build scripts、workflow、build/package manifests、README、`AGENTS.md` 或测试/review 策略文档时，除 `docs/review-guidelines.md` 的通用 author PR packet 外，还必须包含：

- 改动涉及哪些测试层级。
- 每条新增测试的验证意图。
- 为什么没有放到更低层级。
- 跑过哪些命令，哪些未跑。
- residual risk。

## Review Attention Routing

`.github/workflows/test-quality-review.yml` 会运行 advisory router。它读取 changed files 和 Codex review/comment 中的 P0/P1/P2/P3 信号，然后更新 attention labels：

| 结果 | 含义 | 默认处理 |
| --- | --- | --- |
| `attention:none` | 没有需要维护者关注的 review 信号 | 可继续常规验证/合并流程 |
| `attention:ai-fixable` | 有低风险 review 建议，通常可让 AI 自行修 | AI 先修，维护者不必立即介入 |
| `attention:human` | P0/P1 且触碰 project hot zone | 高亮给维护者，先看风险再决定 |

Router 默认返回成功，不因为缺少人工确认而 fail。`pull_request` 事件只做只读分类和 Actions step summary；`pull_request_target` 或 `issue_comment` 事件才尝试写入 PR labels/comment。它只负责把有限注意力推给真正敏感的 PR。
