# Android 测试

主要命令：

```bash
./scripts/verify-android.sh
```

Library unit tests 位于 `native-netkit/src/test`，并使用 injected mock engines。它们不执行 real network I/O。

脚本使用 `platforms/android/gradlew`；当 `ANDROID_HOME` 尚未配置时，会从 `~/Library/Android/sdk` 设置；并把 Gradle、Android user state 和 Maven local output 重定向到仓库内的 `.tmp/`。

在 Android Studio 中打开 `platforms/android`，用于 Gradle sync、IDE inspections 和 Run Configuration setup。
