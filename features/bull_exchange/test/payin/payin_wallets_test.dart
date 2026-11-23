import 'package:bull_exchange/src/payin/payin_wallets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart';

void main() {
  test('closing before the address loads returns a typed failure', () async {
    final result = await readPayinAddress(
      Stream.value(const WalletAddressAt.notLoaded()),
    );

    expect(
      result,
      isA<Err<String, SyncFailure>>().having(
        (result) => result.failure,
        'failure',
        isA<SyncClosedFailure>(),
      ),
    );
  });

  test('an error event keeps the typed Sync failure', () async {
    const failure = SyncBusyFailure();
    final result = await readPayinAddress(Stream.error(failure));

    expect(
      result,
      isA<Err<String, SyncFailure>>().having(
        (result) => result.failure,
        'failure',
        same(failure),
      ),
    );
  });

  test('a foreign error event becomes a storage failure', () async {
    final result = await readPayinAddress(Stream.error(StateError('foreign')));

    expect(
      result,
      isA<Err<String, SyncFailure>>().having(
        (result) => result.failure,
        'failure',
        isA<SyncStorageFailure>(),
      ),
    );
  });
}
