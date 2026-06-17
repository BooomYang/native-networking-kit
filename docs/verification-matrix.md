# 验证矩阵

## 必需检查

| 区域 | 命令 | Phase 1 预期结果 |
| --- | --- | --- |
| Environment | `./scripts/doctor.sh` | 打印发现到的 toolchain versions 和缺失的 optional tools |
| iOS library/example | `./scripts/verify-ios.sh` | 运行 Swift Package tests，并构建 SwiftUI example |
| Android library/example | `./scripts/verify-android.sh` | 当 Android SDK 可用时，运行 Gradle tests、lint、example assemble 和 local Maven publishing |
| Harmony skeleton | `./scripts/verify-harmony.sh` | 如果 Hvigor 可用则运行；否则以 pending 状态退出并给出清晰信息 |
| All local | `./scripts/verify-local.sh` | 按顺序运行 doctor、iOS、Android 和 Harmony checks |

## 当前本地工具链

| 工具 | 状态 |
| --- | --- |
| Swift | 可用：当前 Codex shell 中为 Apple Swift 6.3.2 |
| Xcode | 可用：当前 Codex shell 中为 Xcode 26.5 |
| Java | 可用：OpenJDK 17 |
| Node | 可用：Node 24.2.0 |
| Gradle | 不要求全局安装；使用 `platforms/android/gradlew` |
| Harmony Hvigor | Pending；当前 `hvigorw` 不在 PATH 上 |

## 平台说明

- iOS tests 使用 mock engine，不执行 network I/O。
- Android unit tests 使用 mock engine，不执行 network I/O。
- Examples 只有在用户操作触发时才可能执行 real network requests。
- Verification scripts 会把工具写入重定向到 `.tmp/`，包括 SwiftPM caches、Gradle home、Android user state 和 Maven local output。
- 在 DevEco/Hvigor 验证准确生成的 project metadata 之前，Harmony files 会刻意保持最小化。

## 手动验收

- 在 Android Studio 中打开 Android project，并确认 Gradle sync。
- 在 Xcode 中打开 iOS Swift Package，并确认 tests 可见。
- 在 DevEco Studio 中打开 Harmony project，并确认 HAR 和 example modules 可被识别。
