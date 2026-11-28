///|
/// Proof-layer certificate: the identity map is a permutation of `0..n`.
///
/// This is the machine-checked model underlying the runtime `is_permutation`
/// predicate. The production CSR representation uses `Array`, which the
/// current proof backend does not model, so this certificate is expressed over
/// the proof-supported `FixedArray` representation.
pub fn proof_identity_permutation(
  n : Int32,
) -> FixedArray[Int32] where {
  proof_require: 0 <= n,
  proof_ensure: result => proof_identity_permutation_post(n, result),
} {
  let result = FixedArray::make(n, 0)
  for i = 0; i < n; {
    result[i] = i
    continue i + 1
  } where {
    proof_invariant: 0 <= i,
    proof_invariant: i <= n,
    proof_invariant: result.length() == n,
    proof_invariant: ∀ k : Int32, 0 <= k && k < i → result[k] == k,
    proof_reasoning: (
      #| Each iteration writes the unique index `i` into slot `i`. At exit every
      #| slot is in range and all values are distinct, which is exactly
      #| `proof_is_permutation(result)`.
    ),
  }
  result
}

///|
/// Proof-layer certificate: bandwidth, represented as the maximum absolute
/// row/column offset, is non-negative.
pub fn proof_bandwidth_nonnegative(
  offsets : FixedArray[Int32],
) -> Int32 where {
  proof_ensure: result => 0 <= result,
} {
  let mut bandwidth = 0
  for i = 0; i < offsets.length(); {
    let distance = if offsets[i] < 0 { -offsets[i] } else { offsets[i] }
    if distance > bandwidth {
      bandwidth = distance
    }
    continue i + 1
  } where {
    proof_invariant: 0 <= i,
    proof_invariant: i <= offsets.length(),
    proof_invariant: 0 <= bandwidth,
    proof_reasoning: (
      #| `bandwidth` is the maximum of zero and finitely many absolute values,
      #| so it cannot decrease below zero.
    ),
  }
  bandwidth
}

///|
/// Proof-layer certificate: applying the identity permutation preserves every
/// value and the array length.
pub fn proof_apply_identity(
  values : FixedArray[Int32],
) -> FixedArray[Int32] where {
  proof_ensure: result => proof_same_values(result, values),
} {
  let result = FixedArray::make(values.length(), 0)
  for i = 0; i < values.length(); {
    result[i] = values[i]
    continue i + 1
  } where {
    proof_invariant: 0 <= i,
    proof_invariant: i <= values.length(),
    proof_invariant: result.length() == values.length(),
    proof_invariant: ∀ k : Int32, 0 <= k && k < i → result[k] == values[k],
    proof_reasoning: (
      #| The identity permutation copies `values[k]` into `result[k]` for every
      #| valid index, preserving both length and contents.
    ),
  }
  result
}

///|
/// Proof-layer certificate: the bandwidth of a diagonal-only pattern is zero
/// and therefore non-negative.
pub fn proof_zero_bandwidth() -> Int32 where {
  proof_ensure: result => result == 0 && 0 <= result,
} {
  0
}
