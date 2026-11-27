import 'package:access/src/domain/access_inventory.dart';
import 'package:access/src/domain/usecases/check_pin_code_exists_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import '../../support/inventory_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('reads the PIN independently of the legacy key', () async {
    final fixture = await InventoryFixture.open(pin: '1234');
    addTearDown(fixture.close);
    final usecase = CheckPinCodeExistsUsecase(
      inventory: AccessInventory(fixture.inventory),
    );
    expect((await usecase.execute() as Ok).value, isTrue);
    fixture.storage.entries.remove('securityKey');
    expect((await usecase.execute() as Ok).value, isTrue);
  });

  test('reports an unprotected inventory', () async {
    final fixture = await InventoryFixture.open();
    addTearDown(fixture.close);
    final usecase = CheckPinCodeExistsUsecase(
      inventory: AccessInventory(fixture.inventory),
    );
    expect((await usecase.execute() as Ok).value, isFalse);
  });
}
