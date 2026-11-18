# moonbit-sparse-math
[![CI](https://github.com/hp0200/moonbit-sparse-math/actions/workflows/ci.yml/badge.svg)](https://github.com/hp0200/moonbit-sparse-math/actions/workflows/ci.yml)

> 面向 WebAssembly 的稀疏线性代数库，为 Luna-Flow 数值生态补齐稀疏计算能力

## ✨ 项目简介
`moonbit-sparse-math` 是基于 MoonBit 开发的高性能稀疏矩阵库，主打 Wasm 原生场景，聚焦有限元、偏微分方程、图计算、稀疏AI算子等工程场景。
本库不重复造通用代数抽象，**作为 Luna-Flow（floating）生态的配套稀疏后端**，和现有稠密数值能力形成互补，补齐生态中缺失的稀疏矩阵运算与稀疏求解能力。

## 📦 当前已实现功能
- CSR 稀疏矩阵结构，CSR ↔ 稠密二维数组双向转换
- SpMV（稀疏矩阵-向量乘法）
- 矩阵转置
- 数值健康度评估：对角占优检测、矩阵病态评估，辅助判断迭代求解稳定性

## 🏗️ 架构规划 (Roadmap)
☑ CSR 数据结构与双向转换
☑ SpMV 运算、矩阵转置、基础数值诊断
☐ 高性能 SPA SpGEMM 稀疏矩阵乘法
☐ PCG 预条件共轭梯度稀疏求解器
☐ WebAssembly 动态内存零拷贝互通
☐ 接入 Luna Flow 泛型代数生态（支持 Int / Double）
☐ COO 稀疏存储格式支持，与 CSR 互转
☐ CSC 稀疏存储格式支持
☐ SIMD 指令级性能优化 + Benchmark

## 🧪 测试 & CI
- 单元测试全覆盖已有算子
- GitHub Actions 自动 CI，每次提交自动跑 `moon test`
- 所有数值算子附带收敛性、边界case测试

## 🚀 快速使用
```moonbit
// 示例：构造CSR稀疏矩阵，执行SpMV
let csr = CSR::from_dense(...)
let vec = [1.0, 2.0, 3.0]
let res = csr.spmv(vec)


## 🎯 定位与价值
-场景明确：面向科学计算、有限元仿真、图神经网络等重度稀疏计算场景
-Wasm原生优化：后续实现Wasm零拷贝互通，降低浏览器侧数值计算的数据拷贝开销
-生态互补：对接 Luna-Flow 泛型代数体系，复用它的抽象，避免重新设计一套代数trait
-可控工程体量：单点深耕稀疏线性代数，以算法深度取胜，而非堆砌大量无关组件


 ## 📄 License
Apache License 2.0
