# 核心算法形式化验证合约

完整、可维护的合约状态表位于仓库根目录的 [`docsCONTRACTS.md`](../docsCONTRACTS.md)。

该表逐条记录 C1-C6 生产 API 合约的 `unknown / runtime-only` 状态，以及
`src/contracts_proof` 中 P1-P4 证书的 `proven` 状态、前置/后置条件、工具链限制
和复现命令。文档明确区分生产 CSR 运行时断言与独立 `FixedArray` 证明证书，不将
模型证书误报为生产实现的自动证明结果。
