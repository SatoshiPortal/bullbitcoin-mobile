import 'package:test/test.dart';
import 'package:wallet_transaction_sync/wallet_transaction_sync.dart';

void main() {
  test('published transactions deeply copy mutable input maps and lists', () {
    final nested = <String, Object?>{
      'value': <Object?>['before'],
    };
    final transaction = WalletTransaction(
      txid: 'tx',
      amountSats: 1,
      position: const UnknownPosition(),
      details: nested,
    );
    nested['value'] = <Object?>['after'];

    expect((transaction.details['value'] as List).single, 'before');
    expect(
      () => (transaction.details as Map)['new'] = true,
      throwsUnsupportedError,
    );
  });

  test('pages and snapshots do not expose mutable collections', () {
    final transactions = <WalletTransaction>[];
    final capabilities = <String>{'local'};
    final snapshot = WalletTransactionSnapshot(
      key: const WalletNetworkKey('w', 'bitcoin', 'testnet'),
      revision: 1,
      contentFingerprint: 'fingerprint',
      transactions: transactions,
      observedAt: DateTime(2020),
      lastSuccessfulSyncAt: null,
      sourceKind: 'fake',
      capabilities: capabilities,
      sourceTip: null,
      complete: true,
      evidenceLevel: WalletEvidenceLevel.localSourceState,
    );
    transactions.add(
      WalletTransaction(
        txid: 'late',
        amountSats: 2,
        position: const UnknownPosition(),
      ),
    );
    capabilities.add('network');

    expect(snapshot.transactions, isEmpty);
    expect(snapshot.capabilities, {'local'});
  });
}
