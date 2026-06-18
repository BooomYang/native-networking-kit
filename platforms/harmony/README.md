# HarmonyOS 平台工程指南

## 当前状态

HarmonyOS 平台目前是 DevEco/Hvigor 风格的 HAR skeleton 和 example shell。由于本地 `hvigorw` / DevEco 验证尚未完成，该平台必须保持 pending 状态，不能声称 build verification 已通过。

## 目标结构

```text
platforms/harmony/
  build-profile.json5
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

如果 `platforms/harmony/hvigorw` 或 PATH 上的 `hvigorw` 可用，脚本目标是运行：

```bash
hvigorw --mode module -p module=NativeNetKit assembleHar
hvigorw assembleHap
```

如果缺少 `hvigorw`，脚本会输出 pending 信息。pending 是当前 harness 的真实状态，不应改写成 passed。

## 后续验收条件

在具备 DevEco/Hvigor 环境后，至少需要确认：

- DevEco Studio 可以打开 `platforms/harmony` 并识别 modules。
- HAR module 可以 assemble。
- Example HAP 可以 assemble。
- 如果新增运行时示例，再补充设备或模拟器运行验收。

在这些动作真实执行前，任何 Harmony 相关改动都只能报告为结构或文档层面的更新。

三端通用测试分层和 PR 审阅规则见 `../../docs/testing-strategy.md`；Harmony L2/L3 需要在 Hvigor/DevEco 验证可运行后再补。
