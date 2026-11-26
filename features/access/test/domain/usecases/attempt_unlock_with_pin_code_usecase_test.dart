import 'package:access/src/domain/access_inventory.dart';
import 'package:access/src/domain/usecases/attempt_unlock_with_pin_code_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import '../../support/inventory_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late InventoryFixture fixture;
  late AttemptUnlockWithPinCodeUsecase usecase;

  setUp(() async {
    fixture = await InventoryFixture.open(pin: '1234');
    usecase = AttemptUnlockWithPinCodeUsecase(
      inventory: AccessInventory(fixture.inventory),
    );
  });
  tearDown(() => fixture.close());

  test(
    'wrong PIN records attempts and correct PIN unlocks the inventory',
    () async {
      final wrong = (await usecase.execute('0000') as Ok).value;
      expect(wrong.success, isFalse);
      expect(wrong.failedAttempts, 1);
      final correct = (await usecase.execute('1234') as Ok).value;
      expect(correct.success, isTrue);
      expect(correct.failedAttempts, 0);
      expect(await fixture.inventory.listWallets(), isA<Ok>());
    },
  );

  test('cooldown refuses the correct PIN until its deadline', () async {
    for (var attempt = 0; attempt < 4; attempt++) {
      expect(await usecase.execute('0000'), isA<Ok>());
    }
    final result = (await usecase.execute('1234') as Ok).value;
    expect(result.success, isFalse);
    expect(result.failedAttempts, 4);
    expect(result.timeout, greaterThan(0));
    expect(await fixture.inventory.listWallets(), isA<Err>());
  });
}
