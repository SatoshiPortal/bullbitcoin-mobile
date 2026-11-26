import 'dart:async';
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

final class _Refused extends Failure {
  const _Refused();
}

final class _Unavailable extends Failure {
  const _Unavailable();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;
  late RuntimeAdmission admission;
  late File file;
  late SecretsInventory inventory;
  late ArkRenewalAuthority authority;
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
      await ArkRenewalAuthority.open(file: file, admission: admission),
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

  Future<Result<String, Failure>> renew({
    Fingerprint? of,
    void Function()? onAction,
  }) => authority.withRenewalChild<String, Failure>(
    parent: of ?? parent,
    notPermitted: const _Refused(),
    unavailable: const _Unavailable(),
    action: (mnemonic, child) async {
      onAction?.call();
      return Ok('$mnemonic|${child.hex}');
    },
  );

  test(
    'an unprotected view with background access derives the Ark child',
    () async {
      final handle = _value(await secrets.fetch(parent));
      final words = _value(
        await handle.derive.bip85.mnemonic(
          wordCount: MnemonicLength.words12,
          index: arkChildBip85Index,
          language: Language.english,
        ),
      );
      final expected = _value(
        await secrets.preview.arkFingerprint(words: words),
      );

      final result = _value(await renew());

      expect(result, '${words.join(' ')}|${expected.hex}');
    },
  );

  test('refusal reads no seed and never runs the action', () async {
    var ran = false;

    // Zero membership never satisfies "every view is unprotected".
    final stranger = Fingerprint('01234567');
    final none = await renew(of: stranger, onAction: () => ran = true);
    expect(_failure(none), isA<_Refused>());

    // Background access disabled for the only view.
    await sql("UPDATE views SET background_enabled = 0 WHERE id = 'all'");
    expect(_failure(await renew(onAction: () => ran = true)), isA<_Refused>());
    await sql("UPDATE views SET background_enabled = 1 WHERE id = 'all'");

    // The seed is shared with a protected view: protection wins.
    await addView('protected');
    await protect('protected');
    expect(_failure(await renew(onAction: () => ran = true)), isA<_Refused>());

    expect(ran, isFalse);
  });

  test('a protected default view is refused', () async {
    await protect('all');
    var ran = false;
    expect(_failure(await renew(onAction: () => ran = true)), isA<_Refused>());
    expect(ran, isFalse);
  });

  test(
    'a policy that cannot be read is not a refusal and reads nothing',
    () async {
      await sql('DROP TABLE view_members');
      var ran = false;
      expect(
        _failure(await renew(onAction: () => ran = true)),
        isA<_Unavailable>(),
      );
      expect(ran, isFalse);
    },
  );

  test('a missing seed is unavailable, not a refusal', () async {
    _value(await secrets.trash(parent));
    var ran = false;
    expect(
      _failure(await renew(onAction: () => ran = true)),
      isA<_Unavailable>(),
    );
    expect(ran, isFalse);
  });

  test('a batch admission reads the policy afresh and reads no seed', () async {
    expect(await authority.mayRenew(parent), isTrue);

    // A PIN set between two lots refuses the second one.
    await protect('all');
    expect(await authority.mayRenew(parent), isFalse);
  });

  test(
    'a batch admission is per account: one forbidden, one allowed',
    () async {
      final stranger = Fingerprint('01234567');
      expect(
        await authority.mayRenew(stranger),
        isFalse,
        reason: 'no membership',
      );
      expect(await authority.mayRenew(parent), isTrue);

      await addView('protected');
      await protect('protected');
      expect(
        await authority.mayRenew(parent),
        isFalse,
        reason: 'the seed is shared with a protected view',
      );
    },
  );

  test(
    'a batch admission fails closed when the policy cannot be read',
    () async {
      await sql('DROP TABLE view_members');
      expect(await authority.mayRenew(parent), isFalse);
    },
  );

  test(
    'a PIN set after admission does not interrupt the admitted run',
    () async {
      final admitted = Completer<void>();
      final release = Completer<void>();
      final running = authority.withRenewalChild<String, Failure>(
        parent: parent,
        notPermitted: const _Refused(),
        unavailable: const _Unavailable(),
        action: (mnemonic, child) async {
          admitted.complete();
          await release.future;
          return Ok(child.hex);
        },
      );
      await admitted.future;
      await protect('all');

      // The next admission sees the PIN.
      expect(_failure(await renew()), isA<_Refused>());

      release.complete();
      expect(_value(await running), isNotEmpty);
    },
  );
}

T _value<T, F extends Failure>(Result<T, F> result) {
  expect(result, isA<Ok<T, F>>());
  return (result as Ok<T, F>).value;
}

Failure _failure<T>(Result<T, Failure> result) {
  expect(result, isA<Err<T, Failure>>());
  return (result as Err<T, Failure>).failure;
}
