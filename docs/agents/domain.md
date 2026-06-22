# Domain docs

本 repo 是 single-context repo。Engineering skills 在生成 PRD、做 TDD 计划、诊断问题或 grill 方案前，应先读取 root `CONTEXT.md`，再按任务相关性读取 `docs/decisions/` 中的 ADR-style decisions。

## 读取顺序

1. `CONTEXT.md`：项目术语表，只用于统一项目语言。
2. `docs/decisions/`：本 repo 的 ADR/decision log。虽然部分 skills 默认寻找 `docs/adr/`，本 repo 当前使用 `docs/decisions/`，不要为了模板目录新增重复 ADR 目录。
3. 任务相关文档：例如 `docs/testing-strategy.md`、`docs/verification-matrix.md`、平台 README 或具体 requirement 文档。

## 使用规则

- 输出 issue、PRD、测试计划、review 或实现方案时，优先使用 `CONTEXT.md` 中的 canonical terms。
- 如果要使用 `CONTEXT.md` 明确 `_Avoid_` 的叫法，先指出原因，并优先发起 `/grill-with-docs` 弄清是否需要改术语。
- 如果方案与 `docs/decisions/` 中已接受的 decision 冲突，必须显式说明冲突点，不要静默覆盖。
- 不要把 `CONTEXT.md` 当作 spec、测试矩阵或验证记录；工程规则仍以 `AGENTS.md` 和 `docs/` 中的专项文档为准。
