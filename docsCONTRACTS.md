# 核心算法形式化验证合约

本文件记录本次形式化验证工作的合约、运行时断言与机器证明结果。状态严格区分
生产 API 的运行时检查与独立证明包中由 `moon prove` 验证的证书，不将模型证书
等同于生产 CSR 实现已被自动证明。

## 工具链与验证边界

- 工具链：`moon 0.1.20261102`、`moonc v0.10.19+bee578715`。
- 当前合约语法：`where { proof_require: ...; proof_ensure: result => ... }`。
- 本机运行 `moon prove` 需要可用的 SMT solver；本次通过 `Z3PATH` 指向 Z3 5.3.3。
- `moon prove` 当前不能直接对生产 CSR 使用的 `Array<T>` 建模，因此生产 API
  采用运行时断言；独立证明包使用可建模的 `FixedArray<Int32>` 证书。

## 合约清单

| 合约 | 函数 / 证书 | 前置条件 | 后置条件 | 验证状态 | 备注 |
| --- | --- | --- | --- | --- | --- |
| C1 格式转换保真 | `src/contracts.mbt::csr_to_coo` | 输入为合法 CSR | `result.rows/cols/nnz` 与原矩阵一致，坐标数组长度与值数组一致 | `unknown / runtime-only` | 生产实现使用 `contract_assert`；证明后端不支持 `Array<T>` |
| C2 转置维度对偶 | `src/contracts.mbt::transpose` | 输入为合法 CSR | `result.rows == m.cols`、`result.cols == m.rows`、`result.nnz == m.nnz` | `unknown / runtime-only` | 生产实现使用 `contract_assert`；证明后端不支持 `Array<T>` |
| C3 重排序置换正确性 | `src/contracts.mbt::permute` | `perm.length() == m.rows` 且 `is_permutation(perm)` | 行数、列数与非零数保持不变 | `unknown / runtime-only` | 生产实现使用 `contract_assert`；图排列不变量尚未被自动证明 |
| C4 RCM 带宽不增 | `src/contracts.mbt::rcm` | 输入矩阵对称 | 返回值为排列，且 `bandwidth(permute(m, result)) <= bandwidth(m)` | `unknown / runtime-only` | 运行时断言覆盖完整后置条件；需 `Array` 级图不变量证明 |
| C5 对称诊断无假阳性 | `src/contracts.mbt::is_symmetric` | 无 | 返回 `true` 时逐元素满足 `m[i,j] == m[j,i]`（运行时相对容差） | `unknown / runtime-only` | 返回 `true` 后逐项复核；尚未对生产存储自动证明 |
| C6 PCG 前置/后置条件 | `src/contracts.mbt::pcg` | 对称正定，`b.length() == a.rows`，`x0.length() == a.rows` | 成功返回时 `iterations <= MAX_ITERATIONS` 且 `residual_norm >= 0.0` | `unknown / runtime-only` | 所有成功返回路径均由运行时断言检查；浮点迭代法超出当前证明后端模型 |
| P1 恒等排列证书 | `src/contracts_proof::proof_identity_permutation` | `0 <= n` | 返回长度 `n` 的恒等排列 | `proven` | `FixedArray<Int32>` 模型；由 1 个 Why3/SMT 目标证明 |
| P2 带宽非负证书 | `src/contracts_proof::proof_bandwidth_nonnegative` | 无 | 返回的非负绝对值最大值满足 `0 <= result` | `proven` | `FixedArray<Int32>` 模型；由 1 个 Why3/SMT 目标证明 |
| P3 恒等重排保值证书 | `src/contracts_proof::proof_apply_identity` | 无 | 返回数组长度和逐元素值与原数组一致 | `proven` | `FixedArray<Int32>` 模型；由 1 个 Why3/SMT 目标证明 |
| P4 对角零带宽证书 | `src/contracts_proof::proof_zero_bandwidth` | 无 | `result == 0` 且 `0 <= result` | `proven` | 对角模式带宽为 0；由 1 个 Why3/SMT 目标证明 |

## 验证结果

```text
moon prove src/contracts_proof
Succeeded: 4 goals proved

Summary:
  1 of 1 packages proved
  4 goals proved
```

C1-C6 的生产函数仍以运行时断言保障；本次没有将其自动证明状态虚报为 `proven`。
独立证明包的 4 个证书用于验证排列、带宽非负与恒等重排的基础论证，后续若证明
后端支持 `Array<T>`，可将这些证书提升为生产 CSR 合约的直接证明。

## 复现命令

```powershell
moon fmt --check src/contracts.mbt src/contracts_proof test/contracts_test.mbt
moon check
moon test
$env:Z3PATH = '<path-to-z3.exe>'
moon prove src/contracts_proof
```

CI 若未配置 `Z3PATH`，只执行格式、类型检查与测试；`moon prove` 的 4 条 `proven`
结果为本次本地、带 SMT solver 的实际输出。

## 范围声明

本次变更仅涉及代码、测试、证明与合约文档，不包含申报书、参赛材料或其他提案
文档的修改。
