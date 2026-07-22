import 'package:bb_mobile/core/wallet/data/datasources/liquid_receive_address_index_datasource.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late LiquidReceiveAddressIndexDatasource datasource;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    datasource = LiquidReceiveAddressIndexDatasource();
  });

  group('read', () {
    test('returns null when nothing has ever been reserved', () async {
      expect(await datasource.read('wallet-1'), isNull);
    });
  });

  group('reserveNext', () {
    test('starts at atLeast + 1 on a fresh wallet', () async {
      final index = await datasource.reserveNext('wallet-1', atLeast: 5);

      expect(index, 6);
      expect(await datasource.read('wallet-1'), 6);
    });

    test('advances past the previously persisted index', () async {
      await datasource.reserveNext('wallet-1', atLeast: 5); // -> 6

      final second = await datasource.reserveNext('wallet-1', atLeast: 0);

      expect(second, 7); // max(persisted=6, atLeast=0) + 1
    });

    test('self-heals to atLeast when it exceeds the persisted index', () async {
      await datasource.reserveNext('wallet-1', atLeast: 2); // -> 3

      // Simulates LWK's sync catching up past what was locally persisted
      // (e.g. a wallet restored on a new device).
      final next = await datasource.reserveNext('wallet-1', atLeast: 100);

      expect(next, 101);
    });

    test(
      'two concurrent reservations for the same wallet never collide',
      () async {
        // This is the exact race the datasource exists to close: without
        // serialization, both calls could read the same "current" value
        // before either writes back, returning the same index twice.
        final results = await Future.wait([
          datasource.reserveNext('wallet-1', atLeast: 0),
          datasource.reserveNext('wallet-1', atLeast: 0),
        ]);

        expect(results.toSet(), hasLength(2)); // no duplicate
        expect(results..sort(), [1, 2]);
      },
    );

    test('different wallets reserve independently', () async {
      final walletA = await datasource.reserveNext('wallet-a', atLeast: 0);
      final walletB = await datasource.reserveNext('wallet-b', atLeast: 0);

      expect(walletA, 1);
      expect(walletB, 1); // not affected by wallet-a's reservation
    });
  });

  group('ensureAtLeast', () {
    test('bumps the persisted index up when behind', () async {
      await datasource.reserveNext('wallet-1', atLeast: 0); // -> 1

      await datasource.ensureAtLeast('wallet-1', 10);

      expect(await datasource.read('wallet-1'), 10);
    });

    test('never moves the persisted index backwards', () async {
      await datasource.reserveNext('wallet-1', atLeast: 10); // -> 11

      await datasource.ensureAtLeast('wallet-1', 3);

      expect(await datasource.read('wallet-1'), 11);
    });
  });
}
