# 测试策略

本文定义 NativeNetKit Phase 1 的测试分层和测试质量规则。目标是让后续 agent 知道“该在哪一层验证”，不是追覆盖率。

## 测试分层

| 层级 | 名称 | 目的 | 当前状态 |
| --- | --- | --- | --- |
| L1 | Client contract tests | client + injected engine，验证 request 构造、response/error 透传 | iOS/Android 已有；Harmony 目标一致 |
| L2 | Engine adapter unit tests | native engine adapter + platform stub，验证 status/header/body/error mapping | iOS 已有 `URLProtocol` stub；Android 已有 fake `Call.Factory`；Harmony 待补 |
| L3 | Host loopback integration | host process + 真实 engine adapter + `127.0.0.1` mock server | iOS Swift host loopback check 已有；Android JVM host loopback check 已有；Harmony 待补 |
| L4 | Package/example integration build | library package + example app build | iOS/Android 有入口；Harmony pending |
| L5 | Platform runtime validation | Simulator/emulator/device 上触发真实 runtime behavior；网络库场景应包含 controlled network request | 按阶段人工判断 |
| L6 | Weak network | weak network 条件下的行为 | 后续扩展 |
| L7 | Perf/leak/reliability | latency、memory、leak、stability | 后续扩展 |

Swift host loopback check 属于 L3：它用真实 `URLSessionNativeHttpEngine` 访问本机 `127.0.0.1` mock server，但运行在 Swift host/macOS process 中，不等于 L5 iOS Simulator/device runtime validation。

三端 L3 host loopback 可以共用 repo-level controlled mock server 和 scenario inputs，用来保证各平台面对同一组 `127.0.0.1` 响应、延迟和断连刺激；共用测试输入不等于共享 runtime code。

Android L3 host loopback 优先使用 local JVM test 承载：由独立 verification script 启动共享 Node mock server，并通过 Gradle 只运行对应 L3 test；它仍然是 host process + real `OkHttpNativeHttpEngine` + `127.0.0.1` loopback，不等于 emulator/device L5。

Platform runtime readiness check 用来确认 Simulator/emulator/device、example app launch、UI snapshot、screenshot 和 runtime log 采集链路可用；它是 L5 前置就绪检查，不计入 L5 behavior validation。

对 NativeNetKit，L5 platform runtime validation 的最低标准是：在 Simulator/emulator/device 中启动 example app，通过 `NativeNetClient` 发起 controlled network request，endpoint 使用本机或受控 mock server，并用 UI、可观察状态或 runtime log 证明 response/error 行为。Public network endpoint 不作为 L5 最低标准。

## 测试健康视图术语

测试健康视图用来直观看出当前测试信号覆盖了哪些行为边界、信号强弱和主要缺口；它不替代 L1-L7，也不使用代码行覆盖率百分比作为主要判断。

| 术语 | 中文说明 |
| --- | --- |
| Test health matrix / 测试健康矩阵 | 按 L1-L7 汇总测试意图、验证对象、网络边界、信号强度、确定性、当前状态和缺口的视图。 |
| Behavior intent / 行为意图 | 测试想证明的 public behavior，例如 request 转发、error mapping、loopback response 或 package build。 |
| Subject / 验证对象 | 测试主要覆盖的对象，例如 client contract、engine adapter、host transport、package build 或 platform runtime。 |
| Network boundary / 网络边界 | 请求是否触及网络以及触及到哪里，例如 none、mock engine、`URLProtocol` stub、`127.0.0.1` loopback 或 Simulator/device controlled endpoint。 |
| Signal strength / 信号强度 | 测试信号离真实使用路径的接近程度；unit、adapter unit、host integration、build integration、platform runtime 依次提供不同强度。 |
| Determinism / 确定性 | 测试结果受环境影响的程度；越依赖 toolchain、runtime、网络条件或 device state，确定性越低，诊断成本越高。 |
| Current status / 当前状态 | covered、candidate 或 pending；只表示当前仓库里对应能力是否已有稳定入口或实测证据。 |
| Gap / 缺口 | 下一步最值得补的行为或验证边界，例如 iOS L5 controlled network request。 |

