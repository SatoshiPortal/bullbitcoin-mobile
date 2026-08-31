import 'package:bull_swap/src/data/bull/order_swap_amount_codec.dart';
import 'package:test/test.dart';

void main() {
  test(
    'converts decimal bitcoin amounts without floating-point arithmetic',
    () {
      expect(orderSwapAmountToSats('0.00000001'), BigInt.one);
      expect(orderSwapAmountToSats('0.00101'), BigInt.from(101000));
      expect(orderSwapSatsToAmount(BigInt.from(101000)), '0.00101');
    },
  );

  test('rejects amounts with more than eight decimals', () {
    expect(
      () => orderSwapAmountToSats('0.000000001'),
      throwsA(isA<FormatException>()),
    );
  });
}
