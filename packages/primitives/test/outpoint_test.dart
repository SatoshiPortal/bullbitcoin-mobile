import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

void main() {
  test('Outpoint has structural equality', () {
    const first = (txId: 'transaction', vout: 1);
    const second = (txId: 'transaction', vout: 1);
    const different = (txId: 'transaction', vout: 2);

    final outpoints = <Outpoint>{first};
    outpoints.add(second);

    expect(outpoints, hasLength(1));
    expect(first, isNot(different));
  });
}
