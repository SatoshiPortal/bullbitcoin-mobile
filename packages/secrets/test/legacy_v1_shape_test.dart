import 'package:flutter_test/flutter_test.dart';
import 'package:secrets/storage.dart';

import 'support/view_fixture.dart';

/// Files written before `last_view_id` existed (schema v1 at the WS2 head)
/// open as they are: the column is added once, guarded, with no reset.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ViewFixture fixture;

  setUp(() async => fixture = await ViewFixture.create());
  tearDown(() async => fixture.close());

  Future<SecretsInventory> open() async => ok(
    await SecretsInventory.open(
      file: fixture.file,
      admission: fixture.admission,
      authority: SessionAuthority(),
    ),
  );

  test('a v1 file without the column opens, keeps its PIN, counter and '
      'receipt, and adapts once', () async {
    var inventory = await open();
    ok(await inventory.setCredential('1234'));
    expect(ok(await inventory.authenticate('0000')).views, isNull);
    expect(ok(await inventory.authenticate('0000')).views, isNull);
    await inventory.close();
    // The shape the previous build wrote.
    await fixture.sql(['ALTER TABLE access_state DROP COLUMN last_view_id']);

    inventory = await open();
    expect(ok(await inventory.accessStatus()).failedAttempts, 2);
    final refused = ok(await inventory.authenticate('0000'));
    expect(refused.views, isNull);
    expect(refused.attempt.failedAttempts, 3);
    final accepted = ok(await inventory.authenticate('1234'));
    expect(accepted.views, isNotNull);
    await inventory.close();

    inventory = await open();
    expect(ok(await inventory.isProtected()), isTrue);
    await inventory.close();
  });

  test('adapting twice changes nothing', () async {
    final inventory = await open();
    await inventory.close();
    await fixture.sql(['ALTER TABLE access_state DROP COLUMN last_view_id']);
    for (var i = 0; i < 2; i++) {
      final again = await open();
      ok(await again.accessStatus());
      await again.close();
    }
    final remembered = await fixture.lastView(await open());
    expect(remembered, 'all', reason: 'the opening wrote its memory once');
  });
}
