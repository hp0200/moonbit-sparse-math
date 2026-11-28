# moonbit-sparse-math
[![CI](https://github.com/hp0200/moonbit-sparse-math/actions/workflows/ci.yml/badge.svg)](https://github.com/hp0200/moonbit-sparse-math/actions/workflows/ci.yml)
[![mooncakes](https://img.shields.io/badge/mooncakes-v0.4.0-green)](https://mooncakes.io/docs/#/hp0200/moonbit-sparse-math)

🌐 [在线体验：5000 节点星云交互演示](https://hp0200.github.io/moonbit-sparse-math/examples/showcase.html)

> 面向 WebAssembly 的稀疏线性代数库，为 Luna-Flow 数值生态补齐稀疏计算能力

## ✨ 项目简介
`moonbit-sparse-math` 是基于 MoonBit 开发的高性能稀疏矩阵库，主打 Wasm 原生场景，聚焦有限元、偏微分方程、图计算、稀疏AI算子等工程场景。
本库不重复造通用代数抽象，**作为 Luna-Flow（floating）生态的配套稀疏后端**，和现有稠密数值能力形成互补，补齐生态中缺失的稀疏矩阵运算与稀疏求解能力。

## 📁 项目结构
- `src/core/`：CSR、CSC、COO 稀疏矩阵结构与基础运算
- `src/ops/`：稀疏矩阵乘法等代数运算
- `src/solvers/`：共轭梯度与预条件共轭梯度求解器
- `src/algebra/`：格式转换与数值诊断工具
- `src/wasm/`：WebAssembly 零拷贝接口
- `test/`：跨包集成与回归测试

## 📦 当前已实现功能
- CSR 稀疏矩阵结构，CSR ↔ 稠密二维数组双向转换
- SpMV（稀疏矩阵-向量乘法）
- 矩阵转置
- 数值健康度评估：对角占优检测、矩阵病态评估，辅助判断迭代求解稳定性

## 🏗️ 架构规划 (Roadmap)
- [x] CSR 数据结构与双向转换
- [x] CSC 数据结构与双向转换
- [x] COO 数据结构与双向转换
- [x] SpMV 运算、矩阵转置、基础数值诊断
- [x] 高性能 SPA SpGEMM 稀疏矩阵乘法
- [x] PCG 预条件共轭梯度稀疏求解器 (支持泛型)
- [x] WebAssembly 动态内存零拷贝互通
- [x] 接入 Luna-Flow 泛型代数生态 (支持 Int / Double / Float)
- [x] SIMD 指令级性能优化 + 真实 Benchmark 跑分
- [x] Matrix Market (`.mtx`) 稀疏矩阵文件读写
- [x] 结构诊断：对称性、正定性、连通分量
- [x] RCM (Reverse Cuthill-McKee) 矩阵重排序
- [x] 基础稀疏算子：加减、缩放、Hadamard 积、对角缩放、行切片
- [x] 稀疏矩阵与图邻接表双向互转
- [x] `Complex` 复数类型及泛型 SpMV 支持
- [ ] GMRES 广义最小残差法求解器 (用于非对称矩阵)
- [ ] 基于 BSR 分块格式的 GPU / SIMD 深度优化
- [ ] 端侧医疗图像卷积与处理示例
## 🚀 性能基准测试 (Benchmark)

测试环境：MoonBit (wasm-gc), 1000x1000 矩阵, 1% 稀疏度。

| 算法实现 | 平均耗时 (Mean) | 性能对比 |
| :--- | :--- | :--- |
| `matmul_map` (泛型哈希表累加) | 5.47 ms | 基准线 |
| `matmul_spa` (泛型稀疏累加器) | **3.06 ms** | **快 1.78 倍** |
| `spmv_scalar` (标量循环遍历) | 27.20 µs | 基准线 |
| `spmv_simd` (V128 向量化指令) | **22.60 µs** | **快 17%** |

> **结论**：
> 1. SPA 算法通过定长数组和 `touched` 标记，彻底避免了动态内存分配（Zero-allocation），在矩阵乘法中实现了显著的性能提升。
> 2. 针对 CSR 格式的连续内存访问特点，我们引入了 V128 SIMD 指令，通过双 `f64x2` 累加器并行计算，在保持零分配的同时进一步压榨了硬件性能。

## 🧪 测试 & CI

当前验证基线：**91/91 单元测试**、Harness small/medium 各 **60/60**、**4 goals proved**、变异测试 **36/36 killed（100%）**。

### CI 流水线

| Job | 职责 | 阻塞条件 |
| :--- | :--- | :--- |
| `build-and-test` | 保留原有构建与测试行为 | `moon check` / `moon test` 失败 |
| `lint` | 检查变更 MoonBit 文件格式，打印全仓 fmt 漂移与 warning 计数 | 变更文件格式错误、`moon check` 出现 error |
| `unit-test` | 运行完整单元测试并校验 91/91 | 测试失败或数量不符 |
| `harness` | 运行 small/medium 性质测试并校验 JSON 报告 | 退出码非 0、字段缺失或存在失败用例 |
| `prove` | 安装 Z3 后运行 `moon prove src/contracts_proof` | 少于 4 goals proved |
| `mutation` | 真实执行 36 个源码变异体并校验报告 | score 不是 1.0 或 survived 不为 0 |

CI 使用 `actions/cache@v4` 缓存 MoonBit registry 与 `_build`，cache key 包含 OS、MoonBit 版本和 `hashFiles`。变异报告与性质测试报告会作为带 commit SHA 的 artifact 上传，便于直接下载核对。

> `moon check` 的 31 条既有 warning 与全仓 fmt 漂移在 CI 中**可见但不阻塞**，统一由 #44 跟踪。

### 本地复现

```bash
moon check --no-mbti
moon test
moon run harness/runner -- --scale=small --output=property-report-small.json
moon run harness/runner -- --scale=medium --output=property-report-medium.json
moon prove src/contracts_proof
python3 tools/mutate.py --label ci --output tools/mutation-report.json
```

## 🚀 快速使用
```moonbit
// 示例：构造CSR稀疏矩阵，执行SpMV
let csr = CSR::from_dense(...)
let vec = [1.0, 2.0, 3.0]
let res = csr.spmv(vec)

``` 
## 🎯 定位与价值
- 场景明确：面向科学计算、有限元仿真、图神经网络等重度稀疏计算场景
- Wasm原生优化：后续实现Wasm零拷贝互通，降低浏览器侧数值计算的数据拷贝开销
- 生态互补：对接 Luna-Flow 泛型代数体系，复用它的抽象，避免重新设计一套代数trait
- 可控工程体量：单点深耕稀疏线性代数，以算法深度取胜，而非堆砌大量无关组件

## 📄 License
Apache License 2.0


