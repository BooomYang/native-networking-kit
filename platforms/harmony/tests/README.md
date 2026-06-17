# Harmony 测试

Harmony verification 仍在等待本地 DevEco/Hvigor setup。

Toolchain 可用后的目标命令：

```bash
platforms/harmony/hvigorw --mode module -p module=NativeNetKit assembleHar
platforms/harmony/hvigorw assembleHap
```

当前脚本：

```bash
./scripts/verify-harmony.sh
```

如果缺少 `hvigorw`，脚本会以 pending 状态退出，并且不会声称 Harmony build verification 已通过。
