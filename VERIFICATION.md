# 验证体系总览（VERIFICATION）

本文件汇总 04 维度的四层验证成果：单元测试、性质测试 Harness、形式化合约与变异测试。所有数字均来自本仓库实际执行结果，未将运行时断言或模型证书虚报为机器证明。

## 1. 验证体系总览

| 层级 | 机制 | 当前规模 | 主要作用 |
| --- | --- | --- | --- |
| 单元测试 | `moon test`，覆盖核心、格式转换、诊断、排序、算子、求解器、WASM 演示 | **91 个测试** | 固定已知边界、回归行为与错误路径 |
| 性质测试 Harness | 6 个语料生成器 × 10 条数学性质，确定性 seed | **small 60/60，medium 60/60** | 检查线性性、转置对合、格式往返、SpGEMM 等价等代数性质 |
| 形式化合约 | `src/contracts.mbt` 运行时合约 + `src/contracts_proof` Why3/SMT 证书 | **4 条 `proven`；C1-C6 runtime-only** | 表达关键前置/后置条件，并对可建模部分做机器证明 |
| 变异测试 | `tools/mutate.sh` 注入源码，逐个运行完整 `moon test` | **36 个变异体，36 killed，0 survived** | 量化测试套件发现真实实现缺陷的能力 |

```text
                  ┌──────────────────────────────┐
                  │ 变异测试：36/36 killed       │
                  ├──────────────────────────────┤
                  │ 形式化：4 proven + 6 runtime │
                  ├──────────────────────────────┤
                  │ 性质 Harness：60 + 60 cases  │
                  ├──────────────────────────────┤
                  │ 单元测试：91 tests           │
                  └──────────────────────────────┘
```

## 2. 测试覆盖统计

| 验证入口 | 命令 | 实际结果 |
| --- | --- | --- |
| 单元测试 | `moon test` | `Total tests: 91, passed: 91, failed: 0.` |
| Harness small | `moon run harness/runner --seed=42 --scale=small` | `total: 60, passed: 60, failed: 0` |
| Harness medium | `moon run harness/runner --seed=42 --scale=medium` | `total: 60, passed: 60, failed: 0` |
| 格式检查（本次变更） | `moon fmt --check test/ordering_test.mbt test/diagnostics_test.mbt` | 通过 |
| 类型检查 | `moon check` | 0 errors；既有警告不影响结果 |

Harness 的 60 个组合来自 6 个确定性语料（`random_sparse`、`diagonal_dominant`、`symmetric_positive_definite`、`block_diagonal`、`banded`、`ill_conditioned`）与 10 条性质（`spmv_linearity`、`spmv_zero_vector`、`spgemm_dense_equivalence`、`spgemm_identity`、`transpose_involution`、`format_roundtrip_coo`、`format_roundtrip_csc`、`symmetry_consistency`、`diagonal_dominance_check`、`spadd_subtract`）的笛卡尔积。

本轮为关闭变异测试暴露的盲区，新增 6 个单元测试，测试总数从 85 增加到 91：

- `apply_ordering merges duplicate CSR coordinates`
- `rcm_ordering orders neighbors by degree then index`
- `rcm_ordering starts tied components at the lowest index`
- `rcm_ordering symmetrizes directed edges`
- `is_symmetric merges duplicate coordinates when checking mirrors`
- `is_symmetric accepts a difference exactly at relative tolerance`

## 3. 形式化验证结果

完整记录见 [`docsCONTRACTS.md`](docsCONTRACTS.md) 与 [`docs/CONTRACTS.md`](docs/CONTRACTS.md)。

| 合约 | 函数 / 证书 | 验证状态 |
| --- | --- | --- |
| C1 格式转换保真 | `csr_to_coo` | `unknown / runtime-only` |
| C2 转置维度对偶 | `transpose` | `unknown / runtime-only` |
| C3 重排序置换正确性 | `permute` | `unknown / runtime-only` |
| C4 RCM 带宽不增 | `rcm` | `unknown / runtime-only` |
| C5 对称诊断无假阳性 | `is_symmetric` | `unknown / runtime-only` |
| C6 PCG 前置/后置条件 | `pcg` | `unknown / runtime-only` |
| P1 恒等排列证书 | `proof_identity_permutation` | `proven` |
| P2 带宽非负证书 | `proof_bandwidth_nonnegative` | `proven` |
| P3 恒等重排保值证书 | `proof_apply_identity` | `proven` |
| P4 对角零带宽证书 | `proof_zero_bandwidth` | `proven` |

