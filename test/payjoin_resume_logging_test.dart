import 'dart:io';
import 'dart:typed_data';

import 'package:bb_mobile/payjoin_runtime_adapters.dart';
import 'package:bull_logger/bull_logger.dart' as support;
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _Wallet extends Mock implements PayjoinWalletPort {}

class _Blockchain extends Mock implements PayjoinBlockchainPort {}

class _Transactions extends Mock implements PayjoinTransactionPort {}

class _Labels extends Mock implements PayjoinLabelsPort {}

class _Fees extends Mock implements PayjoinFeesPort {}

class _LegacyData extends Mock implements PayjoinLegacyDataPort {}

void main() {
  for (final withFallback in [true, false]) {
    test('proposal resume cardinality with fallback=$withFallback', () async {
      final dir = await Directory.systemTemp.createTemp('payjoin-resume-');
      support.log = support.Logger.replace(directory: dir);
      final legacy = _LegacyData();
      when(legacy.readSnapshot).thenAnswer(
        (_) async => PayjoinLegacySnapshot(
          sourceSchemaVersion: 13,
          senders: const [],
          receivers: [
            PayjoinLegacyReceiver(
              id: 'receiver-1',
              address: 'tb1qreceiver',
              isTestnet: true,
              protocolState: '[]',
              walletId: 'wallet-1',
              payjoinUri: 'bitcoin:tb1qreceiver?pj=https://payjo.in/receiver-1',
              maximumFeeRateSatPerVbyte: BigInt.from(10000),
              createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
              expireAfterSec: 3600,
              amountSat: 50000,
              originalTransaction: Uint8List.fromList([1]),
              originalTransactionId: withFallback ? 'original-tx' : null,
              proposalPsbt: 'proposal',
              transactionId: 'payjoin-tx',
              isExpired: false,
              isCompleted: false,
            ),
          ],
        ),
      );
      final transactions = _Transactions();
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
      Future<PayjoinLifecycle> open() async {
        final result = await openPayjoin(
          databasePath: '${dir.path}/payjoin.sqlite',
          databaseKey: DatabaseKey.fromHex('42' * 32),
          wallet: _Wallet(),
          blockchain: _Blockchain(),
          fees: _Fees(),
          transactions: transactions,
          labels: _Labels(),
          legacyData: legacy,
          log: const AppPayjoinLogAdapter(),
        );
        return switch (result) {
          Ok(:final value) => value,
          Err(:final failure) => throw TestFailure('Open failed: $failure'),
        };
      }

      Future<int> resumeCount() async => (await support.log.readLogs())
          .where((row) => row.split('\t')[2].contains('sessionResumed:'))
          .length;
      var runtime = await open();
      try {
        expect(
          await runtime.payjoin.policy.setActionEnabled(
            PayjoinAction.receive,
            enabled: true,
          ),
          isA<Ok<PayjoinPolicy, PayjoinFailure>>(),
        );
        for (var i = 0; i < 3; i++) {
          expect(await runtime.resume(), isA<Ok<void, PayjoinFailure>>());
        }
        verify(
          () => transactions.watchWallet('wallet-1'),
        ).called(withFallback ? 2 : 1);
        expect(await resumeCount(), 1);
        // Reopening the same persisted session is a real lifecycle restart.
        await runtime.dispose();
        runtime = await open();
        expect(await runtime.resume(), isA<Ok<void, PayjoinFailure>>());
        verify(
          () => transactions.watchWallet('wallet-1'),
        ).called(withFallback ? 2 : 1);
        expect(await resumeCount(), 2);
      } finally {
        await runtime.dispose();
        await support.log.flush();
        await dir.delete(recursive: true);
      }
    });
  }
}
