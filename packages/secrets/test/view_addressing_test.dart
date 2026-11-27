import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/storage.dart';
import 'package:secrets/testing.dart' show overrideMultiViewForTests;

import 'support/view_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ViewFixture fixture;
  late SessionAuthority authority;
  late SecretsInventory inventory;
  final aPublic = viewWallet('a-public');
  final aLocal = viewWallet(
    'a-local',
    signer: 'local',
    fingerprint: 'aaaaaaaa',
  );
  final bPublic = viewWallet('b-public');
  final bLocal = viewWallet(
    'b-local',
    signer: 'local',
    fingerprint: 'bbbbbbbb',
  );

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
    authority.grant('all');
    ok(await inventory.registerWallet(aPublic));
    ok(await inventory.registerWallet(aLocal));
    authority.grant('b');
    ok(await inventory.registerWallet(bPublic));
    ok(await inventory.registerWallet(bLocal));
  });

  tearDown(() async {
    overrideMultiViewForTests(null);
    await inventory.close();
    await fixture.close();
  });

  Future<List<String>> ids() async =>
      ok(await inventory.listWallets()).map((w) => w.id).toList();

  test('every read of the active view stays inside it', () async {
    expect(await ids(), [bLocal.id, bPublic.id]..sort());
    expect(ok(await inventory.findWallet(aPublic.id)), isNull);
    expect(ok(await inventory.findWallet(bPublic.id)), isNotNull);
    expect(await inventory.readWallet(aLocal.id), isA<Err>());
    expect(ok(await inventory.referencedFingerprints()).map((f) => f.hex), [
      'bbbbbbbb',
    ]);
    expect(
      ok(await inventory.listDescriptors()).map((d) => d.id),
      [bLocal.id, bPublic.id]..sort(),
    );
    expect(
      ok(await inventory.walletsForNetwork(BitcoinNetwork.testnet)).wallets
          .map((w) => w.id),
      [bLocal.id, bPublic.id]..sort(),
    );

    authority.grant('all');
    expect(await ids(), [aLocal.id, aPublic.id]..sort());
  });

  test('a write names no view and cannot reach another one', () async {
    expect(
      await inventory.setWalletProperties(
        id: aPublic.id,
        label: 'taken',
        birthday: null,
        isDefault: false,
      ),
      isA<Err>(),
    );
    expect(await inventory.removeWallet(aPublic.id), isA<Err>());
    authority.grant('all');
    final wallet = ok(await inventory.findWallet(aPublic.id))!;
    expect(wallet.label, 'label-a-public');
  });

  test('the foreground sees only its own view while the background sees every '
      'view that allows it', () async {
    ok(await inventory.setBackgroundEnabled(false));
    final background = ok(
      await BackgroundWalletDescriptors.open(
        file: fixture.file,
        admission: fixture.admission,
      ),
    );
    try {
      final list = ok(await background.list());
      expect(list.map((d) => d.id), [aLocal.id, aPublic.id]..sort());
    } finally {
      await background.close();
    }
  });
}
