# NativeNetKitExample

这是用于集成验证 `NativeNetKit` Swift Package 的 iOS 宿主 app。

## 打开方式

在 Xcode 中打开：

```text
platforms/ios/Examples/NativeNetKitExample/NativeNetKitExample.xcodeproj
```

选择 `NativeNetKitExample` scheme 和 iPhone Simulator 后运行。

## 集成关系

这个 app project 通过 local Swift Package dependency 引用：

```text
../../Package.swift
```

这等价于 CocoaPods 时代 example app 中的：

```ruby
pod 'NativeNetKit', :path => '../..'
```

因此 example 验证的是外部宿主 app 对 `NativeNetKit` package product 的真实集成，而不是把 library 源码直接拖进 app target 编译。
