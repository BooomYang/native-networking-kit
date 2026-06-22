# iOS 测试

主要命令：

```bash
./scripts/verify-ios-tests.sh
```

Test suite 使用 injected mock engines，不执行 real network I/O。

测试分层和注释模板见 `../../../docs/testing-strategy.md`。

需要同时构建 Xcode host example app 时运行：

```bash
./scripts/verify-ios.sh
```
