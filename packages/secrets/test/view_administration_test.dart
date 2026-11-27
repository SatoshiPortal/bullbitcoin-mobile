import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/storage.dart';
import 'package:secrets/testing.dart' show overrideMultiViewForTests;

import 'support/view_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('generation', generationTests);

  late ViewFixture fixture;
  late SessionAuthority authority;
  late SecretsInventory inventory;
  late Secrets secrets;
  late OpenedViews opened;
  late Fingerprint seed;

  Future<List<String>> names() async =>
      opened.views.map((view) => view.name).toList();

  setUp(() async {
    overrideMultiViewForTests(true);
    fixture = await ViewFixture.create();
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
    await inventory.lock();
    opened = ok(await inventory.authenticate('')).views!;
    seed = ok(await secrets.generate()).id;
    ok(
      await inventory.registerWallet(
        viewWallet('mine', signer: 'local', fingerprint: seed.hex),
      ),
    );
    ok(await inventory.registerWallet(viewWallet('watch')));
  });

  tearDown(() async {
    overrideMultiViewForTests(null);
    await inventory.close();
    await fixture.close();
  });

  test('a new view holds only what the view in use already holds', () async {
    final created = ok(
      await opened.administration.create(name: '  Work ', secrets: {seed}),
    );
    expect(created.name, 'Work');
    expect(await names(), ['All', 'Work']);
    final foreign = Fingerprint.tryParse('deadbeef')!;
    final refused = await opened.administration.create(
      name: 'Other',
      secrets: {foreign},
    );
    expect((refused as Err).failure, isA<SecretNotFoundFailure>());
    expect(await names(), ['All', 'Work']);
    expect(
      (await opened.administration.create(name: '   ') as Err).failure,
      isA<InvalidViewNameFailure>(),
    );
  });

  test('only opened views can be named, renamed or deleted', () async {
    const ghost = ViewId('ghost');
    expect(
      (await opened.administration.rename(ghost, 'x') as Err).failure,
      isA<ViewNotOpenFailure>(),
    );
    expect(
      (await opened.administration.delete(ghost) as Err).failure,
      isA<ViewNotOpenFailure>(),
    );
    expect(
      (await opened.administration.attach(seed, to: ghost) as Err).failure,
      isA<ViewNotOpenFailure>(),
    );
  });

  test('the last view and the view in use stay; a view with a seed only it '
      'holds stays too', () async {
    expect(
      (await opened.administration.delete(const ViewId('all')) as Err).failure,
      isA<ViewInUseFailure>(),
    );
    final work = ok(await opened.administration.create(name: 'Work'));
    ok(await opened.activate(work.id));
    expect(
      (await opened.administration.delete(const ViewId('all')) as Err).failure,
      isA<ViewHoldsSecretsFailure>(),
    );
    ok(await opened.activate(const ViewId('all')));
    ok(await opened.administration.delete(work.id));
    expect(await names(), ['All']);
    // With one view left the installation keeps it.
    await inventory.lock();
    final again = ok(await inventory.authenticate('')).views!;
    ok(await again.activate(const ViewId('all')));
  });

  test('a wallet whose member another view holds cannot be deleted from '
      'one of them', () async {
    final work = ok(
      await opened.administration.create(name: 'Work', secrets: {seed}),
    );
    final local = viewWallet('mine', signer: 'local', fingerprint: seed.hex);
    expect(
      (await inventory.removeWallet(local.id) as Err).failure,
      isA<SharedWithOtherViewFailure>(),
    );
    ok(await opened.activate(work.id));
    expect(ok(await inventory.findWallet(local.id)), isNotNull);
    ok(await opened.activate(const ViewId('all')));
    ok(await opened.administration.detach(seed));
    expect(ok(await inventory.findWallet(local.id)), isNull);
    ok(await opened.activate(work.id));
    ok(await inventory.removeWallet(local.id));
  });

  test('detaching the only holder of a seed is refused', () async {
    expect(
      (await opened.administration.detach(seed) as Err).failure,
      isA<ViewHoldsSecretsFailure>(),
    );
  });

  test('attaching to a protected view needs the backup the guard asks '
      'for', () async {
    final work = ok(await opened.administration.create(name: 'Work'));
    ok(await opened.activate(work.id));
    ok(await inventory.setCredential('1234'));
    ok(await opened.activate(const ViewId('all')));
    final refused = await opened.administration.attach(seed, to: work.id);
    expect((refused as Err).failure, isA<BackupVerifierUnboundFailure>());
  });

  test('renaming moves the name and never the id', () async {
    final work = ok(await opened.administration.create(name: 'Work'));
    ok(await opened.administration.rename(work.id, 'Play'));
    expect(opened.views.singleWhere((view) => view.id == work.id).name, 'Play');
  });
}

/// A capability is the generation it was taken in.
void generationTests() {
  late ViewFixture fixture;
  late SessionAuthority authority;
  late SecretsInventory inventory;
  late Secrets secrets;

  setUp(() async {
    overrideMultiViewForTests(true);
    fixture = await ViewFixture.create();
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
  });

  tearDown(() async {
    overrideMultiViewForTests(null);
    await inventory.close();
    await fixture.close();
  });

  test('an administration kept before a lock is refused after the next '
      'unlock', () async {
    final seed = ok(await secrets.generate()).id;
    ok(
      await inventory.registerWallet(
        viewWallet('mine', signer: 'local', fingerprint: seed.hex),
      ),
    );
    final kept = inventory.openedViews!.administration;
    await inventory.lock();
    ok(await inventory.authenticate(''));
    expect(await kept.create(name: 'Late'), isA<Err>());
    expect(await kept.detach(seed), isA<Err>());
    expect(inventory.openedViews!.views.map((v) => v.name), [
      'All',
    ], reason: 'nothing was written by the stale capability');
  });

  test(
    'an administration kept before a view switch is refused after it',
    () async {
      final opened = inventory.openedViews!;
      final kept = opened.administration;
      final other = ok(await kept.create(name: 'Other'));
      ok(await opened.activate(other.id));
      expect(await kept.create(name: 'Late'), isA<Err>());
      expect(
        ok(await opened.administration.create(name: 'Fresh')).name,
        'Fresh',
      );
    },
  );
}
