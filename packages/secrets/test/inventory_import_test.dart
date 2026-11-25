import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_test/flutter_test.dart';
import 'package:legacy_storage/coordination.dart';
import 'package:legacy_storage/legacy_storage.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/migration.dart';
import 'package:secrets/src/data/fss_datasource.dart';
import 'package:secrets/src/data/inventory_store.dart';
import 'package:secrets/src/data/owner_keychain.dart';
import 'package:secrets/src/domain/database_open_failure.dart';
import 'package:secrets/storage.dart';
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

  Future<void> writeReceipt(
    LifecycleAdmission admission,
    String receipt,
  ) async {
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
  }

  Future<void> admitBeforeCatalog(OwnerOrigin origin) async {
    final admission = await exclusive();
    try {
      final owner = await prepare(admission, origin);
      final receipt = switch (origin) {
        OwnerOrigin.legacy => 'split-v1/secrets',
        OwnerOrigin.fresh => 'fresh-v1/secrets',
      };
      _expectOk(
        await (origin == OwnerOrigin.legacy
            ? owner.importLegacy(LegacySource(source, 16))
            : owner.initializeFresh()),
      );
      _expectOk(await owner.close());
      await writeReceipt(admission, receipt);
    } finally {
      await admission.close();
    }
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

  test('refuses an import receipt if the persisted cooldown differs', () async {
    _createSource(source);
    final keychain = OwnerKeychain();
    final deadline = DateTime.now().add(const Duration(minutes: 1));
    final epoch = deadline.millisecondsSinceEpoch.toString();
    expect(await keychain.write(OwnerKey.attempts, '4'), isA<Ok>());
    expect(await keychain.write(OwnerKey.lockedUntil, epoch), isA<Ok>());
    final admission = await exclusive();
    try {
      final opened = await InventoryStore.open(
        destination,
        admission,
        existing: false,
      );
      final store = (opened as Ok<InventoryStore, DatabaseOpenFailure>).value;
      await store.database.customStatement('''
        CREATE TRIGGER mutate_cooldown AFTER INSERT ON access_state
        BEGIN
          UPDATE access_state SET locked_until = NULL;
        END
      ''');
      await store.close();

      final owner = await prepare(admission, OwnerOrigin.legacy);
      expect(
        await owner.importLegacy(LegacySource(source, 16)),
        isA<Err<void, LegacyImportFailure>>().having(
          (result) => result.failure,
          'failure',
          isA<LegacyImportVerificationFailed>(),
        ),
      );
      expect(
        await owner.receipt(),
        isA<Ok<OwnerReadiness, LegacyImportFailure>>().having(
          (result) => result.value,
          'readiness',
          OwnerReadiness.pending,
        ),
      );
      expect(await owner.close(), isA<Ok>());
      expect(
        (await keychain.read(OwnerKey.lockedUntil))
            .fold((value) => value == epoch, (_) => false),
        isTrue,
      );
    } finally {
      await admission.close();
    }
  });

  test('a migrated credential keeps the view locked after restart', () async {
    _createSource(source);
    final keychain = OwnerKeychain();
    final candidate = Random.secure()
        .nextInt(100000000)
        .toString()
        .padLeft(8, '0');
    expect(await keychain.write(OwnerKey.pin, candidate), isA<Ok>());

    final migration = await exclusive();
    try {
      final owner = await prepare(migration, OwnerOrigin.legacy);
      expect(await owner.importLegacy(LegacySource(source, 16)), isA<Ok>());
      expect(await owner.close(), isA<Ok>());
    } finally {
      await migration.close();
    }
    expect(
      (await keychain.read(OwnerKey.pin))
          .fold((value) => value == candidate, (_) => false),
      isTrue,
    );

    final resumed = await runtime();
    try {
      final opened = await SecretsInventory.open(
        file: destination,
        admission: resumed,
      );
      final inventory =
          (opened as Ok<SecretsInventory, DatabaseOpenFailure>).value;
      expect(await inventory.resumeUnprotected(), isA<Err>());
      final wrong = await inventory.unlock('${candidate}0');
      expect(wrong.fold((attempt) => attempt.accepted, (_) => true), isFalse);
      expect(await inventory.listWallets(), isA<Err>());
      final correct = await inventory.unlock(candidate);
      expect(correct.fold((attempt) => attempt.accepted, (_) => false), isTrue);
      expect(await inventory.listWallets(), isA<Ok>());
    } finally {
      await resumed.close();
    }
  });

  test(
    'an admitted inventory picks up a PIN subsequently set by Access',
    () async {
      _createSource(source);
      await admitBeforeCatalog(OwnerOrigin.legacy);

      final pin = Random.secure().nextInt(100000000).toString().padLeft(8, '0');
      final keychain = OwnerKeychain();
      _expectOk(await keychain.write(OwnerKey.pin, pin));
      _expectOk(await keychain.write(OwnerKey.attempts, '2'));

      final admission = await runtime();
      try {
        Future<SecretsInventory> open() async => (await SecretsInventory.open(
          file: destination,
          admission: admission,
        ) as Ok<SecretsInventory, DatabaseOpenFailure>).value;

        final inventory = await open();
        expect(
          (await inventory.isProtected()).fold((v) => v, (_) => null),
          isTrue,
        );
        expect(await inventory.listWallets(), isA<Err>());
        expect(await inventory.resumeUnprotected(), isA<Err>());
        expect(
          (await inventory.accessStatus()).fold(
            (v) => v.failedAttempts,
            (_) => -1,
          ),
          2,
        );
        expect(
          (await inventory.unlock('${pin}0'))
              .fold((v) => v.accepted, (_) => null),
          isFalse,
        );
        expect(
          (await inventory.unlock(pin)).fold((v) => v.accepted, (_) => null),
          isTrue,
        );
        _expectOk(await inventory.removeCredential());
        await inventory.close();

        final reopened = await open();
        expect(
          (await reopened.isProtected()).fold((v) => v, (_) => null),
          isFalse,
        );
        expect(await reopened.listWallets(), isA<Ok>());
        expect(
          (await keychain.read(OwnerKey.pin))
              .fold((v) => v == pin, (_) => false),
          isTrue,
        );
      } finally {
        await admission.close();
      }
    },
  );

  test('a prior fresh admission picks up a PIN and a later cooldown', () async {
    await admitBeforeCatalog(OwnerOrigin.fresh);
    final keychain = OwnerKeychain();
    final pin = Random.secure().nextInt(100000000).toString().padLeft(8, '0');
    final deadline = DateTime.now().add(const Duration(minutes: 1));
    _expectOk(await keychain.write(OwnerKey.pin, pin));
    _expectOk(await keychain.write(OwnerKey.attempts, '4'));
    _expectOk(
      await keychain.write(
        OwnerKey.lockedUntil,
        deadline.millisecondsSinceEpoch.toString(),
      ),
    );
    final admission = await runtime();
    try {
      final opened = await SecretsInventory.open(
        file: destination,
        admission: admission,
      );
      final inventory =
          (opened as Ok<SecretsInventory, DatabaseOpenFailure>).value;
      final status = await inventory.accessStatus();
      expect(status.fold((v) => v.failedAttempts, (_) => -1), 4);
      expect(
        status.fold((v) => v.lockedUntil?.millisecondsSinceEpoch, (_) => null),
        deadline.millisecondsSinceEpoch,
      );
      expect(
        (await inventory.unlock(pin)).fold((v) => v.accepted, (_) => null),
        isFalse,
      );
      expect(await inventory.listWallets(), isA<Err>());
    } finally {
      await admission.close();
    }
  });

  test('a native PIN survives a stale keychain on a fresh receipt', () async {
    await admitBeforeCatalog(OwnerOrigin.fresh);
    final pin = Random.secure().nextInt(100000000).toString().padLeft(8, '0');
    final admission = await runtime();
    try {
      Future<SecretsInventory> open() async => (await SecretsInventory.open(
        file: destination,
        admission: admission,
      ) as Ok<SecretsInventory, DatabaseOpenFailure>).value;
      final inventory = await open();
      _expectOk(await inventory.setCredential(pin));
      await inventory.close();
      await writeReceipt(admission, 'fresh-v1/secrets');
      _expectOk(await OwnerKeychain().write(OwnerKey.pin, '${pin}0'));

      final reopened = await open();
      expect(await reopened.listWallets(), isA<Err>());
      expect(
        (await reopened.unlock(pin)).fold((v) => v.accepted, (_) => null),
        isTrue,
      );
    } finally {
      await admission.close();
    }
  });

  test(
    'the initial view retains a stored secret without wallet usage',
    () async {
      _createSource(source);
      final orphan = Fingerprint('abcdef01');
      FakeSecureStoragePlatform(
        entries: {
          FlutterSecureStorageDatasource.keyForSecret(orphan): 'unreadable',
        },
      ).install();
      final migration = await exclusive();
      try {
        final owner = await prepare(migration, OwnerOrigin.legacy);
        expect(await owner.importLegacy(LegacySource(source, 16)), isA<Ok>());
        expect(await owner.close(), isA<Ok>());
      } finally {
        await migration.close();
      }

      final resumed = await runtime();
      try {
        final opened = await InventoryStore.open(
          destination,
          resumed,
          existing: true,
        );
        final store = (opened as Ok<InventoryStore, DatabaseOpenFailure>).value;
        final members = await store.database
            .select(store.database.viewMembers)
            .get();
        expect(
          members.map((row) => (row.viewId, row.member)),
          contains(('all', 'secret:${orphan.hex}')),
        );
      } finally {
        await resumed.close();
      }
    },
  );

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

  test('fresh initialization ignores orphaned access keys', () async {
    final keychain = OwnerKeychain();
    final pin = Random.secure().nextInt(100000000).toString();
    _expectOk(await keychain.write(OwnerKey.pin, pin));
    _expectOk(await keychain.write(OwnerKey.attempts, '5'));
    final exclusiveAdmission = await exclusive();
    try {
      final owner = await prepare(exclusiveAdmission, OwnerOrigin.fresh);
      _expectOk(await owner.initializeFresh());
      _expectOk(await owner.close());
    } finally {
      await exclusiveAdmission.close();
    }
    final admission = await runtime();
    try {
      final opened = await SecretsInventory.open(
        file: destination,
        admission: admission,
      );
      final inventory =
          (opened as Ok<SecretsInventory, DatabaseOpenFailure>).value;
      expect(
        (await inventory.isProtected()).fold((value) => value, (_) => true),
        isFalse,
      );
      expect(
        (await inventory.accessStatus()).fold(
          (value) => value.failedAttempts,
          (_) => -1,
        ),
        0,
      );
      expect(
        (await inventory.listWallets()).fold(
          (value) => value.isEmpty,
          (_) => false,
        ),
        isTrue,
      );
    } finally {
      await admission.close();
    }
    expect(
      (await keychain.read(OwnerKey.pin))
          .fold((value) => value == pin, (_) => false),
      isTrue,
    );
  });

  test(
    'a malformed seed key does not prevent import after a failed read',
    () async {
      _createSource(source);
      final storage = _InventoryReadFailure()..install();
      final admission = await exclusive();
      try {
        final owner = await prepare(admission, OwnerOrigin.legacy);
        final legacy = LegacySource(source, 16);
        expect(
          await owner.importLegacy(legacy),
          isA<Err<void, LegacyImportFailure>>().having(
            (result) => result.failure,
            'failure',
            isA<LegacyImportUnavailable>(),
          ),
        );
        expect(
          (await owner.receipt()).fold((value) => value, (_) => null),
          OwnerReadiness.pending,
        );
        storage.failed = false;
        _expectOk(await owner.importLegacy(legacy));
        expect(
          (await owner.receipt()).fold((value) => value, (_) => null),
          OwnerReadiness.imported,
        );
        _expectOk(await owner.close());
      } finally {
        await admission.close();
      }
    },
  );
}

void _expectOk(Result<void, Failure> result) => expect(result, isA<Ok>());

final class _InventoryReadFailure extends FakeSecureStoragePlatform {
  bool failed = true;

  _InventoryReadFailure() : super(entries: {'seed_invalid': 'unreadable'});

  @override
  Future<Map<String, String>> readAll({
    required Map<String, String> options,
  }) async {
    if (failed) throw PlatformException(code: 'inventory-unavailable');
    return super.readAll(options: options);
  }
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
