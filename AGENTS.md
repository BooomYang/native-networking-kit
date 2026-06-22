# AGENTS.md

## Repository Expectations

- Purpose: This repository is the Phase 1 monorepo for native iOS, Android, and HarmonyOS networking libraries.
- Non-goals: Do not add QUIC, HTTPDNS, IP racing, multi-network recovery, connection governance, full observability, KMP, or shared runtime code unless a later requirement loop explicitly asks for it.

## Repository Structure

```text
native-networking-kit/
├── platforms/android/   # Android Gradle library, example app, and tests
├── platforms/ios/       # Swift Package library, tests, Xcode host app, and host harnesses
├── platforms/harmony/   # Harmony/ArkTS HAR skeleton, example shell, and pending validation notes
├── docs/                # Phase 1 context, verification matrix, testing strategy, and decisions
├── scripts/             # Stable commands for humans and Codex
└── AGENTS.md            # Durable Codex guidance
```

- Platform setup and IDE notes belong in each platform README.
- Keep long strategy and validation details in `docs/`, not in this file.

## Commands

- Doctor: `./scripts/doctor.sh`
- iOS tests L1/L2: `./scripts/verify-ios-tests.sh`
- iOS build L4: `./scripts/verify-ios.sh`
- iOS PR preflight: `./scripts/verify-ios-pr.sh`
- Swift host loopback harness: `./scripts/verify-ios-network-harness.sh`
- Android verification: `./scripts/verify-android.sh`
- Harmony verification: `./scripts/verify-harmony.sh`
- Local verification: `./scripts/verify-local.sh`

## Project Conventions

- Phase 1 shared behavior is aligned through naming, docs, tests, and verification; it is not shared runtime code.
- Public concepts stay aligned across platforms: `NativeNetClient`, `NativeHttpEngine`, `NativeRequest`, `NativeResponse`, and `NativeNetworkError`.
- Unit tests use injected or mockable boundaries and do not depend on public network access.
- Avoid new production dependencies unless they are native-platform standard practice for the current layer.

## Project Hot Zones

- Public API semantics and error mapping for the aligned concepts above.
- Platform engine boundaries, especially iOS `URLSessionNativeHttpEngine`, Android OkHttp adapter work, and Harmony adapter skeletons.
- Test, harness, verification scripts, build manifests, package metadata, README, `AGENTS.md`, and truth-bearing docs.
- Any code or docs that imply pending Android Studio, device, Simulator, DevEco, Hvigor, weak-network, performance, or reliability validation has passed.

## Verification

- Start with the smallest relevant script for the changed platform or layer.
- iOS PR work defaults to `./scripts/verify-ios-pr.sh`.
- `./scripts/verify-local.sh` is the stable local aggregate; it does not run the Swift host loopback harness.
- If a toolchain is missing, report the exact missing tool and residual risk. Never mark pending validation as passed.
- Testing layers and intent-comment rules live in `docs/testing-strategy.md`; current platform status lives in `docs/verification-matrix.md`.

## Review Guidelines

- Review behavior regressions before style.
- Check changed behavior has useful tests at the lowest effective layer.
- Treat hot-zone changes as requiring explicit validation evidence or a clear residual-risk note.
- For platform-specific changes, confirm unchanged platforms are still described truthfully and conceptually aligned.

## Security And Secrets

- Do not commit local caches, credentials, generated packages, or machine state; keep tool output in `.tmp/` where scripts already do so.
- Do not add internal-company dependencies or private infrastructure assumptions to the library.
- Public-network behavior belongs in examples or opt-in harnesses, not unit tests.

## Do Not

- Do not run destructive commands without explicit approval.
- Do not rewrite unrelated platform code for narrow tasks.
- Do not weaken verification scripts or tests to make a run pass.
- Do not add review router workflows, GitHub state parsers, attention labels, or merge automation in this clean harness foundation.
- Do not claim Harmony HAR/HAP, Android IDE/device, or iOS Simulator/device runtime validation passed unless it was actually run.

## Guidance Maintenance

- Add guidance only when it is durable, project-wide, and likely to prevent future mistakes.
- Link canonical docs instead of copying long process text into `AGENTS.md`.
- Use nested `AGENTS.md` only when a subtree gains stable, distinct rules.

## Git And Delivery

- Git commit message, PR title, PR description, GitHub comment, review text, and delivery summary default to Chinese.
- Branch names, commands, file paths, code identifiers, product names, and necessary technical terms stay in English or ASCII.
- Commit messages use a short verb-object form, such as `补充 iOS harness 分层`.
