# Harmony 测试

Harmony L1/L2 verification 使用 Hvigor/Hypium unit test。L1 覆盖 `NativeNetClient` + injected engine 的 request/response/error contract；L2 覆盖 `RcpNativeHttpEngine` + fake RCP session seam 的 adapter mapping，不访问真实网络。

目标命令：

```bash
cd platforms/harmony
(cd native-netkit && ohpm install)
hvigorw --mode module -p module=NativeNetKit test --no-daemon --no-parallel
platforms/harmony/hvigorw --mode module -p module=NativeNetKit assembleHar
platforms/harmony/hvigorw assembleHap
```

当前脚本：

```bash
./scripts/verify-harmony.sh
```

如果缺少 `ohpm` 或 `hvigorw`，脚本会以 pending 状态说明缺失工具；如果能发现 Hvigor 但 unit test 或 build 失败，应报告真实错误。当前本机可发现 DevEco Studio bundled `ohpm`/`hvigorw`，且 Harmony L1/L2 unit tests 与 HAR/HAP CLI build 已通过。

当前仍 pending：

- L3 host loopback integration。
- DevEco Studio 手工验收。
- 设备运行或 L5 platform runtime validation。
