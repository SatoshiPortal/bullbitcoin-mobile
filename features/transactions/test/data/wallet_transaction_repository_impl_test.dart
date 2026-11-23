import 'package:flutter_test/flutter_test.dart';
import 'package:labels/labels.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';
import 'package:sync/sync.dart' show WalletKey;
import 'package:transactions/src/data/models/transaction_input_model.dart';
import 'package:transactions/src/data/models/wallet_transaction_model.dart';
import 'package:transactions/src/data/wallet_history_datasource.dart';
import 'package:transactions/src/data/wallet_transaction_repository_impl.dart';

class _MockInventory extends Mock implements WalletInventory {}

class _MockLabels extends Mock implements Labels {}

class _MockHistory extends Mock implements WalletHistoryDatasource {}

void main() {
  setUpAll(() {
    registerFallbackValue(
      WalletKey(id: 'fallback', network: BitcoinNetwork.regtest),
    );
  });

  test('a transaction with inputs maps into the wallet history', () async {
    final inventory = _MockInventory();
    final labels = _MockLabels();
    final history = _MockHistory();
    when(() => inventory.readWallet('w1')).thenAnswer(
      (_) async => Ok(
        walletRegistrationForTesting(id: 'w1', network: BitcoinNetwork.regtest),
      ),
    );
    when(() => labels.fetch(reference: any(named: 'reference')))
        .thenAnswer((_) async => const Ok(<Label>[]));
    when(
      () => history.getTransactions(
        key: any(named: 'key'),
        toAddress: any(named: 'toAddress'),
      ),
    ).thenAnswer(
      (_) async => const Ok([
        WalletTransactionModel(
          txId: 'tx',
          isIncoming: true,
          amountSat: 250000,
          feeSat: 0,
          vsize: 141,
          inputs: [
            TransactionInputModel.bitcoin(
              txId: 'tx',
              vin: 0,
              isOwn: false,
              previousTxId: 'prev',
              previousTxVout: 0,
            ),
          ],
          outputs: [],
          network: BitcoinNetwork.regtest,
          isRbf: false,
        ),
      ]),
    );
    final repository = WalletTransactionRepositoryImpl(
      inventory: inventory,
      labelsFacade: labels,
      history: history,
      synchronize: (_) async => const Ok(null),
    );

    final result = await repository.getWalletTransactions(walletId: 'w1');

    switch (result) {
      case Ok(:final value):
        expect(value, hasLength(1));
        expect(value.single.inputs, hasLength(1));
      case Err(:final failure):
        fail('history failed: $failure');
    }
  });
}
