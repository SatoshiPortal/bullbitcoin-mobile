import 'initialization_result.dart';

import 'package:electrum/testing.dart';
import 'package:electrum/electrum.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/init.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

Future<void> main({bool isInitialized = false}) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  if (!isInitialized) {
    requireSuccessfulBullInitialization(await Bull.init());
  }

  final electrum = locator<Electrum>();

  const txid =
      'ff47a0a1dfdcf68327242d2cbfb229a5ba7e3e67572c2d4f390c51b1a89d56e5';

  setUp(() async => await clearElectrumCacheForTesting(electrum));

  tearDownAll(() {});
  group('Electrum cache integration tests', () {
    test('Ensure the repository works', () async {
      // Ensure the tx does not exists in the owner cache
      expect(
        await hasCachedElectrumTransactionForTesting(electrum, txid),
        isFalse,
      );

      // Fetch a transaction and cache it in the owner cache if not present
      final result = await electrum.transactions.fetch(
        txid,
        network: BitcoinNetwork.mainnet,
      );
      expect(result, isA<Ok>());
      expect(result.fold((tx) => tx.txid, (_) => null), txid);

      // Ensure the tx is now stored in the owner cache
      expect(
        await hasCachedElectrumTransactionForTesting(electrum, txid),
        isTrue,
      );
    });
  });
}
