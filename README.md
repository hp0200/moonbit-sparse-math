[![MoonBit CI](https://github.com/hp0200/moonbit-sparse-math/actions/workflows/ci.yml/badge.svg)](https://github.com/hp0200/moonbit-sparse-math/actions/workflows/ci.yml)



# moonbit-sparse-math
面向 WebAssembly 的 MoonBit 稀疏矩阵计算基础库，当前为早期基线版本。

## 当前功能
- CSR 稀疏矩阵存储格式
- 稠密矩阵与 CSR 格式互相转换
- 基础 SpMV 矩阵向量乘法
- 基础单元测试

## 快速开始
```bash
moon build
moon test
```

## 迭代规划
参赛周期内将持续迭代，补充更多稀疏格式、性能优化、求解器与 Web 演示，完善 MoonBit 科学计算生态。

## License
MIT
