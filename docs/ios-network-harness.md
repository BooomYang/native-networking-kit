# Swift Host 网络验证 Harness

本文记录 Swift host loopback harness。它运行在本机 Swift/macOS host process 中，不等于 iOS Simulator/device runtime L3。三端通用测试分层见 `docs/testing-strategy.md`。

## 定位

`./scripts/verify-ios-network-harness.sh` 验证 host Swift `URLSession`、`URLSessionNativeHttpEngine` 和 `127.0.0.1` mock server 的端到端 adapter 路径。它不是 unit test，不访问 public network，也不声明覆盖 iOS Simulator/device 网络栈。

```text
NativeNetClient
  -> URLSessionNativeHttpEngine
  -> URLSession
  -> 127.0.0.1 mock server
```

## 覆盖 case

- success tracer：证明真实 HTTP status、body、header 能进入 `NativeResponse`。
- delay：提供后续 timeout、retry、race 能力可复用的延迟刺激源。
- closed connection：验证真实 socket 断开会映射为 `.transportFailure`，并保留 `rawDescription`。
- unused local port：验证连接失败会映射为 `.transportFailure`，并保留 native/raw details。

HTTP non-2xx 语义主验证放在 L2 adapter unit tests，不放 host loopback harness。

## 文件

- `platforms/ios/Harnesses/NetworkHarness/mock-server.js`
- `platforms/ios/Harnesses/NetworkHarness/Package.swift`
- `platforms/ios/Harnesses/NetworkHarness/Sources/NativeNetKitNetworkHarness/main.swift`
- `scripts/verify-ios-network-harness.sh`

## 规则

- 只访问 loopback。
- server 未就绪、端口解析失败、case 失败或 required tool 缺失时返回非零退出码。
- 退出时清理 mock server 进程。
- SwiftPM cache、scratch 和 module cache 写入 `.tmp/ios-network-harness/`。
- iOS Simulator/device L3 仍是 pending；未实际运行前不能写成 passed。

## Optional AI Tooling

`XcodeBuildMCP` 和 OpenAI `build-ios-apps` plugin 可作为后续 L5-L7 workflow 参考，不是 required toolchain。除非后续 ADR 明确升级，仓库脚本不依赖这些工具。
