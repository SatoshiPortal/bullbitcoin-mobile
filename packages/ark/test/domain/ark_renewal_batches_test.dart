import 'package:ark/ark.dart';
import 'package:ark/src/domain/ark_renewal_batches.dart';
import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

void main() {
  ArkVtxo v(String id, int amount) => ArkVtxo(
    id: id,
    amount: Sats.fromInt(amount),
    expiryHeight: 500,
    state: ArkVtxoState.spendable,
  );
  test('server cap partitions inputs without duplication or oversize', () {
    final inputs = [v('a', 60), v('b', 50), v('c', 40)];
    final result = partitionArkRenewalBatches(inputs, Sats.fromInt(100));
    final batches = (result as Ok<List<List<ArkVtxo>>, ArkWalletFailure>).value;
    expect(batches.length, 2);
    expect(batches.expand((b) => b).map((v) => v.id).toSet(), {'a', 'b', 'c'});
    expect(
      batches.every(
        (batch) =>
            batch.fold<int>(0, (sum, v) => sum + v.amount.value.toInt()) <= 100,
      ),
      isTrue,
    );
  });
  test('unknown cap uses singletons; oversized input is refused', () {
    final inputs = [v('a', 60), v('b', 50)];
    final result = partitionArkRenewalBatches(inputs, null);
    expect(
      (result as Ok<List<List<ArkVtxo>>, ArkWalletFailure>).value.every(
        (batch) => batch.length == 1,
      ),
      isTrue,
    );
    expect(partitionArkRenewalBatches(inputs, Sats.fromInt(59)), isA<Err>());
  });
}
