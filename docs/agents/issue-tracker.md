# Issue tracker

本 repo 的 issues 和 PRDs 使用 GitHub Issues 管理。相关 skills 需要发布、读取或更新 issue 时，默认在当前 git remote 对应的 GitHub repo 中操作。

## 约定

- 创建 issue 使用 `gh issue create`。
- 读取 issue 使用 `gh issue view <number> --comments`。
- 列出 issue 使用 `gh issue list`，按需要附加 label、state 和 JSON 字段。
- 评论 issue 使用 `gh issue comment <number>`。
- 修改 labels 使用 `gh issue edit <number> --add-label` 或 `--remove-label`。
- 关闭 issue 使用 `gh issue close <number>`。

运行 `gh` 时从当前 clone 的 `git remote -v` 推断 repo。若 GitHub 登录、权限或网络不可用，必须说明阻塞项，不要假装已经发布。

## Skill 语义

当 skill 说 “publish to the issue tracker” 时，在 GitHub Issues 创建 issue。

当 skill 说 “fetch the relevant ticket” 时，读取对应 GitHub issue 及 comments。
