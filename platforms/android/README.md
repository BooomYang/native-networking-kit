# Android 平台工程指南

## 目标结构

Android 平台是一个 Gradle root project，包含 library module、example app 和测试入口：

```text
platforms/android/
  build-logic/
  gradle/libs.versions.toml
  settings.gradle.kts
  build.gradle.kts
  gradlew
  native-netkit/
  example/
```

- `:native-netkit`：Android library module，产物形态是 AAR/Maven publication。
- `:example`：集成验证 app，通过 `implementation(project(":native-netkit"))` 引用 library。
- `build-logic`：Gradle composite build，提供 Android library/application convention plugins。
- `gradle/libs.versions.toml`：集中管理 Android Gradle Plugin、Kotlin、OkHttp 和 coroutines 版本。

## 组件与宿主集成

`:native-netkit` 是可独立开发、测试、lint 和发布的 Android 网络库组件。它应用 `native-netkit.android.library` convention plugin，统一 `compileSdk`、`minSdk`、Java/Kotlin toolchain 等 Android library 基础配置；module 自身只保留 namespace、consumer ProGuard、publishing 和依赖声明。

`:example` 是本地集成宿主壳。它应用 `native-netkit.android.application` convention plugin，并通过 `implementation(project(":native-netkit"))` 消费当前源码中的 library，用于 Android Studio、Gradle assemble 和后续 emulator/device harness 的快速验证。example 不承载 library 业务逻辑，也不代表发布产物消费验证。

## 打开方式

在 Android Studio 中打开：

```text
platforms/android
```

打开后需要完成 Gradle sync。当前 README 只描述工程入口和脚本目标；如果没有实际执行 Android Studio sync、Run Configuration 或模拟器/真机运行，不要声称 Android example 已完成 IDE/设备级验收。

## 验证

从仓库根目录运行：

```bash
./scripts/verify-android.sh
```

该聚合脚本在 Android SDK 可用时会运行：

```text
:native-netkit:test
:native-netkit:lint
:native-netkit:publishToMavenLocal
:example:lint
:example:assembleDebug
```

脚本使用 `platforms/android/gradlew`，并把 Gradle user home、Android user state 和 Maven local output 重定向到 `.tmp/`。

组件独立验证：

```bash
./scripts/verify-android-library.sh
```

该脚本只验证 `:native-netkit` 的 unit tests、lint 和 Maven local publication，不依赖 example。

example 宿主集成验证：

```bash
./scripts/verify-android-example.sh
```

该脚本验证 `:example` 通过 `implementation(project(":native-netkit"))` 本地集成 library 后可以 lint 和 assemble debug。

需要采集 Android platform runtime readiness evidence 时，先启动一个 emulator 或连接一个设备，再运行 opt-in 脚本：

```bash
./scripts/verify-android-emulator.sh
```

该脚本会先运行 `./scripts/verify-android.sh`，再通过本机 Android SDK 下的 `adb` 安装并启动 `:example`，采集 foreground、`uiautomator dump` 和 bounded logcat 证据到 `.tmp/android-emulator-harness/`。如果有多个 online ADB target，需要设置 `ANDROID_SERIAL`。该脚本只验证初始 UI 的 `Ready` 和 `GET` 可见，不点击 `GET`，不计入 L5，也不代表 Android Studio、真机或公网请求验证通过。

## 当前验收边界

- Unit tests 使用 injected mock engine，不执行 real network I/O。
- 当前 Android L1/L4 入口由 `./scripts/verify-android-library.sh`、`./scripts/verify-android-example.sh` 和 `./scripts/verify-android.sh` 覆盖；L2 adapter stub、emulator/device L3 和 L5 仍是 target/pending。
- `:example:assembleDebug` 只能证明 example app 可以构建，不等同于已经在 Android Studio 或模拟器中手动运行通过。
- 如果当前机器缺少 Android SDK，`./scripts/verify-android.sh` 应明确失败并提示配置 `ANDROID_HOME` 或 `ANDROID_SDK_ROOT`，不能把该平台标记为 passed。

## 常见问题

- Android Studio 没有识别 module：确认打开的是 `platforms/android`，不是仓库根目录或单个 module。
- Android SDK not found：安装 Android SDK，或设置 `ANDROID_HOME` / `ANDROID_SDK_ROOT`。
- Gradle 依赖写入用户目录：使用根脚本验证，脚本会把相关 cache 指到 `.tmp/`。
