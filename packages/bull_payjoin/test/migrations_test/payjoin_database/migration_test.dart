// dart format width=80
// ignore_for_file: unused_local_variable, unused_import
import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:bull_payjoin/src/data/payjoin_database.dart';
import 'package:test/test.dart';
import 'generated/schema.dart';

import 'generated/schema_v1.dart' as v1;
import 'generated/schema_v2.dart' as v2;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  group('simple database migrations', () {
    // These simple tests verify all possible schema updates with a simple (no
    // data) migration. This is a quick way to ensure that written database
    // migrations properly alter the schema.
    const versions = GeneratedHelper.versions;
    for (final (i, fromVersion) in versions.indexed) {
      group('from $fromVersion', () {
        for (final toVersion in versions.skip(i + 1)) {
          test('to $toVersion', () async {
            final schema = await verifier.schemaAt(fromVersion);
            final db = PayjoinDatabase.forTesting(schema.newConnection());
            await verifier.migrateAndValidate(db, toVersion);
            await db.close();
          });
        }
      });
    }
  });

  // Schema 1 shipped with one switch that gated both sending and receiving
  // between users. After the upgrade both of those keep its value, the
  // exchange switches start on, and existing receivers stay user receivers.
  for (final enabled in [1, 0]) {
    test('migration from v1 to v2 keeps enabled=$enabled for send and '
        'receive', () async {
      final oldPayjoinPoliciesData = <v1.PayjoinPoliciesData>[
        v1.PayjoinPoliciesData(
          id: 1,
          enabled: enabled,
          minimumAmountSat: 12345,
          sessionLifetimeSeconds: 3600,
        ),
      ];
      final expectedNewPayjoinPoliciesData = <v2.PayjoinPoliciesData>[
        v2.PayjoinPoliciesData(
          id: 1,
          enabled: enabled,
          sendEnabled: enabled,
          buyEnabled: 1,
          sellEnabled: 1,
          minimumAmountSat: 12345,
          sessionLifetimeSeconds: 3600,
        ),
      ];

      final oldPayjoinReceiversData = <v1.PayjoinReceiversData>[
        const v1.PayjoinReceiversData(
          id: 'receiver-1',
          address: 'bc1qexample',
          isTestnet: 0,
          receiver: '[]',
          walletId: 'wallet-1',
          pjUri: 'bitcoin:bc1qexample?pj=https://payjo.in/abc',
          maxFeeRateSatPerVb: 20,
          createdAt: 1700000000,
          expireAfterSec: 86400,
          isExpired: 0,
          isCompleted: 0,
          isAborted: 0,
        ),
      ];
      final expectedNewPayjoinReceiversData = <v2.PayjoinReceiversData>[
        const v2.PayjoinReceiversData(
          id: 'receiver-1',
          address: 'bc1qexample',
          isTestnet: 0,
          receiver: '[]',
          walletId: 'wallet-1',
          pjUri: 'bitcoin:bc1qexample?pj=https://payjo.in/abc',
          maxFeeRateSatPerVb: 20,
          createdAt: 1700000000,
          expireAfterSec: 86400,
          isExpired: 0,
          isCompleted: 0,
          isAborted: 0,
          isTrade: 0,
        ),
      ];

      final oldPayjoinSendersData = <v1.PayjoinSendersData>[];
      final expectedNewPayjoinSendersData = <v2.PayjoinSendersData>[];

      final oldPayjoinMigrationsData = <v1.PayjoinMigrationsData>[];
      final expectedNewPayjoinMigrationsData = <v2.PayjoinMigrationsData>[];

      await verifier.testWithDataIntegrity(
        oldVersion: 1,
        newVersion: 2,
        createOld: v1.DatabaseAtV1.new,
        createNew: v2.DatabaseAtV2.new,
        openTestedDatabase: PayjoinDatabase.forTesting,
        createItems: (batch, oldDb) {
          batch.insertAll(oldDb.payjoinSenders, oldPayjoinSendersData);
          batch.insertAll(oldDb.payjoinReceivers, oldPayjoinReceiversData);
          batch.insertAll(oldDb.payjoinPolicies, oldPayjoinPoliciesData);
          batch.insertAll(oldDb.payjoinMigrations, oldPayjoinMigrationsData);
        },
        validateItems: (newDb) async {
          expect(
            expectedNewPayjoinSendersData,
            await newDb.select(newDb.payjoinSenders).get(),
          );
          expect(
            expectedNewPayjoinReceiversData,
            await newDb.select(newDb.payjoinReceivers).get(),
          );
          expect(
            expectedNewPayjoinPoliciesData,
            await newDb.select(newDb.payjoinPolicies).get(),
          );
          expect(
            expectedNewPayjoinMigrationsData,
            await newDb.select(newDb.payjoinMigrations).get(),
          );
        },
      );
    });
  }
}
