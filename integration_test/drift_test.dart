import 'package:bb_mobile/core/transaction/data/drift_datasource.dart';
import 'package:bb_mobile/core/transaction/data/electrum_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final driftDatasource = DriftDatasource();

  setUpAll(() {});

  tearDownAll(() {});
  group('Label Storage Integration Tests', () {
    test('Create and store multiple labels', () async {
      const txidCoinbase =
          'ff47a0a1dfdcf68327242d2cbfb229a5ba7e3e67572c2d4f390c51b1a89d56e5';
      final electrum =
          ElectrumService(host: 'wes.bullbitcoin.com', port: 50002);

      final tx = await electrum.getTransaction(txidCoinbase);
      driftDatasource.storeTransaction(tx);

      final fetched = await driftDatasource.fetchTransaction(txidCoinbase);
      expect(fetched, isNotNull);
      expect(fetched!.txid, txidCoinbase);
    });
  });
}
