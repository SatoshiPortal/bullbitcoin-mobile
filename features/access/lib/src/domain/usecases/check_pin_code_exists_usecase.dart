import 'package:access/src/domain/access_failure.dart';
import 'package:access/src/domain/access_inventory.dart';
import 'package:primitives/primitives.dart';

class CheckPinCodeExistsUsecase {
  final AccessInventory _inventory;

  CheckPinCodeExistsUsecase({required this._inventory});

  Future<Result<bool, AccessFailure>> execute() => _inventory.isProtected();
}
