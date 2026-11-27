import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart' show SecretFailure;
import 'package:secrets/storage.dart';

import 'support/view_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ViewFixture fixture;
  late SessionAuthority authority;
  late SecretsInventory inventory;

  setUp(() async {
    fixture = await ViewFixture.create();
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
    await inventory.close();
    await fixture.close();
  });

  test(
    'a lock that lands while the views are read wins over reopening',
    () async {
      await inventory.lock();
      expect(authority.current, isNull);
      // The read of the views is in flight (it needs the database) when the
      // lock arrives; both start before either can finish.
      final resumed = inventory.resumeUnprotected();
      final locked = inventory.lock();
      final result = await resumed;
      await locked;
      expect(authority.current, isNull, reason: 'no token may be granted');
      expect(result, isA<Err<void, SecretFailure>>());
      expect(inventory.isLocked, isTrue);
      expect(inventory.openedViews, isNull);
    },
  );
}
