import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:legacy_storage/coordination.dart';
import 'package:legacy_storage/legacy_storage.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/migration.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/src/data/inventory_store.dart';
import 'package:secrets/ark_renewal.dart';
import 'package:secrets/storage.dart';
import 'package:secrets/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;
  late RuntimeAdmission admission;
  late File file;
  late SecretsInventory inventory;
  late ArkRenewalSecrets renewal;
  late FakeSecureStoragePlatform keystore;
  late InventoryStore store;
  late Secrets secrets;
  late Fingerprint parent;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('ark-renewal-secrets-');
    keystore = FakeSecureStoragePlatform()..install();
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
    renewal = _value(
      await ArkRenewalSecrets.open(file: file, admission: admission),
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
    await renewal.close();
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

  Future<Result<String, Failure>> refresh({
    Fingerprint? of,
    void Function(ArkChild child)? onAction,
  }) => renewal.withArkChild<String, Failure>(
    parent: of ?? parent,
    notPermitted: const _Refused(),
    unavailable: const _Unavailable(),
    action: (child) async {
      onAction?.call(child);
      return Ok(child.fingerprint.hex);
    },
  );

  test('only the Ark child of the exact account is handed over', () async {
    final handle = _value(await secrets.fetch(parent));
    final expectedWords = _value(
      await handle.derive.bip85.mnemonic(
        wordCount: MnemonicLength.words12,
        index: arkChildBip85Index,
        language: Language.english,
      ),
    );
    final expectedFingerprint = _value(
      await secrets.preview.arkFingerprint(words: expectedWords),
    );

    ArkChild? seen;
    final result = _value(await refresh(onAction: (child) => seen = child));

    expect(result, expectedFingerprint.hex);
    expect(seen?.mnemonic, expectedWords.join(' '));
    expect(seen?.fingerprint, expectedFingerprint);
    expect(
      seen?.fingerprint,
      isNot(parent),
      reason: 'the child is not the parent seed',
    );
  });

  test(
    'a view protected by a PIN is renewed: the veto is lifted for refresh',
    () async {
      await protect('all');
      expect(_value(await refresh()), isNotEmpty);
      expect(await renewal.mayRefresh(parent), isTrue);
    },
  );

  test('a seed shared with a protected view is still renewed', () async {
    await addView('protected');
    await protect('protected');
    expect(_value(await refresh()), isNotEmpty);
  });

  test('background access disabled refuses and reads no seed', () async {
    await sql("UPDATE views SET background_enabled = 0 WHERE id = 'all'");
    final baseline = keystore.reads;
    var ran = false;
    expect(
      _failure(await refresh(onAction: (_) => ran = true)),
      isA<_Refused>(),
    );
    expect(ran, isFalse);
    expect(keystore.reads, baseline);
    expect(await renewal.mayRefresh(parent), isFalse);
  });

  test(
    'two accounts: one without membership is refused, the other renewed',
    () async {
      final stranger = Fingerprint('01234567');
      final baseline = keystore.reads;
      expect(_failure(await refresh(of: stranger)), isA<_Refused>());
      expect(
        keystore.reads,
        baseline,
        reason: 'the refused account reads nothing',
      );
      expect(_value(await refresh()), isNotEmpty);
    },
  );

  test(
    'a policy that cannot be read is unavailable and reads no seed',
    () async {
      await sql('DROP TABLE view_members');
      final baseline = keystore.reads;
      var ran = false;
      expect(
        _failure(await refresh(onAction: (_) => ran = true)),
        isA<_Unavailable>(),
      );
      expect(ran, isFalse);
      expect(keystore.reads, baseline);
      expect(await renewal.mayRefresh(parent), isFalse);
    },
  );

  test('a missing seed is unavailable, not a refusal', () async {
    _value(await secrets.trash(parent));
    expect(_failure(await refresh()), isA<_Unavailable>());
  });

  test(
    'the policy is read again for every lot: a revocation stops the next one',
    () async {
      expect(await renewal.mayRefresh(parent), isTrue, reason: 'first lot');
      await sql("UPDATE views SET background_enabled = 0 WHERE id = 'all'");
      expect(await renewal.mayRefresh(parent), isFalse, reason: 'second lot');
    },
  );

  test(
    'an admitted run is not interrupted, the next admission sees the change',
    () async {
      final admitted = Completer<void>();
      final release = Completer<void>();
      final running = renewal.withArkChild<String, Failure>(
        parent: parent,
        notPermitted: const _Refused(),
        unavailable: const _Unavailable(),
        action: (child) async {
          admitted.complete();
          await release.future;
          return Ok(child.fingerprint.hex);
        },
      );
      await admitted.future;
      await sql("UPDATE views SET background_enabled = 0 WHERE id = 'all'");
      expect(_failure(await refresh()), isA<_Refused>());
      release.complete();
      expect(_value(await running), isNotEmpty);
    },
  );

  test('the SQLite write lock is not held while the action runs', () async {
    final admitted = Completer<void>();
    final release = Completer<void>();
    final running = renewal.withArkChild<String, Failure>(
      parent: parent,
      notPermitted: const _Refused(),
      unavailable: const _Unavailable(),
      action: (child) async {
        admitted.complete();
        await release.future;
        return Ok(child.fingerprint.hex);
      },
    );
    await admitted.future;
    // A write during the "network" must not wait for the action.
    await protect('all').timeout(const Duration(seconds: 5));
    release.complete();
    expect(_value(await running), isNotEmpty);
  });
}

final class _Refused extends Failure {
  const _Refused();
}

final class _Unavailable extends Failure {
  const _Unavailable();
}

T _value<T, F extends Failure>(Result<T, F> result) {
  expect(result, isA<Ok<T, F>>());
  return (result as Ok<T, F>).value;
}

Failure _failure<T, F extends Failure>(Result<T, F> result) {
  expect(result, isA<Err<T, F>>());
  return (result as Err<T, F>).failure;
}
