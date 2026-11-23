import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:legacy_storage/coordination.dart';
import 'package:legacy_storage/legacy_storage.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/migration.dart';
import 'package:secrets/src/data/inventory_store.dart';
import 'package:secrets/src/domain/database_open_failure.dart';
import 'package:secrets/testing.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;
  late NativeFileGate gate;
  late SecretsImport participant;
  late File destination;
  late File source;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('inventory-import-');
    gate = NativeFileGate(File('${directory.path}/admission'));
    destination = File('${directory.path}/inventory.sqlite');
    source = File('${directory.path}/legacy.sqlite');
    participant = SecretsImport(file: destination);
    FakeSecureStoragePlatform().install();
  });

  tearDown(() async {
    await LifecycleAdmission.retryQuarantined();
    await directory.delete(recursive: true);
  });

  Future<ExclusiveAdmission> exclusive() async =>
      await gate.acquire(exclusive: true, timeout: Duration.zero)
          as ExclusiveAdmission;

  Future<RuntimeAdmission> runtime() async =>
      await gate.acquire(exclusive: false, timeout: Duration.zero)
          as RuntimeAdmission;

  Future<PreparedOwner> prepare(
    ExclusiveAdmission admission,
    OwnerOrigin origin,
  ) async {
    final opened = await participant.prepare(admission, origin);
    expect(opened, isA<Ok<PreparedOwner, LegacyImportFailure>>());
    return (opened as Ok<PreparedOwner, LegacyImportFailure>).value;
  }

  test('copies raw definitions and parent paths exactly once', () async {
    _createSource(source);
    final admission = await exclusive();
    try {
      final owner = await prepare(admission, OwnerOrigin.legacy);
      expect(await owner.importLegacy(LegacySource(source, 16)), isA<Ok>());
      expect(await owner.importLegacy(LegacySource(source, 16)), isA<Ok>());
      expect(await owner.close(), isA<Ok>());
    } finally {
      await admission.close();
    }
    final shared = await runtime();
    try {
      final opened = await InventoryStore.open(
        destination,
        shared,
        existing: true,
      );
      final store = (opened as Ok<InventoryStore, DatabaseOpenFailure>).value;
      final rows = await store.database
          .customSelect('SELECT * FROM wallets ORDER BY id')
          .get();
      expect(rows.map((row) => row.data['id']), ['hardware', 'local-wallet']);
      expect(rows.map((row) => row.data['secret_fingerprint']), [
        null,
        'owner',
      ]);
      expect(rows.map((row) => row.data['label']), ['', null]);
      expect(rows.map((row) => row.data['network']), [
        'unknown-chain',
        'bitcoin',
      ]);
      expect(rows.last.data['external_descriptor'], 'exact-external-marker');
      expect(rows.last.data['birthday'], '2026-11-21T10:23:17.000Z');
      final derivations = await store.database
          .customSelect('SELECT * FROM derivations')
          .get();
      expect(derivations.single.data['parent_fingerprint'], 'orphan-parent');
      expect(derivations.single.data['path'], "128169'/16'/7'");
      expect(derivations.single.data['status'], 'revoked');
      final members = await store.database
          .customSelect('SELECT member FROM view_members ORDER BY member')
          .get();
      expect(members.map((row) => row.data['member']), [
        'secret:orphan-parent',
        'secret:owner',
        'wallet:hardware',
      ]);
      expect(
        await store.database.select(store.database.credentials).get(),
        isEmpty,
      );
      await store.close();
      expect(
        await participant.inspect(shared),
        isA<Ok<OwnerReadiness, LegacyImportFailure>>().having(
          (result) => result.value,
          'committed import receipt',
          OwnerReadiness.imported,
        ),
      );
      expect(await source.exists(), isTrue);
    } finally {
      await shared.close();
    }
  });

  test('a failed import rolls back all projections and can retry', () async {
    _createSource(source, includeDerivations: false);
    final admission = await exclusive();
    try {
      final owner = await prepare(admission, OwnerOrigin.legacy);
      expect(await owner.importLegacy(LegacySource(source, 16)), isA<Err>());
      expect(
        await owner.receipt(),
        isA<Ok<OwnerReadiness, LegacyImportFailure>>().having(
          (result) => result.value,
          'readiness after failure',
          OwnerReadiness.pending,
        ),
      );
      final legacy = sqlite3.open(source.path);
      try {
        _writeDerivations(legacy);
      } finally {
        legacy.close();
      }
      // The importer refuses a pending destination containing committed rows.
      // A successful retry therefore also proves the first copy rolled back.
      expect(await owner.importLegacy(LegacySource(source, 16)), isA<Ok>());
      expect(await owner.close(), isA<Ok>());
    } finally {
      await admission.close();
    }
  });

  test('fresh initialization has a distinct receipt and no source', () async {
    final admission = await exclusive();
    try {
      final owner = await prepare(admission, OwnerOrigin.fresh);
      expect(await owner.initializeFresh(), isA<Ok>());
      expect(await owner.initializeFresh(), isA<Ok>());
      expect(
        await owner.receipt(),
        isA<Ok<OwnerReadiness, LegacyImportFailure>>().having(
          (result) => result.value,
          'fresh receipt',
          OwnerReadiness.initialized,
        ),
      );
      expect(await owner.close(), isA<Ok>());
      expect(await source.exists(), isFalse);
    } finally {
      await admission.close();
    }
  });
}

void _createSource(File file, {bool includeDerivations = true}) {
  final legacy = sqlite3.open(file.path);
  try {
    legacy.execute('''
      CREATE TABLE wallet_metadatas (
        id TEXT PRIMARY KEY, master_fingerprint TEXT NOT NULL,
        signer TEXT NOT NULL, network TEXT NOT NULL, xpub TEXT NOT NULL,
        external_public_descriptor TEXT NOT NULL, internal_public_descriptor TEXT NOT NULL,
        label TEXT, birthday TEXT, is_default INTEGER NOT NULL
      );
      INSERT INTO wallet_metadatas VALUES
        ('local-wallet', 'owner', 'local', 'bitcoin', 'xpub-marker',
          'exact-external-marker', 'internal-marker', NULL, '2026-11-21T10:23:17.000Z', 1),
        ('hardware', 'hardware-owner', 'remote', 'unknown-chain', 'xpub-marker',
          'external-marker', 'internal-marker', '', NULL, 0);
    ''');
    if (includeDerivations) _writeDerivations(legacy);
    legacy.userVersion = 16;
  } finally {
    legacy.close();
  }
}

void _writeDerivations(Database legacy) {
  legacy.execute('''
    CREATE TABLE bip85_derivations (
      path TEXT PRIMARY KEY, xprv_fingerprint TEXT NOT NULL,
      application TEXT NOT NULL, status TEXT NOT NULL, alias TEXT
    )
  ''');
  legacy.execute('INSERT INTO bip85_derivations VALUES (?,?,?,?,?)', [
    "128169'/16'/7'",
    'orphan-parent',
    'hex',
    'revoked',
    '',
  ]);
}
