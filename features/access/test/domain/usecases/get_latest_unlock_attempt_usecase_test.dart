import 'package:access/src/domain/access_inventory.dart';
import 'package:access/src/domain/usecases/get_latest_unlock_attempt_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import '../../support/inventory_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('reads the persisted attempt count and deadline', () async {
    final fixture = await InventoryFixture.open(pin: '1234');
    addTearDown(fixture.close);
    for (var index = 0; index < 4; index++) {
      expect(await fixture.inventory.unlock('0000'), isA<Ok>());
    }
    final usecase = GetLatestUnlockAttemptUsecase(
      inventory: AccessInventory(fixture.inventory),
    );
    final result = await usecase.execute();
    final attempt = (result as Ok).value;
    expect(attempt.failedAttempts, 4);
    expect(attempt.timeout, greaterThan(0));
    expect(attempt.timeout, lessThanOrEqualTo(30));
  });
}
