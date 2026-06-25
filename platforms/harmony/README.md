# HarmonyOS 平台工程指南

## 当前状态

HarmonyOS 平台目前是 DevEco Studio 26 / Hvigor `modelVersion: "26.0.0"` 风格的 HAR module 和 example shell。当前 `./scripts/verify-harmony.sh` 能发现 DevEco Studio bundled `hvigorw` 和 `ohpm`，并已在本机完成 ArkTS L1/L2 unit tests 与 HAR/HAP CLI build 验证。

## 目标结构

```text
platforms/harmony/
  AppScope/
  build-profile.json5
  hvigor/
    hvigor-config.json5
  hvigorfile.ts
  native-netkit/
  example/
    entry/
```

- `native-netkit`：HAR module skeleton。
- `example/entry`：ArkUI example shell。

## 打开方式

在 DevEco Studio 中打开：

```text
platforms/harmony
```

打开后需要确认 HAR module 和 example entry module 能被 DevEco 正确识别。

## 验证

从仓库根目录运行：

```bash
./scripts/verify-harmony.sh
```

脚本会按顺序探测 `platforms/harmony/hvigorw`、PATH 上的 `hvigorw` 和 DevEco Studio bundled `hvigorw`。如果 Hvigor 可用，脚本目标是运行：

```bash
ohpm install
hvigorw --mode module -p module=NativeNetKit test --no-daemon --no-parallel
hvigorw --mode module -p module=NativeNetKit assembleHar --no-daemon --no-parallel
hvigorw assembleHap --no-daemon --no-parallel
```

如果缺少 `ohpm` 或 `hvigorw`，脚本会输出 pending 信息。如果能发现 Hvigor 但测试或构建失败，应报告真实错误，不应把失败写成 passed。

当前 Harmony L1 client contract tests 和 L2 `RcpNativeHttpEngine` adapter mapping tests 已通过 `hvigorw --mode module -p module=NativeNetKit test` 覆盖。L2 使用 fake RCP session seam，只验证 `NativeRequest` 到 platform request seam、platform response 到 `NativeResponse`、platform error 到 `NativeNetworkError` 的映射，不访问真实网络。Harmony L3 host loopback、DevEco Studio 手工验收、设备运行和 L5 runtime validation 仍是 pending。

## 后续验收条件

后续如要提升 Harmony 验证层级，至少需要继续确认：

- DevEco Studio 可以打开 `platforms/harmony` 并识别 modules。
- Host loopback 或受控 endpoint integration 可稳定运行。
- 如果新增运行时示例，再补充设备或模拟器运行验收。

在这些动作真实执行前，任何 Harmony 相关改动都只能报告为结构或文档层面的更新。
