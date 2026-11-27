import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:legacy_storage/coordination.dart';
import 'package:legacy_storage/legacy_storage.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/migration.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/src/data/inventory_store.dart';
import 'package:secrets/storage.dart';
import 'package:secrets/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;
  late RuntimeAdmission admission;
  late File file;
  late SecretsInventory inventory;
  late ArkBackgroundAccess authority;
  late InventoryStore store;
  late Secrets secrets;
  late Fingerprint parent;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('ark-renewal-');
    FakeSecureStoragePlatform().install();
    file = File('${directory.path}/secrets.sqlite');
    final gate = NativeFileGate(File('${directory.path}/gate'));
    final participant = SecretsImport(file: file);
    final exclusive = await gate.acquire(
      exclusive: true,
      timeout: Duration.zero,
    ) as ExclusiveAdmission;
    try {
      final result = await participant.prepare(exclusive, OwnerOrigin.fresh);
      final owner = (result as Ok<PreparedOwner, LegacyImportFailure>).value;
      expect(await owner.initializeFresh(), isA<Ok>());
      expect(await owner.close(), isA<Ok>());
    } finally {
      await exclusive.close();
    }
    admission = await gate.acquire(
      exclusive: false,
      timeout: Duration.zero,
    ) as RuntimeAdmission;
    inventory = _value(
      await SecretsInventory.open(
        authority: SessionAuthority(),
        file: file,
        admission: admission,
      ),
    );
    authority = _value(
      await ArkBackgroundAccess.open(file: file, admission: admission),
    );
    store = _value(await InventoryStore.open(file, admission, existing: true));
    secrets = Secrets(
      authority: unlockedSessionAuthority(),
      scratchDirectory: () async => directory.path,
    );
    final secret = _value(await secrets.generate());
    parent = secret.id;
    final id = 'wpkh([${parent.hex}/84h/1h/0h]):regtest';
    _value(
      await inventory.registerWallet(
        RegisteredWallet(
          id: id,
          secretFingerprint: parent.hex,
          masterFingerprint: parent.hex,
          signer: 'local',
          network: 'bitcoinRegtest',
          xpub: 'public-marker',
          externalDescriptor: 'wpkh(public-marker/0/*)',
          internalDescriptor: 'wpkh(public-marker/1/*)',
          label: null,
          birthday: null,
          isDefault: true,
        ),
      ),
    );
  });

  tearDown(() async {
    await authority.close();
    await store.close();
    await admission.close();
    await directory.delete(recursive: true);
  });

  Future<void> sql(String statement) =>
      store.database.customStatement(statement);

  Future<void> protect(String view) async {
    await sql(
      "INSERT OR IGNORE INTO credentials (id, scheme, salt, params, verifier) "
      "VALUES ('c-$view', 'test', x'00', '{}', x'00')",
    );
    await sql("UPDATE views SET credential_id = 'c-$view' WHERE id = '$view'");
  }

  Future<void> addView(String view, {bool background = true}) async {
    await sql(
      "INSERT INTO views (id, name, background_enabled) "
      "VALUES ('$view', '$view', ${background ? 1 : 0})",
    );
    await sql(
      "INSERT INTO view_members (view_id, member) "
      "VALUES ('$view', 'secret:${parent.hex}')",
    );
  }

  test(
    'an unprotected view with background access permits its own parent',
    () async {
      expect(await authority.mayNotify(parent), isTrue);
    },
  );

  test('the exact owner is decided: no membership is a refusal', () async {
    expect(await authority.mayNotify(Fingerprint('01234567')), isFalse);
    expect(await authority.mayNotify(parent), isTrue);
  });

  test('background access disabled refuses, enabled permits again', () async {
    await sql("UPDATE views SET background_enabled = 0 WHERE id = 'all'");
    expect(await authority.mayNotify(parent), isFalse);
    await sql("UPDATE views SET background_enabled = 1 WHERE id = 'all'");
    expect(await authority.mayNotify(parent), isTrue);
  });

  test('a seed shared with a protected view is refused', () async {
    await addView('protected');
    await protect('protected');
    expect(await authority.mayNotify(parent), isFalse);
  });

  test('a PIN set between two asks refuses the second', () async {
    expect(await authority.mayNotify(parent), isTrue);
    await protect('all');
    expect(await authority.mayNotify(parent), isFalse);
  });

  test('a policy that cannot be read is a refusal', () async {
    await sql('DROP TABLE view_members');
    expect(await authority.mayNotify(parent), isFalse);
  });

  test(
    'the answer is a bool: no seed is read, even for a missing seed',
    () async {
      _value(await secrets.trash(parent));
      expect(await authority.mayNotify(parent), isTrue);
    },
  );
  test('the foreground inventory answers like the background access', () async {
    expect(
      await inventory.mayNotifyArk(parent),
      await authority.mayNotify(parent),
    );
    expect(await inventory.mayNotifyArk(parent), isTrue);
    expect(await inventory.mayNotifyArk(Fingerprint('01234567')), isFalse);
    await protect('all');
    expect(await inventory.mayNotifyArk(parent), isFalse);
    expect(
      await inventory.mayNotifyArk(parent),
      await authority.mayNotify(parent),
    );
  });
}

T _value<T, F extends Failure>(Result<T, F> result) {
  expect(result, isA<Ok<T, F>>());
  return (result as Ok<T, F>).value;
}