本地 `moon prove src/contracts_proof` 的实际输出：

```text
hp0200/moonbit-sparse-math/src/contracts_proof
  Succeeded: 4 goals proved

Summary:
  1 of 1 packages proved
  4 goals proved
```

C1-C6 的生产实现使用 `contract_assert` 检查运行时语义，但当前证明后端不能直接建模生产 CSR 的 `Array<T>`，因此不将其标记为 `proven`。

## 4. 变异测试结果

变异测试报告：

- 补强前：[`tools/mutation-report.initial.json`](tools/mutation-report.initial.json)
- 补强后：[`tools/mutation-report.json`](tools/mutation-report.json)

| 阶段 | Killed | Survived | 总数 | Mutation score |
| --- | ---: | ---: | ---: | ---: |
| 补强前 | 29 | 7 | 36 | **80.56%** |
| 补强后 | 36 | 0 | 36 | **100.00%** |

### 4.1 按算子分类

| 算子 | Killed / Total | 分数 |
| --- | ---: | ---: |
| 算术 `+ ↔ -`、`* ↔ /` | 6 / 6 | 100% |
| 关系 `== ↔ !=`、`< ↔ <=`、`> ↔ >=` | 6 / 6 | 100% |
| 边界循环 off-by-one | 6 / 6 | 100% |
| 累加 `acc += x ↔ acc = x` | 6 / 6 | 100% |
| 逻辑 `&& ↔ ||`、`!` 取反 | 6 / 6 | 100% |
| 数据 CSR/COO 行 ↔ 列 | 6 / 6 | 100% |

### 4.2 按目标文件分类

| 文件 | Killed / Total | Survived |
| --- | ---: | ---: |
| `src/ops/spgemm.mbt` | 5 / 5 | 0 |
| `src/core/csr.mbt` | 7 / 7 | 0 |
| `src/core/ordering.mbt` | 9 / 9 | 0 |
| `src/ops/basic_ops.mbt` | 5 / 5 | 0 |
| `src/algebra/diagnostics.mbt` | 4 / 4 | 0 |
| `src/core/coo.mbt` | 6 / 6 | 0 |

### 4.3 补强前 7 个 survived 的逐条结论

| ID | 位置 | 结论 | 补强动作 | 最终结果 |
| --- | --- | --- | --- | --- |
| `arith-05` | `ordering.mbt:157` | 测试盲区：缺少重复 CSR 列坐标合并时的减法检测 | 新增 `apply_ordering merges duplicate CSR coordinates` | killed |
| `rel-03` | `ordering.mbt:79` | 测试盲区：只检查带宽不增，未固定邻居度数优先的精确顺序 | 新增 `rcm_ordering orders neighbors by degree then index` | killed |
| `rel-05` | `diagnostics.mbt:77` | 测试盲区：未覆盖相对容差恰好相等的边界 | 新增 `is_symmetric accepts a difference exactly at relative tolerance` | killed |
| `rel-06` | `ordering.mbt:53` | 测试盲区：未覆盖等最小度节点的确定性起点选择 | 新增 `rcm_ordering starts tied components at the lowest index` | killed |
| `accum-03` | `ordering.mbt:157` | 测试盲区：与 `arith-05` 同一重复坐标合并路径 | 由重复 CSR 坐标合并测试覆盖 | killed |
| `accum-06` | `diagnostics.mbt:28` | 测试盲区：镜像项存在重复坐标时，未验证求和而非覆盖 | 新增 `is_symmetric merges duplicate coordinates when checking mirrors` | killed |
| `logic-03` | `ordering.mbt:19` | 非对称输入盲区：对称矩阵下邻接集不变，但 RCM 文档承诺将有向存储按无向图解释 | 新增 `rcm_ordering symmetrizes directed edges` | killed |

补强后没有 survived 变异体，因此不存在最终仍被判定为“等价变异”的条目。初始 7 条均为可观测测试盲区，并已逐条补强、重跑确认。

## 5. 验证边界与已知限制

