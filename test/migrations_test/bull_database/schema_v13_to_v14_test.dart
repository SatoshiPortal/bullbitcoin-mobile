import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'generated/schema.dart';
import 'generated/schema_v13.dart' as v13;
import 'generated/schema_v14.dart' as v14;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  group('v13 to v14: settings payjoin columns, payjoin_receivers/senders '
      'is_aborted columns', () {
    test('adds payjoin_enabled, payjoin_min_amount_sat and '
        'payjoin_expire_after_sec to settings, backfilling existing rows to '
        'false/10000/86400', () async {
      final schema = await verifier.schemaAt(13);

      final oldDb = v13.DatabaseAtV13(schema.newConnection());
      await oldDb
          .into(oldDb.settings)
          .insert(
            v13.SettingsCompanion.insert(
              id: const Value(1),
              environment: 'mainnet',
              bitcoinUnit: 'sats',
              language: 'en',
              currency: 'USD',
              hideAmounts: 0,
              isSuperuser: 0,
            ),
          );
      await oldDb.close();

      final db = SqliteDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 14);
      await db.close();

      final migratedDb = v14.DatabaseAtV14(schema.newConnection());
      final settings = await migratedDb.select(migratedDb.settings).get();
      expect(settings, hasLength(1));
      expect(settings.single.payjoinEnabled, 0);
      expect(settings.single.payjoinMinAmountSat, 10000);
      expect(settings.single.payjoinExpireAfterSec, 86400);
      await migratedDb.close();
    });

    test('adds is_aborted to payjoin_receivers and payjoin_senders, '
        'backfilling existing rows to false', () async {
      final schema = await verifier.schemaAt(13);

      final oldDb = v13.DatabaseAtV13(schema.newConnection());
      await oldDb
          .into(oldDb.payjoinReceivers)
          .insert(
            v13.PayjoinReceiversCompanion.insert(
              id: 'receiver1',
              address: 'bcrt1qaddress',
              isTestnet: 1,
              receiver: '[]',
              walletId: 'wallet1',
              pjUri: 'bitcoin:bcrt1qaddress?pj=https://payjo.in/abc',
              maxFeeRateSatPerVb: 10000,
              createdAt: 1700000000,
              expireAfterSec: 86400,
              isExpired: 0,
              isCompleted: 0,
            ),
          );
      await oldDb
          .into(oldDb.payjoinSenders)
          .insert(
            v13.PayjoinSendersCompanion.insert(
              uri: 'bitcoin:bcrt1qaddress?pj=https://payjo.in/abc',
              isTestnet: 1,
              sender: '[]',
              walletId: 'wallet1',
              originalPsbt: 'psbt-base64',
              originalTxId: 'a' * 64, // 64-char placeholder, not a real txid
              amountSat: 10000,
              createdAt: 1700000000,
              expireAfterSec: 86400,
              isExpired: 0,
              isCompleted: 0,
            ),
          );
      await oldDb.close();

      final db = SqliteDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 14);
      await db.close();

      final migratedDb = v14.DatabaseAtV14(schema.newConnection());
      final receivers = await migratedDb
          .select(migratedDb.payjoinReceivers)
          .get();
      final senders = await migratedDb.select(migratedDb.payjoinSenders).get();
      expect(receivers.single.isAborted, 0);
      expect(senders.single.isAborted, 0);
      await migratedDb.close();
    });
  });
}
