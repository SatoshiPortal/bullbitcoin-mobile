import 'dart:io';

import 'package:bull_payjoin/migration.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:legacy_storage/coordination.dart';
import 'package:legacy_storage/legacy_storage.dart';
import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

import 'migrations_test/payjoin_database/generated/schema_v2.dart' as v2;

void main() {
  test(
    'the v2 standalone file supplies live sessions on a rootless install',
    () async {
      final directory = await Directory.systemTemp.createTemp('payjoin-owner-');
      addTearDown(() => directory.delete(recursive: true));
      final oldFile = File('${directory.path}/payjoin.sqlite');
      final replacement = File('${directory.path}/encrypted.sqlite');
      final old = v2.DatabaseAtV2(NativeDatabase(oldFile));
      try {
        await old.customStatement('PRAGMA user_version = 2');
        await old
            .into(old.payjoinSenders)
            .insert(
              const v2.PayjoinSendersData(
                uri: 'pending-v2',
                isTestnet: 0,
                sender: '[]',
                walletId: 'wallet-1',
                originalPsbt: 'fixture-psbt',
                originalTxId: 'fixture-tx',
                amountSat: 20000,
                createdAt: 1700000000,
                expireAfterSec: 3600,
                isExpired: 0,
                isCompleted: 0,
                isAborted: 0,
              ),
            );
        await old
            .into(old.payjoinReceivers)
            .insert(
              v2.PayjoinReceiversData(
                id: 'active-receiver',
                address: 'fixture-address',
                isTestnet: 0,
                receiver: '[]',
                walletId: 'wallet-1',
                pjUri: 'fixture-uri',
                maxFeeRateSatPerVb: 25,
                createdAt: 1700000001,
                expireAfterSec: 3600,
                originalTxBytes: Uint8List.fromList([0, 255, 1]),
                isExpired: 0,
                isCompleted: 0,
                isAborted: 0,
                isTrade: 1,
              ),
            );
        await old
            .into(old.payjoinPolicies)
            .insert(
              const v2.PayjoinPoliciesData(
                id: 1,
                enabled: 0,
                sendEnabled: 1,
                buyEnabled: 0,
                sellEnabled: 1,
                minimumAmountSat: 12345,
                sessionLifetimeSeconds: 3600,
              ),
            );
      } finally {
        await old.close();
      }
      final sourceBytes = await oldFile.readAsBytes();
      final gate = NativeFileGate(File('${directory.path}/lifecycle.lock'));
      final cutover = PayjoinCutover(
        file: replacement,
        standalone: oldFile,
        regtest: false,
        executor: (_) => _executor(replacement.path),
      );
      final lease = await gate.acquire(
        exclusive: true,
        timeout: const Duration(seconds: 1),
      ) as ExclusiveAdmission;
      try {
        final opened = await cutover.participant.prepare(
          lease,
          OwnerOrigin.fresh,
        );
        final owner = (opened as Ok<PreparedOwner, LegacyImportFailure>).value;
        expect(await owner.initializeFresh(), isA<Ok>());
        expect(await owner.close(), isA<Ok>());
      } finally {
        await lease.close();
      }
      final shared = await gate.acquire(
        exclusive: false,
        timeout: const Duration(seconds: 1),
      ) as RuntimeAdmission;
      try {
        final opened = await cutover.open(shared);
        await opened.fold((store) async {
          final database = store.database;
          final sender = await database
              .select(database.payjoinSenders)
              .getSingle();
          final receiver = await database
              .select(database.payjoinReceivers)
              .getSingle();
          final policy = await database
              .select(database.payjoinPolicies)
              .getSingle();
          expect(sender.hasNetworkEvidence, isTrue);
          expect(receiver.isTrade, isTrue);
          expect(receiver.originalTxBytes, orderedEquals([0, 255, 1]));
          expect(policy.minimumAmountSat, 12345);
          expect(policy.buyEnabled, isFalse);
        }, (_) async => fail('Could not reopen Payjoin destination'));
      } finally {
        await shared.close();
      }
      expect(await oldFile.readAsBytes(), sourceBytes);
    },
  );
}

Future<Result<QueryExecutor, LegacyImportFailure>> Function() _executor(
  String path,
) =>
    () async => Ok(NativeDatabase(File(path)));
