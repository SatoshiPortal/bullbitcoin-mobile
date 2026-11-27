import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:legacy_storage/coordination.dart';
import 'package:legacy_storage/legacy_storage.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/migration.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/storage.dart';
import 'package:secrets/testing.dart';

/// A handle is the session it was issued in: once that session ended it never
/// reaches key material again, not even after the next unlock.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;
  late RuntimeAdmission admission;
  late SecretsInventory inventory;
  late Secrets secrets;
  late SessionAuthority authority;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('session-authority-');
    FakeSecureStoragePlatform().install();
    final file = File('${directory.path}/secrets.sqlite');
    final gate = NativeFileGate(File('${directory.path}/gate'));
    final exclusive = await gate.acquire(
      exclusive: true,
      timeout: Duration.zero,
    ) as ExclusiveAdmission;
    try {
      final prepared = await SecretsImport(file: file)
          .prepare(exclusive, OwnerOrigin.fresh);
      final owner = (prepared as Ok<PreparedOwner, LegacyImportFailure>).value;
      expect(await owner.initializeFresh(), isA<Ok>());
      expect(await owner.close(), isA<Ok>());
    } finally {
      await exclusive.close();
    }
    admission = await gate.acquire(
      exclusive: false,
      timeout: Duration.zero,
    ) as RuntimeAdmission;
    authority = SessionAuthority();
    inventory = _value(
      await SecretsInventory.open(
        file: file,
        admission: admission,
        authority: authority,
      ),
    );
    secrets = Secrets(
      scratchDirectory: () async => directory.path,
      authority: authority,
    );
  });

  tearDown(() async {
    await inventory.close();
    await admission.close();
    await directory.delete(recursive: true);
  });

  Future<Result<String, SecretFailure>> xpub(Secret secret) => secret.derive
      .xpub(network: BitcoinNetwork.mainnet, scriptType: ScriptType.bip84);

  test(
    'a handle of a past session is refused, even after a new unlock',
    () async {
      final generated = _value(await secrets.generate());
      final fetched = _value(await secrets.fetch(generated.id));
      final listed = _value(await secrets.list()).whereType<Secret>().single;
      expect(_value(await xpub(fetched)), isNotEmpty);

      await inventory.lock();

      for (final handle in [generated, fetched, listed]) {
        expect(
          (await xpub(handle) as Err<String, SecretFailure>).failure,
          isA<UseSecretFailure>(),
        );
      }

      _value(await inventory.resumeUnprotected());
      for (final handle in [generated, fetched, listed]) {
        expect(
          await xpub(handle),
          isA<Err<String, SecretFailure>>(),
          reason: 'a new unlock is a new generation, not the old session',
        );
      }
      expect(
        _value(await xpub(_value(await secrets.fetch(generated.id)))),
        isNotEmpty,
      );
    },
  );

  test('a handle issued by import and by find follows the same rule', () async {
    final imported = _value(
      await secrets.import(
        words: 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about'
            .split(' '),
        language: Language.english,
      ),
    );
    await inventory.lock();
    expect(await xpub(imported), isA<Err<String, SecretFailure>>());
  });

  test('while locked nothing starts and nothing is listed', () async {
    final generated = _value(await secrets.generate());
    await inventory.lock();

    expect(await secrets.fetch(generated.id), isA<Err>());
    expect(await secrets.list(), isA<Err>());
    expect(await secrets.generate(), isA<Err>());
    expect(await secrets.exists(generated.id), isA<Err>());
  });

  test('a lock during a read keeps its result from being delivered', () async {
    final generated = _value(await secrets.generate());
    final reading = secrets.fetch(generated.id);
    await inventory.lock();
    expect(await reading, isA<Err<Secret, SecretFailure>>());
  });
}

T _value<T, F extends Failure>(Result<T, F> result) {
  expect(result, isA<Ok<T, F>>());
  return (result as Ok<T, F>).value;
}
