import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'generated/schema.dart';
import 'generated/schema_v15.dart' as v15;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test(
    'v15 to v16 keeps certificate validation for existing servers',
    () async {
      final schema = await verifier.schemaAt(15);
      final oldDb = v15.DatabaseAtV15(schema.newConnection());
      await oldDb.batch((batch) {
        batch.insertAll(oldDb.mempoolServers, [
          v15.MempoolServersCompanion.insert(
            url: 'mempool.local',
            isTestnet: 1,
            isLiquid: 0,
            isCustom: 1,
            enableSsl: const Value(1),
          ),
          v15.MempoolServersCompanion.insert(
            url: 'mempool.bullbitcoin.com',
            isTestnet: 0,
            isLiquid: 0,
            isCustom: 0,
            enableSsl: const Value(1),
          ),
        ]);
      });
      await oldDb.close();

      final db = SqliteDatabase(schema.newConnection());
      addTearDown(db.close);
      await verifier.migrateAndValidate(db, 16);

      final servers = await db.select(db.mempoolServers).get();
      expect(servers, hasLength(2));
      expect(servers.every((server) => server.validateDomain), isTrue);
      expect(servers.every((server) => server.enableSsl), isTrue);
      final custom = servers.singleWhere((server) => server.isCustom);
      expect(custom.url, 'mempool.local');
      expect(custom.isTestnet, isTrue);
      expect(custom.isLiquid, isFalse);
      final defaultServer = servers.singleWhere((server) => !server.isCustom);
      expect(defaultServer.url, 'mempool.bullbitcoin.com');
      expect(defaultServer.isTestnet, isFalse);
      expect(defaultServer.isLiquid, isFalse);
    },
  );
}
