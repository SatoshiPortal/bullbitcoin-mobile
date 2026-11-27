import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:legacy_storage/coordination.dart';
import 'package:legacy_storage/legacy_storage.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';
import 'package:sync/sync.dart';
import 'package:sync/storage.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'imports the historical nullable synced_at by exact wallet id',
    () async {
      final dir = await Directory.systemTemp.createTemp('sync-metadata-');
      addTearDown(() => dir.delete(recursive: true));
      FakeSecureStoragePlatform().install();
      final source = File('${dir.path}/legacy.sqlite');
      final db = sqlite3.open(source.path);
      try {
        db.execute('''
        CREATE TABLE wallet_metadatas (id TEXT PRIMARY KEY, synced_at TEXT);
        INSERT INTO wallet_metadatas VALUES
          ('first', '2026-11-21T10:23:17.000Z'),
          ('second', NULL);
      ''');
        db.userVersion = 16;
      } finally {
        db.close();
      }

      final file = File('${dir.path}/sync.sqlite');
      final keys = Secrets(
        authority: unlockedSessionAuthority(),
        scratchDirectory: () async => dir.path,
      ).databaseKeys(module: 'sync');
      final participant = syncWalletMetadataImport(file: file, keys: keys);
      final gate = NativeFileGate(File('${dir.path}/gate'));
      final exclusive = await gate.acquire(
        exclusive: true,
        timeout: Duration.zero,
      ) as ExclusiveAdmission;
      try {
        final prepared = await participant.prepare(
          exclusive,
          OwnerOrigin.legacy,
        );
        final owner =
            (prepared as Ok<PreparedOwner, LegacyImportFailure>).value;
        expect(await owner.importLegacy(LegacySource(source, 16)), isA<Ok>());
        expect(await owner.importLegacy(LegacySource(source, 16)), isA<Ok>());
        expect(await owner.close(), isA<Ok>());
      } finally {
        await exclusive.close();
      }

      final admission = await gate.acquire(
        exclusive: false,
        timeout: Duration.zero,
      ) as RuntimeAdmission;
      try {
        final readiness = await participant.inspect(admission);
        expect(
          (readiness as Ok<OwnerReadiness, LegacyImportFailure>).value,
          OwnerReadiness.imported,
        );
        final opened = await SyncFreshness.open(
          file: file,
          admission: admission,
          keys: keys,
        );
        final storage = (opened as Ok<SyncFreshness, SyncFailure>).value;
        final first = await storage.read('first');
        final second = await storage.read('second');
        expect(
          (first as Ok<DateTime?, SyncFailure>).value,
          DateTime.utc(2026, 11, 21, 10, 23, 17),
        );
        expect((second as Ok<DateTime?, SyncFailure>).value, isNull);
        expect(await source.exists(), isTrue);
      } finally {
        await admission.close();
      }
    },
  );
}
