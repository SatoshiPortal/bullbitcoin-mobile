import 'package:bull_sdk/src/checked_u64.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('checkedU64 accepts the complete u64 range', () {
    expect(checkedU64(BigInt.zero), BigInt.zero);
    expect(
      checkedU64((BigInt.one << 64) - BigInt.one),
      (BigInt.one << 64) - BigInt.one,
    );
  });

  test('checkedU64 rejects values that would wrap modulo 2^64', () {
    expect(() => checkedU64(-BigInt.one), throwsRangeError);
    expect(() => checkedU64(BigInt.one << 64), throwsRangeError);
  });
}
