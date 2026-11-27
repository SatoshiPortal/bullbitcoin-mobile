import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/storage.dart';

import 'support/view_fixture.dart';

/// The isolation suite of the multiple views (D63, D69, D96): what one view can
/// reach of another, through every capability this package publishes. Each
/// test fixes one side of the line; the gate stays closed in production.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ViewFixture fixture;
  late SessionAuthority authority;
  late SecretsInventory inventory;
  late Secrets secrets;
  late Fingerprint inA;
  late Fingerprint inB;

  setUp(() async {
    fixture = await ViewFixture.create();
    await fixture.sql([
      "INSERT INTO views (id, name, background_enabled) VALUES ('b', 'B', 0)",
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
    ok(await inventory.registerWallet(viewWallet('a-watch')));
    authority.grant('b');
    inB = ok(await secrets.generate()).id;
    ok(
      await inventory.registerWallet(
        viewWallet('b', signer: 'local', fingerprint: inB.hex),
      ),
    );
  });

  tearDown(() async {
    await inventory.close();
    await fixture.close();
  });

  group('BIP85 children', () {
    test(
      'are listed and reserved only for the view that holds the parent',
      () async {
        ok(await inventory.reserveHexDerivation(parent: inB, length: 32));
        expect(ok(await inventory.listDerivations()), hasLength(1));
        authority.grant('all');
        expect(ok(await inventory.listDerivations()), isEmpty);
        final foreign = await inventory.reserveHexDerivation(
          parent: inB,
          length: 32,
        );
        expect(foreign, isA<Err>());
        expect(
          ok(await inventory.listDerivations()),
          isEmpty,
          reason: 'a refused reservation writes nothing',
        );
      },
    );
  });

  group('background', () {
    Future<List<String>> background() async {
      final catalog = ok(
        await BackgroundWalletDescriptors.open(
          file: fixture.file,
          admission: fixture.admission,
          multiView: true,
        ),
      );
      try {
        return ok(await catalog.list()).map((d) => d.id).toList()..sort();
      } finally {
        await catalog.close();
      }
    }

    test(
      'a view with the grant off never leaves the descriptor list',
      () async {
        final ids = await background();
        expect(
          ids,
          contains(viewWallet('a', signer: 'local', fingerprint: inA.hex).id),
        );
        expect(
          ids,
          isNot(
            contains(viewWallet('b', signer: 'local', fingerprint: inB.hex).id),
          ),
        );
      },
    );

    test('turning the grant back on adds exactly that view', () async {
      ok(await inventory.setBackgroundEnabled(true));
      expect(await background(), hasLength(3));
      ok(await inventory.setBackgroundEnabled(false));
      expect(await background(), hasLength(2));
    });

    test('Ark reminders follow the same rule through every view that holds '
        'the seed', () async {
      final catalog = ok(
        await ArkBackgroundAccess.open(
          file: fixture.file,
          admission: fixture.admission,
          multiView: true,
        ),
      );
      try {
        expect(await catalog.mayNotify(inA), isTrue);
        expect(await catalog.mayNotify(inB), isFalse, reason: 'grant off');
        ok(await inventory.setBackgroundEnabled(true));
        expect(await catalog.mayNotify(inB), isTrue);
        await fixture.sql([
          "INSERT INTO credentials (id, scheme, salt, params, verifier) VALUES ('pin', 's', x'00', 'p', x'00')",
          "UPDATE views SET credential_id = 'pin' WHERE id = 'b'",
        ]);
        expect(
          await catalog.mayNotify(inB),
          isFalse,
          reason: 'a protected view never lets its seed notify',
        );
        expect(await catalog.mayNotify(inA), isTrue);
      } finally {
        await catalog.close();
      }
    });
  });

  group('custody', () {
    test('seeds still count as held by the other view, by design', () async {
      final held = ok(await inventory.getCustodyFingerprints()) as Set;
      expect(held, containsAll([inA, inB]));
      authority.grant('all');
      expect(ok(await inventory.referencedFingerprints()), [inA]);
    });
  });

  group('the session', () {
    test('nothing is readable while locked', () async {
      await inventory.lock();
      expect(await inventory.listWallets(), isA<Err>());
      expect(await secrets.list(), isA<Err>());
      expect(await secrets.fetch(inA), isA<Err>());
    });

    test('a handle taken in one view dies when the other opens', () async {
      final handle = ok(await secrets.fetch(inB));
      authority.grant('all');
      final result = await handle.derive.xpub(
        network: BitcoinNetwork.testnet,
        scriptType: ScriptType.bip84,
      );
      expect(result, isA<Err>());
    });
  });
}
