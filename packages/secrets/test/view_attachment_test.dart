import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart'
    show SecretFailure, SecretOwnedByAnotherViewFailure;
import 'package:secrets/storage.dart';

import 'support/view_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ViewFixture fixture;
  late SessionAuthority authority;
  late SecretsInventory inventory;
  final owned = viewWallet('owned', signer: 'local', fingerprint: 'aaaaaaaa');

  setUp(() async {
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
        multiView: true,
      ),
    );
    authority.grant('all');
    ok(await inventory.registerWallet(owned));
  });

  tearDown(() async {
    await inventory.close();
    await fixture.close();
  });

  test('a view cannot claim the secret another view holds by naming its '
      'fingerprint', () async {
    authority.grant('b');
    // A second wallet that only repeats the public fingerprint of view A's
    // seed: it must not make that seed a member of view B.
    final claim = viewWallet(
      'claim',
      signer: 'local',
      fingerprint: 'aaaaaaaa',
      network: 'bitcoinRegtest',
    );
    final result = await inventory.registerWallet(claim);
    expect(
      (result as Err<void, SecretFailure>).failure,
      isA<SecretOwnedByAnotherViewFailure>(),
    );
    expect(ok(await inventory.listWallets()), isEmpty);
    expect(ok(await inventory.referencedFingerprints()), isEmpty);
    expect(ok(await inventory.findWallet(owned.id)), isNull);

    authority.grant('all');
    expect(ok(await inventory.listWallets()).map((w) => w.id), [owned.id]);
  });

  test('a secret still registers in the view that holds it', () async {
    final sibling = viewWallet(
      'sibling',
      signer: 'local',
      fingerprint: 'aaaaaaaa',
      network: 'bitcoinMainnet',
    );
    ok(await inventory.registerWallet(sibling));
    expect(ok(await inventory.listWallets()), hasLength(2));
  });

  test('a secret nobody holds registers in the active view', () async {
    authority.grant('b');
    ok(
      await inventory.registerWallet(
        viewWallet('fresh', signer: 'local', fingerprint: 'bbbbbbbb'),
      ),
    );
    expect(ok(await inventory.referencedFingerprints()).map((f) => f.hex), [
      'bbbbbbbb',
    ]);
  });
}
