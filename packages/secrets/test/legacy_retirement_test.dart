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

// BIP32 test vector 1: master extended public key and its fingerprint.
const _xpub =
    'xpub661MyMwAqRbcFtXgS5sYJABqqG9YLmC4Q1Rdap9gSE8NqtwybGhePY2gZ29ESFjqJoCu1Rupje8YtGqsefD265TMg7usUDFdp6W1EGMcet8';
const _fingerprint = '3442193e';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;
  late NativeFileGate gate;
  late File destination;
  late File source;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('secrets-retirement-');
    gate = NativeFileGate(File('${directory.path}/admission'));
    destination = File('${directory.path}/inventory.sqlite');
    source = File('${directory.path}/legacy.sqlite');
    FakeSecureStoragePlatform().install();
  });

  tearDown(() async {
    await LifecycleAdmission.retryQuarantined();
    await directory.delete(recursive: true);
  });

  Future<ExclusiveAdmission> exclusive() async =>
      await gate.acquire(exclusive: true, timeout: Duration.zero)
          as ExclusiveAdmission;

  void createSource(String fingerprint) {
    final legacy = sqlite3.open(source.path);
    try {
      legacy.execute('''
        CREATE TABLE wallet_metadatas (
          id TEXT PRIMARY KEY, master_fingerprint TEXT NOT NULL,
          signer TEXT NOT NULL, network TEXT NOT NULL, xpub TEXT NOT NULL,
          xpub_fingerprint TEXT NOT NULL,
          external_public_descriptor TEXT NOT NULL,
          internal_public_descriptor TEXT NOT NULL,
          label TEXT, birthday TEXT, is_default INTEGER NOT NULL
        );
        CREATE TABLE bip85_derivations (
          path TEXT PRIMARY KEY, xprv_fingerprint TEXT NOT NULL,
          application TEXT NOT NULL, status TEXT NOT NULL, alias TEXT
        );
      ''');
      legacy.execute(
        'INSERT INTO wallet_metadatas VALUES (?,?,?,?,?,?,?,?,?,?,?)',
        [
          'w',
          'owner',
          'local',
          'bitcoin',
          _xpub,
          fingerprint,
          'external',
          'internal',
          null,
          null,
          1,
        ],
      );
      legacy.userVersion = 16;
    } finally {
      legacy.close();
    }
  }

  Future<void> importOwner(OwnerOrigin origin) async {
    final admission = await exclusive();
    try {
      final opened = await SecretsImport(file: destination)
          .prepare(admission, origin);
      final owner = (opened as Ok<PreparedOwner, LegacyImportFailure>).value;
      final result = origin == OwnerOrigin.legacy
          ? await owner.importLegacy(LegacySource(source, 16))
          : await owner.initializeFresh();
      expect(result, isA<Ok>());
      expect(await owner.close(), isA<Ok>());
    } finally {
      await admission.close();
    }
  }

  Future<void> setReceipt(String receipt) async {
    final admission = await exclusive();
    try {
      final opened = await InventoryStore.open(
        destination,
        admission,
        existing: true,
      );
      final store = (opened as Ok<InventoryStore, DatabaseOpenFailure>).value;
      try {
        await store.database.customStatement(
          'UPDATE access_state SET import_receipt = ?',
          [receipt],
        );
      } finally {
        await store.close();
      }
    } finally {
      await admission.close();
    }
  }

  Future<Result<void, LegacyImportFailure>> verify(OwnerOrigin origin) async {
    final admission = await exclusive();
    try {
      return await SecretsRetirement(file: destination).verifyRetirable(
        admission,
        origin: origin,
        source: LegacySource(source, 16),
      );
    } finally {
      await admission.close();
    }
  }

  group('proof', () {
    test('a verified import with matching fingerprints is retirable', () async {
      createSource(_fingerprint);
      await importOwner(OwnerOrigin.legacy);
      expect(await verify(OwnerOrigin.legacy), isA<Ok>());
    });

    test(
      'a fingerprint the schema omitted refuses and changes nothing',
      () async {
        createSource('deadbeef');
        await importOwner(OwnerOrigin.legacy);
        final before = source.readAsBytesSync();
        expect(
          await verify(OwnerOrigin.legacy),
          isA<Err<void, LegacyImportFailure>>().having(
            (e) => e.failure,
            'failure',
            isA<LegacyImportVerificationFailed>(),
          ),
        );
        expect(source.readAsBytesSync(), before);
      },
    );

    test('a fresh owner needs no source', () async {
      await importOwner(OwnerOrigin.fresh);
      expect(source.existsSync(), isFalse);
      expect(await verify(OwnerOrigin.fresh), isA<Ok>());
    });

    test('a reconstruction receipt proves nothing', () async {
      createSource(_fingerprint);
      await importOwner(OwnerOrigin.legacy);
      await setReceipt('recovered-v1/secrets');
      expect(await verify(OwnerOrigin.legacy), isA<Err>());
    });

    test('a receipt from before access moved is refused', () async {
      createSource(_fingerprint);
      await importOwner(OwnerOrigin.legacy);
      await setReceipt('split-v1/secrets');
      expect(await verify(OwnerOrigin.legacy), isA<Err>());
    });

    test('a fresh receipt does not certify a legacy origin', () async {
      createSource(_fingerprint);
      await importOwner(OwnerOrigin.fresh);
      expect(await verify(OwnerOrigin.legacy), isA<Err>());
    });
  });
}
