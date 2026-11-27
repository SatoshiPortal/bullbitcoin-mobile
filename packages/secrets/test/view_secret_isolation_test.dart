import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/storage.dart';
import 'package:secrets/testing.dart' show overrideMultiViewForTests;

import 'support/view_fixture.dart';

/// A seed is one entry of the keystore, not of a view. What a view may find,
/// list, test for or delete is decided by its membership.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ViewFixture fixture;
  late SessionAuthority authority;
  late SecretsInventory inventory;
  late Secrets secrets;
  late Fingerprint inA;
  late Fingerprint inB;

  setUp(() async {
    overrideMultiViewForTests(true);
    fixture = await ViewFixture.create();
    await fixture.sql([
      "INSERT INTO views (id, name, background_enabled) VALUES ('b', 'B', 1)",
    ]);
    authority = SessionAuthority();
    inventory = ok(
      await SecretsInventory.open(
        file: fixture.file,
        admission: fixture.admission,
        authority: authority,
      ),
    );
    secrets = Secrets(
      scratchDirectory: () async => fixture.directory.path,
      authority: authority,
    );
    authority.grant('all');
    inA = ok(await secrets.generate()).id;
    ok(
      await inventory.registerWallet(
        viewWallet('a', signer: 'local', fingerprint: inA.hex),
      ),
    );
    authority.grant('b');
    inB = ok(await secrets.generate()).id;
    ok(
      await inventory.registerWallet(
        viewWallet('b', signer: 'local', fingerprint: inB.hex),
      ),
    );
  });

  tearDown(() async {
    overrideMultiViewForTests(null);
    await inventory.close();
    await fixture.close();
  });

  test('fetch, exists and list show a view its own secrets only', () async {
    expect(ok(await secrets.fetch(inB)).id, inB);
    expect(
      (await secrets.fetch(inA) as Err<Secret, SecretFailure>).failure,
      isA<SecretNotFoundFailure>(),
    );
    expect(ok(await secrets.exists(inA)), isFalse);
    expect(ok(await secrets.exists(inB)), isTrue);
    final listed = ok(await secrets.list())
        .whereType<Secret>()
        .map((s) => s.id);
    expect(listed, [inB]);
  });

  test('a view cannot delete the secret of another', () async {
    expect(await secrets.trash(inA), isA<Err>());
    authority.grant('all');
    expect(ok(await secrets.fetch(inA)).id, inA);
  });

  test('a secret the session just made is usable before it is registered, '
      'and only in that session', () async {
    final fresh = ok(await secrets.generate()).id;
    expect(ok(await secrets.fetch(fresh)).id, fresh);
    authority.grant('b');
    expect(await secrets.fetch(fresh), isA<Err>());
  });

  test('a seed whose words the session supplies is found', () async {
    final words = List<String>.filled(11, 'zoo') + ['wrong'];
    final imported = ok(
      await secrets.import(words: words, language: Language.english),
    );
    authority.grant('all');
    expect(await secrets.fetch(imported.id), isA<Err>());
    final found = ok(
      await secrets.find(words: words, language: Language.english),
    );
    expect(found?.id, imported.id);
    expect(ok(await secrets.fetch(imported.id)).id, imported.id);
  });
}
