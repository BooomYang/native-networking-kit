# Android 测试

常用命令：

```bash
./scripts/verify-android.sh
```

Library L1/L2 验证：

```bash
./scripts/verify-android-library.sh
```

L1 client contract tests 使用 injected mock engines，不执行 real network I/O。L2 engine adapter unit tests 使用 fake `Call.Factory`，验证 `OkHttpNativeHttpEngine` 的 request、response 和 error mapping，不访问 public network。

L3 host loopback 验证：

```bash
./scripts/verify-android-network-harness.sh
```

该脚本启动 repo-level 共享 Node mock server，并运行 `:native-netkit:networkHarnessTest`。它通过真实 `OkHttpNativeHttpEngine` 访问 `127.0.0.1`，覆盖 success、delay、closed connection 和 unused port；它不属于 emulator/device L5。

Android PR preflight：

```bash
./scripts/verify-android-pr.sh
```

该脚本组合 library、example 和 host loopback checks，覆盖 L1、L2、L3 和 L4。`./scripts/verify-android.sh` 保持为 library + example aggregate，不包含 L3。

脚本使用 `platforms/android/gradlew`；当 `ANDROID_HOME` 尚未配置时，会从 `~/Library/Android/sdk` 设置；并把 Gradle、Android user state 和 Maven local output 重定向到仓库内的 `.tmp/`。

在 Android Studio 中打开 `platforms/android`，用于 Gradle sync、IDE inspections 和 Run Configuration setup。
