import 'package:primitives/primitives.dart' as primitive;
import 'package:test/test.dart';
import 'package:transaction_sync/transaction_sync.dart' as sync;

void main() {
  test('the compatibility export retains the canonical primitive identity', () {
    final primitive.BitcoinSyncSource source =
        sync.BitcoinSyncSource.compactBlockFilters;
    expect(
      identical(source, primitive.BitcoinSyncSource.compactBlockFilters),
      isTrue,
    );
    expect(source.name, 'compactBlockFilters');
    expect(sync.BitcoinSyncSource.electrum.name, 'electrum');
  });
}
