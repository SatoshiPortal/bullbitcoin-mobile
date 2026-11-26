/// Bounds check for values crossing the bridge as an unsigned 64-bit integer.
///
/// flutter_rust_bridge encodes `u64` and `usize` with `toSigned(64).toInt()`,
/// which wraps modulo 2^64 instead of failing. A Dart `BigInt` amount above
/// `u64::MAX` therefore arrived in Rust as an unrelated, smaller number, and a
/// negative one as a very large positive value — before any Rust-side check
/// could see it. Every satoshi amount in this SDK crosses that boundary.
BigInt checkedU64(BigInt value) {
  if (value.isNegative || value.bitLength > 64) {
    throw RangeError('value must fit in an unsigned 64-bit integer: $value');
  }
  return value;
}

int checkedU64ToNativeInt(BigInt value) =>
    checkedU64(value).toSigned(64).toInt();
