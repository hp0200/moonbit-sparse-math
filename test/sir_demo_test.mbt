///|
test "SIR epidemic model simulation" {
  // SIR 模型：易感者(S) - 感染者(I) - 康复者(R)
  // 假设 4 个人群的接触网络矩阵
  let contact_matrix = [
    [0.8, 0.2, 0.0, 0.0],
    [0.1, 0.7, 0.2, 0.0],
    [0.0, 0.2, 0.8, 0.1],
    [0.0, 0.0, 0.1, 0.9],
  ]

  let csr = @core.from_dense(contact_matrix, 0.0)

  // 初始感染人数比例：只有第 0 个人感染
  let infected : Array[Double] = [1.0, 0.0, 0.0, 0.0]

  println("=== 医院病区 SIR 传播模拟 ===")
  println("初始感染分布: \{infected}")

  // 模拟 5 天
  for day = 1; day <= 5; day = day + 1 {
    // 注意：这里要用 match 解包 Result
    match @core.spmv(csr, infected) {
      Ok(next_day) =>
        for i = 0; i < 4; i = i + 1 {
          infected[i] = next_day[i]
        }
      Err(_) => println("维度错误！")
    }
    println("第 \{day} 天模拟完成")
  }
}
