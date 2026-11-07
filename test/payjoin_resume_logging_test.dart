import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:bb_mobile/payjoin_runtime_adapters.dart';
import 'package:bull_logger/bull_logger.dart' as support;
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:bull_payjoin/src/data/local_payjoin_datasource.dart';
import 'package:bull_payjoin/src/data/payjoin_database.dart';
import 'package:bull_payjoin/src/data/payjoin_model.dart';
import 'package:bull_payjoin/src/data/payjoin_policy_store.dart';
import 'package:bull_payjoin/src/engine/payjoin_engine.dart';
import 'package:bull_payjoin/src/engine/payjoin_logger.dart';
import 'package:bull_payjoin/src/engine/pdk_payjoin_datasource.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockPdkPayjoinDatasource extends Mock implements PdkPayjoinDatasource {}

class _MockWalletPort extends Mock implements PayjoinWalletPort {}

class _MockBlockchainPort extends Mock implements PayjoinBlockchainPort {}

class _MockTransactionPort extends Mock implements PayjoinTransactionPort {}

class _MockLabelsPort extends Mock implements PayjoinLabelsPort {}

void main() {
  for (final withFallback in [true, false]) {
    test('proposal resume cardinality with fallback=$withFallback', () async {
      final database = PayjoinDatabase.forTesting(NativeDatabase.memory());
      final local = LocalPayjoinDatasource(db: database);
      final policy = PayjoinPolicyStore(database);
      await database
          .into(database.payjoinPolicies)
          .insert(
            const PayjoinPolicyRow(
              id: 1,
              receiveEnabled: true,
              sendEnabled: true,
              buyEnabled: true,
              sellEnabled: true,
              minimumAmountSat: 10000,
              sessionLifetimeSeconds: 86400,
            ),
          );
      final pdk = _MockPdkPayjoinDatasource();
      when(() => pdk.isPolling(any())).thenReturn(false);
      final blockchain = _MockBlockchainPort();
      final transactions = _MockTransactionPort();
      final labels = _MockLabelsPort();
      final wallet = _MockWalletPort();
      final requests = StreamController<PayjoinReceiverModel>.broadcast();
      when(() => pdk.requestsForReceivers).thenAnswer((_) => requests.stream);
      when(
        () => pdk.proposalsForSenders,
      ).thenAnswer((_) => const Stream.empty());
      when(() => pdk.expiredPayjoins).thenAnswer((_) => const Stream.empty());
      when(() => pdk.dispose()).thenAnswer((_) async {});
      when(() => pdk.stopPolling(any())).thenReturn(null);
      when(
        () => transactions.watchWallet(any()),
      ).thenAnswer((_) => const Stream.empty());
      when(
        () => transactions.isTransactionVisible(
          walletId: any(named: 'walletId'),
          transactionId: any(named: 'transactionId'),
          refresh: any(named: 'refresh'),
        ),
      ).thenAnswer((_) async => false);
      when(() => transactions.refreshWallet(any())).thenAnswer((_) async {});
      var engine = PayjoinRepositoryImpl(
        localPayjoinDatasource: local,
        pdkPayjoinDatasource: pdk,
        log: const PayjoinLogger(AppPayjoinLogAdapter()),
        wallet: wallet,
        blockchain: blockchain,
        transactions: transactions,
        policy: policy,
        labels: labels,
      );
      final model =
          PayjoinModel.receiver(
                id: 'receiver-1',
                address: 'tb1qreceiver',
                isTestnet: true,
                receiver: '[]',
                walletId: 'wallet-1',
                pjUri: 'bitcoin:tb1qreceiver?pj=https://payjo.in/receiver-1',
                maxFeeRateSatPerVb: BigInt.from(10000),
                createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
                expireAfterSec: 3600,
                amountSat: 50000,
                originalTxBytes: Uint8List.fromList([1]),
                originalTxId: withFallback ? 'original-tx' : null,
                proposalPsbt: 'proposal',
                txId: 'payjoin-tx',
              )
              as PayjoinReceiverModel;
      await local.storeReceiver(model);
      final dir = await Directory.systemTemp.createTemp('payjoin-resume-');
      support.log = support.Logger.replace(directory: dir);
      Future<int> resumeCount() async => (await support.log.readLogs())
          .where((row) => row.split('\t')[2].contains('sessionResumed:'))
          .length;
      try {
        await engine.resumePayjoinsOnStartup();
        await engine.resumePayjoinsOnStartup();
        await engine.resumePayjoinsOnStartup();
        verify(
          () => transactions.watchWallet('wallet-1'),
        ).called(withFallback ? 2 : 1);
        expect(await resumeCount(), 1);
        // A new engine has no active work and must persist a real restart.
        await engine.dispose();
        engine = PayjoinRepositoryImpl(
          localPayjoinDatasource: local,
          pdkPayjoinDatasource: pdk,
          log: const PayjoinLogger(AppPayjoinLogAdapter()),
          wallet: wallet,
          blockchain: blockchain,
          transactions: transactions,
          policy: policy,
          labels: labels,
        );
        await engine.resumePayjoinsOnStartup();
        verify(
          () => transactions.watchWallet('wallet-1'),
        ).called(withFallback ? 2 : 1);
        expect(await resumeCount(), 2);
      } finally {
        await engine.dispose();
        await requests.close();
        await database.close();
        await support.log.flush();
        await dir.delete(recursive: true);
      }
    });
  }
}
