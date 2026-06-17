# iOS 项目启动最小指南

本文用于避免把 Swift Package、Xcode App project 和 example host app 混在一起。它是 native iOS 项目启动时的最小工程判断，不替代 Apple 官方文档。

## 先判断目标形态

| 目标 | 推荐入口 |
| --- | --- |
| 只做 Swift 库 | Standalone Swift Package |
| 只做正式 iOS App | Xcode iOS App project |
| 做 Swift 库并提供可运行示例 | Swift Package library + Xcode host app project |

对于本仓库，目标是第三种：

```text
Swift Package library
  -> product NativeNetKit
Xcode host app project
  -> local Swift Package dependency
  -> import NativeNetKit
```

## 推荐目录

```text
platforms/ios/
  Package.swift
  Sources/<LibraryName>/
  Tests/<LibraryName>Tests/
  Examples/<ExampleApp>/
    <ExampleApp>.xcodeproj
    <ExampleApp>/
      <ExampleApp>App.swift
```

`Package.swift` 是库的发布、测试和依赖入口。`Examples/<ExampleApp>.xcodeproj` 是真实 iOS 宿主 app，用于验证外部 app 如何集成这个库。

## CocoaPods 类比

Objective-C / CocoaPods 时代常见形态：

```ruby
pod '<LibraryName>', :path => '../..'
```

Swift Package 时代对应为：

```text
Xcode App project
  -> Add Package Dependency
  -> local path: ../../Package.swift
  -> link product: <LibraryName>
```

这表示 example app 像外部使用者一样依赖库，而不是把库源码直接拖进 app target。

## 不推荐的混用

- 用 SwiftPM executable example 充当 iOS App 宿主。
- 创建空 `.xcodeproj` 目录但缺少 `project.pbxproj`。
- App target 直接编译 library 源码，而不是依赖 Swift Package product。
- CLI build 未验证时，只因为 Xcode GUI 能打开就声称工程正确。

## 最小验证

从仓库根目录运行：

```bash
swift test --package-path platforms/ios
xcodebuild \
  -project platforms/ios/Examples/NativeNetKitExample/NativeNetKitExample.xcodeproj \
  -scheme NativeNetKitExample \
  -destination "generic/platform=iOS Simulator" \
  CODE_SIGNING_ALLOWED=NO \
  build
```

本仓库封装为：

```bash
./scripts/verify-ios.sh
```

如果 CLI build 成功但 Xcode GUI 不能运行，优先排查 DerivedData、Package cache、scheme、destination、Simulator runtime 和 signing，而不是先改源码结构。

## 官方参考

- [Creating a standalone Swift package with Xcode](https://developer.apple.com/documentation/xcode/creating-a-standalone-swift-package-with-xcode)
- [Adding package dependencies to your app](https://developer.apple.com/documentation/xcode/adding-package-dependencies-to-your-app)
- [Organizing your code with local packages](https://developer.apple.com/documentation/xcode/organizing-your-code-with-local-packages)
- [PackageDescription.Package](https://developer.apple.com/documentation/packagedescription/package)
