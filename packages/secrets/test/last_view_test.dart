import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/storage.dart';
import 'package:secrets/testing.dart' show overrideMultiViewForTests;

import 'support/view_fixture.dart';

/// D102: the last view opened is remembered in the Secrets database. It is a
/// memory, not a right: it chooses among the views an authentication opened and
/// nothing else.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ViewFixture fixture;
  late SessionAuthority authority;
  late SecretsInventory inventory;

  setUp(() async {
    overrideMultiViewForTests(true);
    fixture = await ViewFixture.create();
    await fixture.sql([
      "INSERT INTO views (id, name, background_enabled) VALUES ('b', 'Bravo', 1)",
      "INSERT INTO views (id, name, background_enabled) VALUES ('c', 'Charlie', 1)",
    ]);
    authority = SessionAuthority();
    inventory = ok(
      await SecretsInventory.open(
        file: fixture.file,
        admission: fixture.admission,
        authority: authority,
      ),
    );
  });

  tearDown(() async {
    overrideMultiViewForTests(null);
    await inventory.close();
    await fixture.close();
  });

  Future<String?> active() async => authority.current?.activeView;

  test('with no PIN anywhere the last view opened is the one that opens '
      'again', () async {
    expect(await active(), 'all');
    final views = ok(await inventory.authenticate('')).views!;
    ok(await views.activate(const ViewId('c')));
    await inventory.lock();
    expect(await inventory.resumeUnprotected(), isA<Ok>());
    expect(await active(), 'c');
  });

  test('a single view is the one that opens', () async {
    await fixture.sql(["DELETE FROM views WHERE id IN ('b', 'c')"]);
    await inventory.lock();
    ok(await inventory.resumeUnprotected());
    expect(await active(), 'all');
  });

  test('a PIN starts on the remembered view only when it opened it', () async {
    authority.grant('b');
    ok(await inventory.setCredential('1111'));
    authority.grant('c');
    ok(await inventory.setCredential('2222'));
    await inventory.lock();
    final first = ok(await inventory.authenticate('2222')).views!;
    ok(await first.activate(const ViewId('c')));
    await inventory.lock();
    ok(await inventory.authenticate('2222'));
    expect(await active(), 'c', reason: 'its own PIN opens where it left off');
    await inventory.lock();
    final other = ok(await inventory.authenticate('1111')).views!;
    expect(other.views.map((v) => v.name), isNot(contains('Charlie')));
    expect(await active(), isNot('c'), reason: 'a memory is not a right');
    expect(await active(), isNotNull);
  });

  test('deleting the remembered view forgets it', () async {
    final views = ok(await inventory.authenticate('')).views!;
    ok(await views.activate(const ViewId('b')));
    ok(await views.activate(const ViewId('all')));
    ok(await views.administration.delete(const ViewId('b')));
    final remembered = await fixture.lastView(inventory);
    expect(remembered, 'all');
  });
}
