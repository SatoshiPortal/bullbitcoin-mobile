import 'dart:io';

import 'package:bull_payjoin/migration.dart';
import 'package:bull_payjoin/src/data/payjoin_migration.dart';
import 'package:bull_payjoin/src/domain/payjoin_ports.dart';
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
      final quarantine = File('${oldFile.path}.unreadable-1');
      await quarantine.writeAsBytes([1, 0, 255]);
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
          expect(
            await hasLegacyImportReceipt(
              database,
              'standalone-v1/payjoin/quarantine-present',
            ),
            isA<Ok<bool, LegacyImportFailure>>().having(
              (r) => r.value,
              'value',
              true,
            ),
          );
        }, (_) async => fail('Could not reopen Payjoin destination'));
      } finally {
        await shared.close();
      }
      expect(await oldFile.readAsBytes(), sourceBytes);
      expect(await quarantine.readAsBytes(), [1, 0, 255]);
    },
  );

  for (final (marked, invalid, engaged) in [
    (true, false, false),
    (true, false, true),
    (true, true, false),
    (false, true, false),
  ]) {
    test('reconciles root (marked=$marked, invalid=$invalid, engaged=$engaged)', () async {
      final directory = await Directory.systemTemp.createTemp('payjoin-root-');
      addTearDown(() => directory.delete(recursive: true));
      final rootFile = File('${directory.path}/root.sqlite');
      final standalone = File('${directory.path}/payjoin.sqlite');
      final replacement = File('${directory.path}/encrypted.sqlite');
      final root = v2.DatabaseAtV2(NativeDatabase(rootFile));
      const sender = PayjoinLegacySender(
        uri: 'active-sender',
        isTestnet: false,
        protocolState: '[]',
        walletId: 'wallet',
        originalPsbt: 'original',
        originalTransactionId: 'original-tx',
        amountSat: 1000,
        createdAt: 1700000000,
        expireAfterSec: 3600,
        proposalPsbt: 'root-proposal',
        transactionId: null,
        isExpired: false,
        isCompleted: false,
      );
      final receiver = PayjoinLegacyReceiver(
        id: 'missing-receiver',
        address: 'address',
        isTestnet: false,
        protocolState: '[]',
        walletId: 'wallet',
        payjoinUri: 'receiver-uri',
        maximumFeeRateSatPerVbyte: BigInt.one,
        createdAt: 1700000001,
        expireAfterSec: 3600,
        originalTransaction: engaged ? Uint8List.fromList([1]) : null,
        originalTransactionId: null,
        amountSat: null,
        proposalPsbt: null,
        transactionId: null,
        isExpired: false,
        isCompleted: false,
      );
      const insertSender = '''
        INSERT INTO payjoin_senders
        (uri,is_testnet,sender,wallet_id,original_psbt,original_tx_id,
         amount_sat,created_at,expire_after_sec,proposal_psbt,is_expired,
         is_completed,is_aborted)
        VALUES (?,0,'[]','wallet','original','original-tx',
                1000,1700000000,?,?,0,0,0)
      ''';
      try {
        await root.customStatement('PRAGMA user_version = 16');
        await root.customStatement(insertSender, [
          sender.uri,
          3600,
          'root-proposal',
        ]);
        if (invalid) {
          await root.customStatement(insertSender, ['invalid-expiry', 0, null]);
          await root.customStatement(insertSender, ['\t', 3600, null]);
        }
        await root.customStatement(
          '''
          INSERT INTO payjoin_receivers
          (id,address,is_testnet,receiver,wallet_id,pj_uri,max_fee_rate_sat_per_vb,
           created_at,expire_after_sec,original_tx_bytes,is_expired,is_completed,
           is_aborted,is_trade)
          VALUES ('missing-receiver','address',0,'[]','wallet','receiver-uri',1,
                  1700000001,3600,?,0,0,0,0)
        ''',
          [receiver.originalTransaction],
        );
        if (invalid) {
          await root.customStatement('''
            INSERT INTO payjoin_receivers
            SELECT 'invalid-wallet',address,is_testnet,receiver,' ',pj_uri,
              max_fee_rate_sat_per_vb,created_at,expire_after_sec,original_tx_bytes,
              original_tx_id,amount_sat,proposal_psbt,tx_id,is_expired,is_completed,
              is_aborted,is_trade
            FROM payjoin_receivers WHERE id = 'missing-receiver'
          ''');
        }
      } finally {
        await root.close();
      }
      if (marked) {
        final old = v2.DatabaseAtV2(NativeDatabase(standalone));
        try {
          await old.customStatement('PRAGMA user_version = 2');
          await old.customStatement(insertSender, [
            sender.uri,
            3600,
            'live-proposal',
          ]);
          await old.customStatement(
            '''
            INSERT INTO payjoin_migrations
            (name,completed_at,source_schema_version,sender_count,receiver_count,verification_digest)
            VALUES ('root-payjoin-v1',1700000000,16,1,1,?)
          ''',
            [
              legacyPayjoinSnapshotDigest(
                PayjoinLegacySnapshot(
                  sourceSchemaVersion: 16,
                  senders: [sender],
                  receivers: [receiver],
                ),
              ),
            ],
          );
        } finally {
          await old.close();
        }
      }
      final rootBytes = await rootFile.readAsBytes();
      final warnings = <String>[];
      final gate = NativeFileGate(File('${directory.path}/lifecycle.lock'));
      final cutover = PayjoinCutover(
        file: replacement,
        standalone: standalone,
        regtest: false,
        executor: (_) => _executor(replacement.path),
        warning: warnings.add,
      );
      final lease = await gate.acquire(
        exclusive: true,
        timeout: const Duration(seconds: 2),
      ) as ExclusiveAdmission;
      try {
        final opened = await cutover.participant.prepare(
          lease,
          OwnerOrigin.legacy,
        );
        final owner = (opened as Ok<PreparedOwner, LegacyImportFailure>).value;
        final result = await owner.importLegacy(LegacySource(rootFile, 16));
        expect(
          result,
          engaged
              ? isA<Err<void, LegacyImportFailure>>().having(
                  (r) => r.failure,
                  'failure',
                  isA<LegacyImportVerificationFailed>(),
                )
              : isA<Ok>(),
        );
        expect(await owner.close(), isA<Ok>());
      } finally {
        await lease.close();
      }
      expect(await rootFile.readAsBytes(), rootBytes);
      if (engaged) {
        expect(warnings, [
          'storage.cutover.rejected owner=payjoin reason=root_receiver_missing',
        ]);
        return;
      }
      expect(
        warnings,
        marked
            ? isEmpty
            : ['storage.cutover.root_payjoin_quarantined senders=2 receivers=1'],
      );
      final shared = await gate.acquire(
        exclusive: false,
        timeout: const Duration(seconds: 2),
      ) as RuntimeAdmission;
      try {
        final opened = await cutover.open(shared);
        await opened.fold((store) async {
          final db = store.database;
          final imported = await db.select(db.payjoinSenders).getSingle();
          expect(imported.uri, sender.uri);
          expect(imported.isCompleted, isFalse);
          expect(
            imported.proposalPsbt,
            marked ? 'live-proposal' : 'root-proposal',
          );
          final receivers = await db.select(db.payjoinReceivers).get();
          expect(receivers.map((r) => r.id), marked ? isEmpty : [receiver.id]);
          if (!marked) {
            expect(
              await hasLegacyImportReceipt(db, 'root-payjoin-quarantine/2s/1r'),
              isA<Ok<bool, LegacyImportFailure>>().having(
                (r) => r.value,
                'value',
                true,
              ),
            );
          }
        }, (_) async => fail('Could not reopen Payjoin destination'));
      } finally {
        await shared.close();
      }
    });
  }
}

Future<Result<QueryExecutor, LegacyImportFailure>> Function() _executor(
  String path,
) =>
    () async => Ok(NativeDatabase(File(path)));
