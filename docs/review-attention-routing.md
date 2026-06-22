# Review Attention Routing

本文只记录未来方向，不定义当前 GitHub workflow、labels、API 或 review state parser。

## 目标

当 Codex Review 或 CI 产生建议时，未来可以按风险和 hot zone 分类，只把 P0/P1 加 hot-zone 的信号推给维护者。

```text
Codex Review / CI signals
        |
        v
risk + hot-zone classification
        |
        v
maintainer attention for P0/P1 hot-zone risks
```

## 为什么暂不实现

当前项目仍在 Phase 1 harness foundation。GitHub review data model 包含 dismissed review、resolved/outdated thread、inline comment、issue comment、router 自身 summary、token 权限边界等状态。现在实现状态解释器会比本轮 harness 本身更重。

## 当前非目标

- 不新增 GitHub Actions workflow。
- 不写 attention labels 或 PR summary comment。
- 不解析 GitHub REST/GraphQL review state。
- 不做 auto merge、auto notification 或非作者批准硬门禁。
- 不替代人工 review 或 PR 作者的验证说明。
