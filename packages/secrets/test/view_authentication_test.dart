import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart'
    show SecretFailure, UseSecretFailure, ViewId, ViewNotOpenFailure;
import 'package:secrets/storage.dart';
import 'package:secrets/testing.dart' show overrideMultiViewForTests;

import 'support/view_fixture.dart';

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

  Future<void> protect(String view, String pin) async {
    authority.grant(view);
    ok(await inventory.setCredential(pin));
  }

  Future<int> failedAttempts() async =>
      ok(await inventory.accessStatus()).failedAttempts;

  Future<OpenedViews> authenticate(String pin) async {
    final result = ok(await inventory.authenticate(pin));
    expect(result.attempt.accepted, isTrue);
    return result.views!;
  }

  test('the live session names its views and none while locked', () async {
    expect(inventory.activeView, const ViewId('all'));
    expect(inventory.openedViews?.views.map((v) => v.name), [
      'All',
      'Bravo',
      'Charlie',
    ]);
    await inventory.lock();
    expect(inventory.activeView, isNull);
    expect(inventory.openedViews, isNull);
    expect(multiViewSupported, isFalse, reason: 'release builds leave it off');
  });

  test('with no credential anywhere every view opens and no attempt is '
      'counted', () async {
    expect(inventory.isLocked, isFalse);
    ok(await inventory.lock().then((_) => const Ok<void, SecretFailure>(null)));
    final views = await authenticate('');
    expect(views.views.map((v) => v.name), ['All', 'Bravo', 'Charlie']);
    expect(await failedAttempts(), 0);
  });

  group('with two credentials', () {
    setUp(() async {
      await protect('b', '1111');
      await protect('c', '2222');
      await inventory.lock();
    });

    test('a PIN opens its own views and the views without a PIN, never '
        'another credential\'s', () async {
      final views = await authenticate('1111');
      expect(views.views.map((v) => v.name), ['All', 'Bravo']);
      expect(views.views.every((v) => v.name != 'Charlie'), isTrue);
      expect(
        views.views.singleWhere((v) => v.name == 'Bravo').isProtected,
        isTrue,
      );
    });

    test('an id this session did not open is not a right to it', () async {
      final views = await authenticate('1111');
      for (final id in [const ViewId('c'), const ViewId('unknown')]) {
        final result = await views.activate(id);
        expect(
          (result as Err).failure,
          isA<ViewNotOpenFailure>(),
          reason: '${id.value} must be refused alike',
        );
      }
      expect(authority.current?.activeView, 'all');
    });

    test('one wrong guess counts one attempt however many credentials '
        'exist', () async {
      final result = ok(await inventory.authenticate('9999'));
      expect(result.attempt.accepted, isFalse);
      expect(result.views, isNull);
      expect(await failedAttempts(), 1);
      expect(inventory.isLocked, isTrue);
    });

    test('a PIN that opens only some credentials does not forgive the '
        'attempts spent on the others', () async {
      ok(await inventory.authenticate('9999'));
      ok(await inventory.authenticate('9999'));
      expect(await failedAttempts(), 2);
      await authenticate('1111');
      expect(await failedAttempts(), 2);
    });

    test('activating another view revokes the first one\'s session', () async {
      final views = await authenticate('1111');
      final first = authority.current!;
      ok(await views.activate(const ViewId('b')));
      expect(authority.isCurrent(first), isFalse);
      expect(authority.current?.activeView, 'b');
    });

    test('views opened before a lock cannot be used after the next '
        'unlock', () async {
      final stale = await authenticate('1111');
      await inventory.lock();
      expect(await stale.activate(const ViewId('b')), isA<Err>());
      expect(stale.views, isEmpty);
      await authenticate('1111');
      final result = await stale.activate(const ViewId('b'));
      expect(
        (result as Err).failure,
        isA<UseSecretFailure>(),
        reason: 'the opening it belonged to is over',
      );
    });

    test('a session on a view without a PIN setting one keeps the attempts '
        'of the protected views', () async {
      ok(await inventory.authenticate('9999'));
      ok(await inventory.authenticate('9999'));
      final views = await authenticate('1111');
      ok(await views.activate(const ViewId('all')));
      expect(await failedAttempts(), 2);
      ok(await inventory.setCredential('3333'));
      expect(await failedAttempts(), 2);
    });
  });

  group('a credential shared by two views', () {
    setUp(() async {
      await protect('b', '1111');
      await fixture.sqlWhileOpen(inventory, [
        "UPDATE views SET credential_id = "
            "(SELECT credential_id FROM views WHERE id = 'b') WHERE id = 'c'",
      ]);
    });

    test('removing it from one view leaves the other protected', () async {
      authority.grant('b');
      ok(await inventory.removeCredential());
      await inventory.lock();
      // The sibling still requires its PIN, and the shared row survived.
      expect(ok(await inventory.authenticate('0000')).views, isNull);
      final views = await authenticate('1111');
      expect(
        views.views.singleWhere((v) => v.name == 'Charlie').isProtected,
        isTrue,
      );
      expect(
        views.views.singleWhere((v) => v.name == 'Bravo').isProtected,
        isFalse,
      );
    });

    test('rotating it moves every view that shares it, a dissociated view '
        'keeps its own PIN', () async {
      authority.grant('c');
      ok(await inventory.dissociateView());
      authority.grant('b');
      ok(await inventory.setCredential('5555'));
      await inventory.lock();
      expect((await authenticate("5555")).views.map((v) => v.name), [
        'All',
        'Bravo',
      ]);
      await inventory.lock();
      expect((await authenticate("1111")).views.map((v) => v.name), [
        'All',
        'Charlie',
      ]);
    });
  });
}
