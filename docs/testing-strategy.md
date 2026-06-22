# 测试策略

本文定义 NativeNetKit Phase 1 的测试分层和测试质量规则。目标是让后续 agent 知道“该在哪一层验证”，不是追覆盖率。

## 测试分层

| 层级 | 名称 | 目的 | 当前状态 |
| --- | --- | --- | --- |
| L1 | Client contract tests | client + injected engine，验证 request 构造、response/error 透传 | iOS 已有；Android/Harmony 目标一致 |
| L2 | Engine adapter unit tests | native engine adapter + platform stub，验证 status/header/body/error mapping | iOS 已有 `URLProtocol` stub；Android/Harmony 待补 |
| L3 | Platform loopback integration harness | 真实平台 runtime 网络栈 + `127.0.0.1` mock server | 三端 pending |
| L4 | Package/example integration build | library package + example app build | iOS/Android 有入口；Harmony pending |
| L5 | Runtime E2E | Simulator/emulator/device UI 路径 | 按阶段人工判断 |
| L6 | Weak network | weak network 条件下的行为 | 后续扩展 |
| L7 | Perf/leak/reliability | latency、memory、leak、stability | 后续扩展 |

Swift host loopback integration harness 是独立的 host integration check：它用真实 `URLSessionNativeHttpEngine` 访问本机 `127.0.0.1` mock server，但运行在 Swift host/macOS process 中，不等于 iOS Simulator/device L3。

## 默认选择

- 日常 iOS library 变更先跑 L1/L2：`./scripts/verify-ios-tests.sh`。
- iOS build/package/example 相关变更跑 L4：`./scripts/verify-ios.sh`。
- iOS PR preflight 跑：`./scripts/verify-ios-pr.sh`。
- 能在 L1/L2 验证的行为，不升级到 L3 或 host loopback。
- HTTP `503` 这类 adapter mapping 属于 L2；closed connection、unused local port、delay elapsed 这类真实网络边界才属于 host loopback。

## 测试质量规则

- 只测 public behavior，不绑 private method、call count 或实现顺序。
- Mock 只放在系统边界或设计 seam；当前 `NativeHttpEngine` injection 是 client contract seam。
- Unit tests 不访问 public network。
- Loopback harness 只访问 `127.0.0.1`。
- 每条单测必须有中文验证意图注释，命令、路径、API 名和代码标识符保持 English/ASCII。

注释模板：

```swift
// 验证意图：当 <场景> 时，<public interface> 应 <行为>；防止 <风险>。
```

## PR 说明

测试、harness 或 verification script 变更进入 PR 时，说明：

- 涉及哪些测试层级。
- 新增测试的验证意图。
- 跑过哪些命令，哪些未跑。
- residual risk。
