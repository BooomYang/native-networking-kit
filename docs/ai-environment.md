# AI 环境

## 基线

本仓库保持第一版 AI coding environment 轻量：

- Git repository 用于 Codex review、worktrees 和未来 PR workflows。
- `AGENTS.md` 提供持久化 repo guidance。
- `scripts/` 下的稳定 scripts 用于 verification。
- `docs/verification-matrix.md` 记录 commands 和 toolchain truth。
- `docs/decisions/` 下的 ADR 记录需要跨越 chat context 保留的 decisions。

## 候选 MCP 和 IDE 集成

以下内容只是候选项，不是 Phase 1 requirements：

- OpenAI Docs MCP：用于获取当前 Codex/OpenAI guidance。
- Android Studio / JetBrains MCP：在此环境中的 Android Studio 支持 MCP Server 后，将 IDE build、inspections 和 run configurations 暴露给 Codex。
- GitHub connector 或 CLI：仓库托管后用于 PRs、issues、CI status 和 review comments。
- Browser 或 Playwright MCP：仅当 example UIs 变为 web-testable 或 browser-mediated 时使用。
- `codex exec --json`：后续用于 machine-readable triage、release notes 或 CI summaries。

## 目前不添加的内容

- Hooks：只有 repeated failure 足以证明需要 mechanical enforcement 后再添加。
- Automations：只有 manual workflow 具备稳定 input、output 和 acceptance criteria 后再添加。
- Custom skills：只有同一 workflow 被重复执行并打磨后再添加。
- Evals：至少出现一个 repeatable failure 或 behavior target 后再添加。

## Codex 使用模式

后续 requirements 使用以下模式：

```text
Goal + Context + Constraints + Done when
-> 读取相关文件
-> 实现有边界的改动
-> 运行相关 script
-> 检查 diff 中的 regression 和 test gap
-> 仅当本轮产生可复用知识时，更新 docs 或 ADR
```
