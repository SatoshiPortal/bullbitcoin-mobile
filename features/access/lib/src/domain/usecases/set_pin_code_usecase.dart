import 'package:access/src/domain/access_failure.dart';
import 'package:access/src/domain/access_inventory.dart';
import 'package:primitives/primitives.dart';

class SetPinCodeUsecase {
  final AccessInventory _inventory;

  SetPinCodeUsecase({required this._inventory});

  Future<Result<void, AccessFailure>> execute(String pinCode) =>
      _inventory.setCredential(pinCode);
}
