import 'package:bb_mobile/features/send/domain/lnurl_pay_limits.dart';
import 'package:test/test.dart';

void main() {
  LnurlPayLimits? limits(int minimum, int maximum) =>
      LnurlPayLimits.fromMillisatoshis(
        BigInt.from(minimum),
        BigInt.from(maximum),
      );

  test('rounds to complete sats without widening the bounds', () {
    final range = limits(1001, 4999);

    expect(range?.minimumSat, 2);
    expect(range?.maximumSat, 4);
    expect(range?.fixedAmountSat, isNull);
    expect(range?.includes(1), isFalse);
    expect(range?.includes(2), isTrue);
    expect(range?.includes(4), isTrue);
    expect(range?.includes(5), isFalse);
  });

  test('identifies the only whole-sat amount even when msat bounds differ', () {
    expect(limits(5000000, 5000000)?.fixedAmountSat, 5000);
    expect(limits(4999999, 5000001)?.fixedAmountSat, 5000);
  });

  test('rejects non-positive, inverted and unpayable ranges', () {
    expect(limits(0, 5000), isNull);
    expect(limits(3000, 2000), isNull);
    expect(limits(1001, 1999), isNull);
  });
}