## 默认选择

- 日常 iOS library 变更先跑 L1/L2：`./scripts/verify-ios-tests.sh`。
- iOS build/package/example 相关变更跑 L4：`./scripts/verify-ios.sh`。
- iOS PR preflight 跑：`./scripts/verify-ios-pr.sh`；它覆盖 L1、L2、L3 和 L4，其中 L3 是 Swift host loopback check，不覆盖 platform runtime readiness check 或 L5。
- 日常 Android library 变更先跑 L1/L2：`./scripts/verify-android-library.sh`。
- Android PR preflight 跑：`./scripts/verify-android-pr.sh`；它覆盖 L1、L2、L3 和 L4，其中 L3 是 JVM host loopback check，不覆盖 platform runtime readiness check 或 L5。
- 能在 L1/L2 验证的行为，不升级到 L3。
- HTTP `503` 这类 adapter mapping 属于 L2；closed connection、unused local port、delay elapsed 这类真实网络边界才属于 host loopback。

## 测试健康维护规则

Review 代码变更时，先判断 changed behavior 属于哪个 public behavior，再选择最低有效验证层级；如果没有补测试，需要说明为什么当前层级不需要更新。

| 变更类型 | 默认检查层级 |
| --- | --- |
| `NativeNetClient` public behavior、client method 或 request lifecycle ownership | L1 |
| `NativeRequest`、`NativeResponse`、`NativeNetworkError` public semantics | L1 + L2，涉及真实 transport boundary 时加 L3 |
| `NativeHttpEngine` contract、iOS `URLSessionNativeHttpEngine` 或 Android `OkHttpNativeHttpEngine` adapter mapping | L2，涉及真实 socket、timeout、closed connection 或 unused port 时加 L3 |
| Swift/Android host loopback harness、mock server 或真实 host transport behavior | L3 |
| Swift Package manifest、Xcode host app project、example app build integration | L4 |
| Simulator/emulator/device app flow、UI automation、runtime log 采集链路 | platform runtime readiness check；触发 controlled network request 时才是 L5 |
| verification scripts、preflight orchestration 或验证入口语义 | 检查对应 L1-L7 覆盖是否仍真实，并同步 `docs/verification-matrix.md` |
| Weak network、latency、memory、leak、stability 专项 | L6 或 L7 |

## 测试质量规则

- 只测 public behavior，不绑 private method、call count 或实现顺序。
- Mock 只放在系统边界或设计 seam；当前 `NativeHttpEngine` injection 是 client contract seam。
- Unit tests 不访问 public network。
- Loopback harness 只访问 `127.0.0.1`。
- 三端新增或修改 automated tests、integration checks 或 harness scenarios 时，每个独立测试意图必须有精简中文验证意图注释；注释描述要保护的 public behavior 和回归风险，不描述实现步骤。
- 命令、路径、API 名和代码标识符保持 English/ASCII。

短测试可使用单行模板：

```text
// 验证意图：当 <场景> 时，<public interface> 应 <行为>；防止 <风险>。
```

复杂 test 或 harness scenario 使用多行模板：

```text
// 验证意图：
// - 场景：<触发条件或输入>
// - 行为：<public interface> 应 <可观察结果>
// - 风险：防止 <回归或误分类>
```

适用范围：

- iOS Swift/XCTest 或 Swift Testing：放在 test method 内靠近 Arrange 段。
- Android Kotlin/JUnit 或后续 instrumented tests：放在 test method 内靠近 Arrange 段。
- Harmony ArkTS tests 或 harness scenarios：放在独立 scenario 开始处。
- 一个 harness 内包含多个独立 scenario 时，每个 scenario 都要有自己的验证意图。

## PR 说明

测试、harness 或 verification script 变更进入 PR 时，说明：

- 涉及哪些测试层级。
- 新增测试的验证意图。
- 跑过哪些命令，哪些未跑。
- residual risk。