1. **`moon prove` 的存储模型限制**：证明后端当前不能直接建模生产 CSR 的 `Array<T>`，因此 C1-C6 仍是运行时合约；4 条 `proven` 来自 `FixedArray<Int32>` 独立证书，不能等同于生产实现已被自动证明。
2. **变异测试为脚本降级方案**：MoonBit 没有原生 mutation testing 框架，`moon test --help` 也没有相应选项；本项目使用确定性的 36 条变异目录，不是任意随机变异生成器。
3. **编译失败计分口径**：`arith-02` 将泛型 `*` 改成 `/` 后因 `T` 未实现 `Div` 而构建失败，按“非零退出即 killed”计分；其余 35 个变异体均由测试失败捕获。报告保留了 `failure_kind` 字段，便于区分。
4. **变异范围有限**：只覆盖 `src/ops/spgemm.mbt`、`src/core/csr.mbt`、`src/core/coo.mbt`、`src/core/ordering.mbt`、`src/ops/basic_ops.mbt`、`src/algebra/diagnostics.mbt`；未覆盖 `src/solvers`、`src/core/io.mbt`、`src/wasm` 和测试代码本身，也未做跨包变异。
5. **性能与规模未覆盖**：未验证超大稀疏矩阵的缓存局部性、内存峰值、超长运行时间或大规模 RCM 的性能退化。
6. **并发与平台未覆盖**：当前 Harness 和变异执行是单进程确定性流程；未覆盖并发调用、线程安全、WASM 浏览器运行时差异或文件系统异常。
7. **Harness 语料有限**：small/medium 各 6 类生成矩阵、固定 seed 42；不能替代真实工业矩阵集或随机长时间性质测试。
8. **CI 已覆盖证明、Harness 与变异测试，但仍是单平台、单进程流程**：GitHub Actions 现会执行 `moon prove src/contracts_proof`、small/medium Harness 与 36 个变异体，并上传带 commit SHA 的报告 artifact；尚未覆盖其他平台矩阵、并发执行或浏览器运行时差异。
9. **全仓格式检查存在历史漂移**：仓库既有文件（如 `harness/runner/main.mbt`、`src/wasm/demo_wasm.mbt`）仍会被当前格式化器报告差异，其中包含无关的 `Int`/`Int32` 重写建议。CI 会展示漂移文件数与清单但不阻塞；清理工作由 #44 统一跟踪。

## 6. 复现命令

```powershell
# 1. 格式（本次变更）、类型与单元测试
moon fmt --check test/ordering_test.mbt test/diagnostics_test.mbt
moon check
moon test

# 2. 形式化证明（需要可用的 Z3）
$env:Z3PATH = '<path-to-z3.exe>'
moon prove src/contracts_proof

# 3. 性质测试 Harness
moon run harness/runner -- --scale=small --output=property-report-small.json
moon run harness/runner -- --scale=medium --output=property-report-medium.json

# 4. 变异测试（Linux/macOS/Git Bash）
bash tools/mutate.sh --label final --output tools/mutation-report.json

# Windows 也可直接调用 Python 入口
python tools/mutate.py --label final --output tools/mutation-report.json

# 只校验 36 个源码锚点，不执行变异
bash tools/mutate.sh --dry-run
```

CI 入口为 `.github/workflows/ci.yml`，包含 `build-and-test`、`lint`、`unit-test`、`harness`、`prove`、`mutation` 六个 job。`mutation-report.json` 与两份 `property-report-*.json` 会以包含 commit SHA 的 artifact 名称上传；31 条既有 warning 和全仓 fmt 漂移只做可见展示，清理进度以 #44 为准。

变异脚本会先运行一次基线 `moon test`，逐个注入变异体并运行完整测试，无论成功或失败都在 `finally` 路径恢复源码，然后写入包含 `{file, operator, line, original, mutated, status}` 的 JSON 报告。

## 结论

当前测试套件对 36 个核心算法变异体达到 **100% mutation score**，性质 Harness 在 small/medium 两档各 60/60 通过，单元测试 91/91 通过；形式化层有 4 条模型证书机器证明，C1-C6 生产合约仍如实保持 `unknown / runtime-only`。已知限制已在第 5 节完整列出，不以模型证明或脚本分数替代真实工程边界。
