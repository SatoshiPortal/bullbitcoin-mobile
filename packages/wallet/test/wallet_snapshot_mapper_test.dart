import 'package:wallet/src/data/wallet_snapshot_mapper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transaction_sync/transaction_sync.dart' as sync;
import 'package:wallet/wallet.dart';

void main() {
  test(
    'retains Bitcoin display amounts, prevouts, change and block time',
    () async {
      final time = DateTime.utc(2026, 11, 4);
      final models = await WalletSnapshotMapper.toModels(
        _snapshot([
          sync.WalletTransaction(
            txid: 'payment',
            amountSats: -200,
            displayAmountSats: 10000,
            feeSats: 200,
            displaySelfTransfer: true,
            isRbf: true,
            vsize: 141,
            position: sync.AnchoredPosition('block', 100, time),
            direction: sync.TransactionDirection.outgoing,
            inputs: const [
              sync.TransactionInput(
                txid: 'funding',
                vout: 3,
                originalIndex: 0,
                isOwn: true,
                scriptSig: '0102',
              ),
            ],
            outputs: const [
              sync.TransactionOutput(
                valueSats: 19800,
                txid: 'payment',
                vout: 1,
                originalIndex: 1,
                isOwn: true,
                script: '0103',
                standardAddress: 'change',
                chain: sync.TransactionChain.internal,
              ),
            ],
          ),
        ]),
      );
      final transaction = models.single;
      expect(transaction.amountSat, 10000);
      expect(transaction.feeSat, 200);
      expect(transaction.isToSelf, isTrue);
      expect(transaction.isIncoming, isFalse);
      expect(
        transaction.confirmationTimestamp,
        time.millisecondsSinceEpoch ~/ 1000,
      );
      expect(transaction.isRbf, isTrue);
      expect(transaction.vsize, 141);
      final input = transaction.inputs.single as BitcoinTransactionInputDetails;
      expect(input.previousTxId, 'funding');
      expect(input.previousTxVout, 3);
      expect(input.labelRef, 'payment:0');
      expect(input.scriptSig, [1, 2]);
      final output =
          transaction.outputs.single as BitcoinTransactionOutputDetails;
      expect(output.labelRef, 'payment:1');
      expect(output.value, BigInt.from(19800));
      expect(output.isChange, isTrue);
      expect(output.scriptPubkey, [1, 3]);
      expect(output.address, 'change');
    },
  );

  test(
    'retains Liquid sparse indexes and confidential address labels',
    () async {
      final time = DateTime.utc(2026);
      final models = await WalletSnapshotMapper.toModels(
        _snapshot([
          sync.WalletTransaction(
            txid: 'liquid',
            amountSats: 50,
            displayAmountSats: 75,
            feeSats: 50,
            displaySelfTransfer: true,
            isRbf: false,
            vsize: 100,
            position: sync.UnconfirmedPosition(time, time),
            direction: sync.TransactionDirection.incoming,
            inputs: const [
              sync.TransactionInput(
                txid: 'funding',
                vout: 8,
                isOwn: true,
                value: 125,
                script: 'input',
              ),
            ],
            outputs: const [
              sync.TransactionOutput(
                valueSats: 75,
                originalIndex: 4,
                isOwn: true,
                script: 'output',
                standardAddress: 'standard',
                confidentialAddress: 'confidential',
              ),
            ],
          ),
        ], liquid: true),
        toAddress: 'standard',
      );
      final transaction = models.single;
      expect(transaction.amountSat, 75);
      expect(transaction.isIncoming, isTrue);
      expect(transaction.isToSelf, isTrue);
      expect(
        transaction.confirmationTimestamp,
        time.millisecondsSinceEpoch ~/ 1000,
      );
      expect(transaction.inputs.single.labelRef, 'liquid:0');
      expect(transaction.outputs.single.labelRef, 'liquid:4');
      expect(transaction.outputs.single.address, 'confidential');
      expect(transaction.outputs.single.isChange, isFalse);
      expect(transaction.unblindedUrl, isNull);
      expect(
        await WalletSnapshotMapper.toModels(_snapshot([], liquid: true)),
        isEmpty,
      );
    },
  );

  test(
    'does not turn missing display evidence into a successful empty list',
    () async {
      await expectLater(
        WalletSnapshotMapper.toModels(
          _snapshot([
            sync.WalletTransaction(
              txid: 'unknown',
              amountSats: 0,
              position: const sync.UnknownPosition(),
            ),
          ]),
        ),
        throwsStateError,
      );
    },
  );
}

sync.WalletTransactionSnapshot _snapshot(
  List<sync.WalletTransaction> transactions, {
  bool liquid = false,
}) => sync.WalletTransactionSnapshot(
  key: sync.WalletNetworkKey(
    'wallet',
    liquid ? 'liquid' : 'bitcoin',
    'testnet',
  ),
  revision: 1,
  contentFingerprint: 'fixture',
  transactions: transactions,
  observedAt: DateTime.utc(2026),
  lastSuccessfulSyncAt: null,
  sourceKind: liquid ? 'lwk_electrum' : 'bdk_electrum',
  capabilities: const {},
  sourceTip: null,
  complete: true,
  evidenceLevel: sync.WalletEvidenceLevel.localSourceState,
);
