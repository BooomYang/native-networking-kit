# ADR 0002: Phase 1 只保留 thin engine adapter

## 状态

Accepted

## 背景

参考设计包含多个有价值的 optimization capabilities，但第一个实现里程碑是让仓库可构建、可验证。在 project harness 稳定前实现 optimization behavior，会模糊 bootstrap 和 feature work 的边界。

## 决策

Phase 1 只实现：

- native request、response、error、client 和 engine concepts；
- engine injection；
- platform default engine shape；
- mock-engine unit tests；
- example UI shells。

Phase 1 不实现 QUIC、HTTPDNS、IP racing、multi-network recovery、connection governance、full observability 或 KMP。

## 后果

- 第一版 repo state 足够小，便于 inspect 和 review。
- 后续 capabilities 可以通过明确的 requirement loops 进入。
- Tests 聚焦 API forwarding、response mapping 和 error propagation，而不是 network behavior。
