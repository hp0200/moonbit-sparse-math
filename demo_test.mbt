///|
test "medical demo" {
  println("=========== 医疗稀疏矩阵演示 ===========")

  let hospital_data : Array[Array[Double]] = [
    [5.0, 1.0, 0.0, 0.0],
    [1.0, 6.0, 2.0, 0.0],
    [0.0, 2.0, 7.0, 1.0],
    [0.0, 0.0, 1.0, 8.0],
  ]
  println("1. 原始数据已输入 (4x4矩阵)")

  let csr = from_dense(hospital_data, 0.0)
  println("2. 数据已极限压缩为 CSR 格式！")
  println("提取出的非零数值: \{csr.values}")
  println("对应的列索引: \{csr.col_indices}")

  let health = estimate_conditioning(csr)
  println("3. 智能诊断结果: \{health}")

  let current_patients : Array[Double] = [10.0, 20.0, 30.0, 40.0]
  let next_day = spmv(csr, current_patients).unwrap()
  println("4. 今天的各病区人数: \{current_patients}")
  println("   第二天的预测人数: \{next_day}")
  println("========================================")
}
