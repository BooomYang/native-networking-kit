# iOS 平台工程指南

## 目标结构

iOS 平台采用一个标准 Swift Package library，加一个用于集成验证的 Xcode 宿主 app：

```text
platforms/ios/
  Package.swift
  Sources/NativeNetKit/
  Tests/NativeNetKitTests/
  Harnesses/NetworkHarness/
  Examples/NativeNetKitExample/
    NativeNetKitExample.xcodeproj
    NativeNetKitExample/
      NativeNetKitExampleApp.swift
```

`Package.swift` 只负责发布和测试 `NativeNetKit` library product。`NativeNetKitExample.xcodeproj` 是真实 iOS App project，通过 local Swift Package dependency 引用 `../../Package.swift`。

## 打开方式

- Library/tests：在 Xcode 中打开 `platforms/ios/Package.swift`。
- Example app：在 Xcode 中打开 `platforms/ios/Examples/NativeNetKitExample/NativeNetKitExample.xcodeproj`，选择 `NativeNetKitExample` scheme 和 iPhone Simulator 后运行。

不要把 SwiftPM executable example 当作 iOS host app。iOS 可运行宿主应是 Xcode App project，并通过 package product 依赖库，而不是把 library 源码直接拖进 app target。

## 验证

从仓库根目录运行：

```bash
./scripts/verify-ios.sh
```

该脚本会：

- 运行 `platforms/ios` Swift Package tests；
- 构建 `NativeNetKitExample.xcodeproj`；
- 将 SwiftPM、Xcode package cache 和 DerivedData 写入 `.tmp/`。

iOS unit tests 使用 injected mock engine，不执行 real network I/O。Example app 只有在用户点击 GET 时才会访问输入的真实 URL。

如需验证真实 `URLSessionNativeHttpEngine` 在可控网络刺激下的行为，可以运行 opt-in loopback harness：

```bash
./scripts/verify-ios-network-harness.sh
```

该脚本会启动 `127.0.0.1` mock HTTP server，并运行独立 Swift executable harness。它覆盖 success tracer、delay、closed connection 和 unused port cases，不访问 public network，也不属于默认 unit tests。HTTP non-2xx 主验证放在 L2 adapter unit tests。

三端测试分层和 PR 审阅规则见 [测试策略](../../docs/testing-strategy.md)。iOS L3 细节见 [iOS 网络验证 Harness](../../docs/ios-network-harness.md)。未实际运行 L5-L7 时，只能标记为 manual、optional 或 pending。

## 常见问题

- `missing its project.pbxproj file`：`.xcodeproj` 只是空目录或缺少核心工程文件，需要恢复完整 Xcode project bundle。
- Xcode 只看到 `Package.swift`，看不到可 Run 的 app：当前打开的是 library package，不是 example app project。
- `Missing package product 'NativeNetKit'`：检查 app project 是否通过 local Swift Package dependency 指向 `../../Package.swift`，并确认 target 链接了 `NativeNetKit` product。
- `CoreUI: CUICatalog ... APPLE10`：通常是 Simulator/CoreUI 系统日志；如果 app 正常展示，可以视为非阻塞 warning。

## 官方参考

- [Creating a standalone Swift package with Xcode](https://developer.apple.com/documentation/xcode/creating-a-standalone-swift-package-with-xcode)
- [Adding package dependencies to your app](https://developer.apple.com/documentation/xcode/adding-package-dependencies-to-your-app)
- [Organizing your code with local packages](https://developer.apple.com/documentation/xcode/organizing-your-code-with-local-packages)
- [PackageDescription.Package](https://developer.apple.com/documentation/packagedescription/package)
