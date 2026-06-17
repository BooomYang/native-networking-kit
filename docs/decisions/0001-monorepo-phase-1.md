# ADR 0001: Phase 1 使用 native monorepo

## 状态

Accepted

## 背景

项目需要启动 iOS、Android 和 HarmonyOS 三端原生网络库，同时保持各平台实现为 platform-native。后续开发会使用 loop-engineering practices，因此 Codex 需要稳定的 project context、verification commands 和 review boundaries。

## 决策

使用一个 monorepo，并在 `platforms/` 下分别放置各平台的 native platform projects。

Phase 1 的共享层是 documentation、naming、verification 和 aligned concepts。没有 shared runtime code，也没有 KMP bridge。

## 后果

- Codex 可以从一个 Git root 和一个 `AGENTS.md` 开始工作。
- Cross-platform docs 和 verification 与代码保持接近。
- Platform packages 保持原生：Android 使用 AAR/Maven，iOS 使用 Swift Package，HarmonyOS 使用 HAR/Hvigor。
- 后续 cross-platform behavior 必须通过 docs、tests 和 reviews 有意识地保持对齐。
