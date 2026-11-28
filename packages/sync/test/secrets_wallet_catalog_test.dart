import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/storage.dart';
import 'package:sync/inventory.dart';
import 'package:sync/sync.dart';

import '../../secrets/test/support/view_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'an authority refuses an equal-generation token from another instance',
    () {
      final authority = SessionAuthority();
      final own = replaceGrant(authority, 'all');
      final foreign = replaceGrant(SessionAuthority(), 'all');

      expect(own.generation, foreign.generation);
      expect(own.activeView, foreign.activeView);
      expect(authority.isCurrent(foreign), isFalse);
    },
  );

  multiViewSuite(() {
    final shared = viewWallet('shared');
    final privateA = viewWallet('private-a', signer: 'local');
    final watchA = viewWallet('watch-a');
    final privateB = viewWallet('private-b');
    final sharedKey = WalletKey(id: shared.id, network: BitcoinNetwork.testnet);
    final watchAKey = WalletKey(id: watchA.id, network: BitcoinNetwork.testnet);
    late ViewFixture fixture;
    late SessionAuthority authority;
    late SecretsInventory inventory;
    late SecretsWalletCatalog catalog;

    setUp(() async {
      fixture = await ViewFixture.create();
      addTearDown(fixture.close);
      await fixture.sql([
        "INSERT INTO views (id, name, background_enabled) VALUES ('b', 'Bravo', 0)",
      ]);
      authority = SessionAuthority();
      inventory = ok(
        await SecretsInventory.open(
          file: fixture.file,
          admission: fixture.admission,
          authority: authority,
        ),
      );
      addTearDown(inventory.close);
      await inventory.insertWalletInViewForTesting(view: 'all', wallet: shared);
      await inventory.insertWalletInViewForTesting(
        view: 'all',
        wallet: privateA,
      );
      await inventory.insertWalletInViewForTesting(view: 'all', wallet: watchA);
      await inventory.insertWalletInViewForTesting(view: 'b', wallet: privateB);
      await inventory.shareWalletWithViewForTesting(
        view: 'b',
        walletId: shared.id,
      );
      catalog = SecretsWalletCatalog.foreground(inventory);
    });

    test('list and find discard results after A1 to B to A2', () async {
      // Hold both results at their first asynchronous inventory read: there
      // is no yield to either caller between starting the reads and replacing
      // the authority twice.
      final listing = catalog.list();
      final finding = catalog.find(sharedKey);
      replaceGrant(authority, 'b');
      replaceGrant(authority, 'all');

      expectClosed(await listing);
      expectClosed(await finding);
      expect(ok(await catalog.find(sharedKey)).key, sharedKey);
      expect(
        ok(await catalog.list()).map((row) => row.key.id),
        unorderedEquals([shared.id, privateA.id, watchA.id]),
      );
    });

    test('a bound catalog cannot follow replacement or revocation', () async {
      final session = present(catalog.foregroundSession);
      final a1 = present(session.capture());
      final boundA1 = present(catalog.captureForeground(a1));
      expect(ok(await boundA1.find(sharedKey)).key, sharedKey);
      final observed = <SessionToken?>[];
      final subscription = session.changes.listen(observed.add);
      addTearDown(subscription.cancel);

      final foreign = replaceGrant(SessionAuthority(), 'all');
      expect(foreign.generation, a1.generation);
      expect(session.isCurrent(foreign), isFalse);
      expect(catalog.captureForeground(foreign), isNull);
      expect(await inventory.listDescriptorsFor(foreign), isA<Err>());

      final listing = boundA1.list();
      final finding = boundA1.find(sharedKey);
      final descriptors = inventory.listDescriptorsFor(a1);
      // No native wallet lifecycle change: the shared wallet is the same
      // catalog entry for every grant, including the later grant to A.
      final b = replaceGrant(authority, 'b');
      final a2 = replaceGrant(authority, 'all');

      expectClosed(await listing);
      expectClosed(await finding);
      expect(await descriptors, isA<Err>());
      expectClosed(await boundA1.find(sharedKey));
      expectClosed(await boundA1.list());
      expect(catalog.captureForeground(a1), isNull);
      expect(session.capture(), same(a2));
      expect(session.isCurrent(a1), isFalse);
      final boundA2 = present(catalog.captureForeground(a2));
      expect(ok(await boundA2.find(sharedKey)).key, sharedKey);

      expect(await inventory.lock(), isTrue);
      expect(session.capture(), isNull);
      expect(catalog.captureForeground(a2), isNull);
      expectClosed(await boundA2.find(sharedKey));
      expect(observed, [b, a2, null]);
    });

    test(
      'foreground view selection and lock do not change background grants',
      () async {
        final background = ok(
          await BackgroundWalletDescriptors.open(
            file: fixture.file,
            admission: fixture.admission,
          ),
        );
        addTearDown(background.close);
        final worker = SecretsWalletCatalog.background(background);
        expect(worker.foregroundSession, isNull);
        expect(worker.captureForeground(present(authority.current)), isNull);
        final views = present(inventory.openedViews);
        ok(await views.activate(const ViewId('b')));

        expect(
          ok(await catalog.list()).map((row) => row.key.id),
          unorderedEquals([shared.id, privateB.id]),
        );
        final aKey = WalletKey(
          id: privateA.id,
          network: BitcoinNetwork.testnet,
        );
        final bKey = WalletKey(
          id: privateB.id,
          network: BitcoinNetwork.testnet,
        );
        expect(await catalog.find(aKey), isA<Err>());
        expect(await catalog.find(watchAKey), isA<Err>());
        expect(ok(await catalog.find(bKey)).key, bKey);

        expect(await inventory.lock(), isTrue);
        expectClosed(await catalog.list());
        expectClosed(await catalog.find(sharedKey));
        expect(
          ok(await worker.list()).map((row) => row.key.id),
          unorderedEquals([shared.id, privateA.id, watchA.id]),
        );
        expect(await worker.find(bKey), isA<Err>());
      },
    );
  });
}

void expectClosed<T>(Result<T, SyncFailure> result) {
  expect(
    result,
    isA<Err<T, SyncFailure>>().having(
      (result) => result.failure,
      'failure',
      isA<SyncClosedFailure>(),
    ),
  );
}
