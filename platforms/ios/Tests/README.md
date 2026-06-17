# iOS 测试

主要命令：

```bash
./scripts/verify-ios.sh
```

Test suite 使用 injected mock engines，不执行 real network I/O。

Verification script 还会构建 `platforms/ios/Examples/NativeNetKitExample/NativeNetKitExample.xcodeproj`。
