import 'package:access/src/domain/access_inventory.dart';
import 'package:access/src/domain/usecases/is_pin_code_set_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import '../../support/inventory_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('reads settings from the inventory', () async {
    final fixture = await InventoryFixture.open(pin: '1234');
    addTearDown(fixture.close);
    final usecase = IsPinCodeSetUsecase(
      inventory: AccessInventory(fixture.inventory),
    );
    expect((await usecase.execute() as Ok).value, isTrue);
  });
}
