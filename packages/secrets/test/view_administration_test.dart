import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/storage.dart';
import 'package:secrets/testing.dart' show overrideMultiViewForTests;

import 'support/view_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
    final admin = opened.administration;
    final created = ok(await admin.create(name: '  Work ', secrets: {seed}));
    expect(created.name, 'Work');
    expect(await names(), ['All', 'Work']);
    final foreign = Fingerprint.tryParse('deadbeef')!;
    final refused = await admin.create(name: 'Other', secrets: {foreign});
    expect((refused as Err).failure, isA<SecretNotFoundFailure>());
    expect(await names(), ['All', 'Work']);
    expect(
      (await admin.create(name: '   ') as Err).failure,
      isA<InvalidViewNameFailure>(),
    );
  });

  test('only opened views can be named, renamed or deleted', () async {
    final admin = opened.administration;
    const ghost = ViewId('ghost');
    expect(
      (await admin.rename(ghost, 'x') as Err).failure,
      isA<ViewNotOpenFailure>(),
    );
    expect(
      (await admin.delete(ghost) as Err).failure,
      isA<ViewNotOpenFailure>(),
    );
    expect(
      (await admin.attach(seed, to: ghost) as Err).failure,
      isA<ViewNotOpenFailure>(),
    );
  });

  test('the last view and the view in use stay; a view with a seed only it '
      'holds stays too', () async {
    final admin = opened.administration;
    expect(
      (await admin.delete(const ViewId('all')) as Err).failure,
      isA<ViewInUseFailure>(),
    );
    final work = ok(await admin.create(name: 'Work'));
    ok(await opened.activate(work.id));
    expect(
      (await admin.delete(const ViewId('all')) as Err).failure,
      isA<ViewHoldsSecretsFailure>(),
    );
    ok(await opened.activate(const ViewId('all')));
    ok(await admin.delete(work.id));
    expect(await names(), ['All']);
    // With one view left the installation keeps it.
    await inventory.lock();
    final again = ok(await inventory.authenticate('')).views!;
    ok(await again.activate(const ViewId('all')));
  });

  test('a wallet whose member another view holds cannot be deleted from '
      'one of them', () async {
    final admin = opened.administration;
    final work = ok(await admin.create(name: 'Work', secrets: {seed}));
    final local = viewWallet('mine', signer: 'local', fingerprint: seed.hex);
    expect(
      (await inventory.removeWallet(local.id) as Err).failure,
      isA<SharedWithOtherViewFailure>(),
    );
    ok(await opened.activate(work.id));
    expect(ok(await inventory.findWallet(local.id)), isNotNull);
    ok(await opened.activate(const ViewId('all')));
    ok(await admin.detach(seed));
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
    final admin = opened.administration;
    final work = ok(await admin.create(name: 'Work'));
    ok(await opened.activate(work.id));
    ok(await inventory.setCredential('1234'));
    ok(await opened.activate(const ViewId('all')));
    final refused = await admin.attach(seed, to: work.id);
    expect((refused as Err).failure, isA<BackupVerifierUnboundFailure>());
  });

  test('renaming moves the name and never the id', () async {
    final admin = opened.administration;
    final work = ok(await admin.create(name: 'Work'));
    ok(await admin.rename(work.id, 'Play'));
    expect(opened.views.singleWhere((view) => view.id == work.id).name, 'Play');
  });
}
