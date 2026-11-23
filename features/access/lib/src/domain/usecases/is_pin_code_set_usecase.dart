import 'package:access/src/domain/access_failure.dart';
import 'package:access/src/domain/access_inventory.dart';
import 'package:primitives/primitives.dart';

class IsPinCodeSetUsecase {
  final AccessInventory _inventory;

  IsPinCodeSetUsecase({required this._inventory});

  Future<Result<bool, AccessFailure>> execute() => _inventory.isProtected();
}
