import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/ark_renewal.dart';
import 'package:secrets/storage.dart';
import 'package:secrets/testing.dart' show overrideMultiViewForTests;
import 'package:secrets/secrets.dart'
    show
        DatabaseFileUnavailable,
        DatabaseOpenFailure,
        DatabaseViewsUnsupported,
        SecretFailure,
        ViewsUnsupportedFailure;

import 'support/view_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ViewFixture fixture;

  setUp(() async => fixture = await ViewFixture.create());
  tearDown(() async {
    overrideMultiViewForTests(null);
    await fixture.close();
  });

  Future<List<Object?>> open({required bool multiView}) async {
    overrideMultiViewForTests(multiView);
    final inventory = await SecretsInventory.open(
      file: fixture.file,
      admission: fixture.admission,
      authority: SessionAuthority(),
    );
    final descriptors = await BackgroundWalletDescriptors.open(
      file: fixture.file,
      admission: fixture.admission,
    );
    final notify = await ArkBackgroundAccess.open(
      file: fixture.file,
      admission: fixture.admission,
    );
    final renewal = await ArkRenewalSecrets.open(
      file: fixture.file,
      admission: fixture.admission,
    );
    final results = [inventory, descriptors, notify, renewal];
    if (inventory case Ok(:final value)) await value.close();
    if (descriptors case Ok(:final value)) await value.close();
    if (notify case Ok(:final value)) await value.close();
    if (renewal case Ok(:final value)) await value.close();
    return results;
  }

  void expectEveryOpener(List<Object?> results, {required bool supported}) {
    expect(results, hasLength(4));
    for (final result in results) {
      if (supported) {
        expect(result, isA<Ok>());
      } else {
        expect(result, isA<Err>());
        expect((result! as Err).failure, isA<DatabaseViewsUnsupported>());
      }
    }
  }

  const second =
      "INSERT INTO views (id, name, background_enabled) VALUES ('b', 'B', 1)";

  test('the initial layout opens in a build without multiple views', () async {
    expectEveryOpener(await open(multiView: false), supported: true);
    expectEveryOpener(await open(multiView: true), supported: true);
  });

  test('a second view is refused by every opener of a closed build', () async {
    await fixture.sql([second]);
    expectEveryOpener(await open(multiView: false), supported: false);
    // The same file, after a restart, in a build that supports the layout.
    expectEveryOpener(await open(multiView: true), supported: true);
  });

  test('returning to a closed build after deleting the initial view is '
      'refused, not recovered', () async {
    await fixture.sql([second, "DELETE FROM views WHERE id = 'all'"]);
    expectEveryOpener(await open(multiView: false), supported: false);
    final supported = await open(multiView: true);
    // The foreground inventory reads the layout through its session: see the
    // view-addressing tests. The other openers read nothing of 'all'.
    expect(supported.skip(1), everyElement(isA<Ok>()));
  });

  test('zero views are refused by every build', () async {
    await fixture.sql(["DELETE FROM views"]);
    expectEveryOpener(await open(multiView: false), supported: false);
    expectEveryOpener(await open(multiView: true), supported: false);
  });

  test(
    'a credential reference with no row is refused by every build',
    () async {
      await fixture.sql([
        'PRAGMA foreign_keys = OFF',
        "UPDATE views SET credential_id = 'missing' WHERE id = 'all'",
      ]);
      expectEveryOpener(await open(multiView: false), supported: false);
      expectEveryOpener(await open(multiView: true), supported: false);
    },
  );

  test('a missing access state is refused by every build', () async {
    await fixture.sql(['DELETE FROM access_state']);
    expect(await open(multiView: false), everyElement(isA<Err>()));
    expect(await open(multiView: true), everyElement(isA<Err>()));
  });

  test('the refusal is not a damaged or unreadable file', () async {
    await fixture.sql([second]);
    final result = await SecretsInventory.open(
      file: fixture.file,
      admission: fixture.admission,
      authority: SessionAuthority(),
    );
    final failure =
        (result as Err<SecretsInventory, DatabaseOpenFailure>).failure;
    expect(failure, isNot(isA<DatabaseFileUnavailable>()));
    expect(failure, isA<DatabaseViewsUnsupported>());
  });

  test('a closed build refuses to create a second view and leaves the file '
      'readable by every opener', () async {
    // Production parameters: no override, so the build's own gate decides.
    final inventory = (await SecretsInventory.open(
      file: fixture.file,
      admission: fixture.admission,
      authority: SessionAuthority(),
    ) as Ok<SecretsInventory, DatabaseOpenFailure>).value;
    final opened = inventory.openedViews;
    expect(opened, isNotNull);
    final created = await opened!.administration.create(name: 'Second');
    expect(
      (created as Err<ViewSummary, SecretFailure>).failure,
      isA<ViewsUnsupportedFailure>(),
    );
    expect(opened.views.map((v) => v.name), ['All']);
    await inventory.close();
    for (final result in await open(multiView: false)) {
      expect(result, isA<Ok>());
    }
  });
}
