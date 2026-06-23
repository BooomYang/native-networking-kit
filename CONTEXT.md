# NativeNetKit Context

本文件是 NativeNetKit 的 single-context glossary，用来统一三端原生网络库 Phase 1 的项目语言。这里只定义术语，不记录验证命令、工程规则、实现方案或测试矩阵。

## Language

**NativeNetClient**:
三端对齐的 public client 概念，负责接收 `NativeRequest` 并返回 `NativeResponse` 或 `NativeNetworkError`。它代表 library 使用者面对的主要入口，而不是某个平台底层网络栈本身。

**NativeHttpEngine**:
三端对齐的 engine boundary，表示真正执行 HTTP 请求的可替换能力边界。它既可以由平台默认 engine adapter 实现，也可以在测试中由 mock engine 实现。

**NativeRequest**:
三端对齐的请求模型，用来表达 client 需要发送的 HTTP method、URL、headers 和 body 等输入。它是 NativeNetKit 的 public request shape，不是某个平台原生请求类型的别名。

**NativeResponse**:
三端对齐的响应模型，用来表达 HTTP status、headers、body 和 timing 等输出。它是 NativeNetKit 暴露给调用方的 response shape，不直接等同于 `URLResponse`、OkHttp response 或 HarmonyOS 平台响应对象。

**NativeNetworkError**:
三端对齐的网络错误概念，用来表达调用方可见的 invalid request、transport failure、cancellation 和 unknown 等 public error semantics。它不暴露平台内部异常类型，也不表示 Phase 1 已经建模完整 HTTP、timeout 或 reliability 错误体系。

**engine adapter**:
把平台原生网络能力适配到 `NativeHttpEngine` boundary 的实现。Phase 1 中它应该保持 thin，只做必要的 request、response 和 error mapping。
_Avoid_: optimization engine, governance engine, full networking stack

**engine injection**:
把 `NativeHttpEngine` 作为可替换依赖传入 client 的设计边界。它让 unit tests 使用 mock engine，也让 examples 或实际集成使用平台默认 engine。
_Avoid_: global engine, hidden singleton, public network unit test seam

**request lifecycle**:
一次 `NativeNetClient` request 从调用方发起到返回 response、error 或 cancellation 的可观察生命周期。它应归属于调用方的 async、coroutine 或 promise 生命周期，而不是脱离调用方继续运行的后台工作。
_Avoid_: detached request, hidden background work, fire-and-forget request

**Phase 1**:
本 repo 当前阶段的 bootstrap 范围，目标是建立三端原生工程底座、对齐 public concepts、保留最薄 engine adapter 和基础验证入口。它不包含 QUIC、HTTPDNS、IP racing、multi-network recovery、connection governance、full observability 或 KMP。

**verification layer**:
项目用来描述验证责任边界的层级语言，例如 client contract、engine adapter mapping、platform runtime、package/example build 和后续弱网或性能验证。它描述“验证在哪一层成立”，不等同于某一个脚本或单测文件。
_Avoid_: all tests, passed everything, release readiness

**Swift host loopback check**:
运行在 macOS Swift host process 中的本地回环集成检查，使用真实 `URLSessionNativeHttpEngine` 和 `URLSession` 访问 `127.0.0.1` mock server。它验证少量真实 host transport boundary，不等于 iOS Simulator/device L3。
_Avoid_: host loopback harness, iOS L3 harness, platform runtime harness

**preflight**:
进入 PR、merge、release 或 handoff 之前运行的组合验证入口。它只表示当前变更通过了该决策点要求的 checks，不表示已经完成更大范围的 runtime、弱网、性能或全平台验证。
_Avoid_: full validation, release validation, all tests passed
