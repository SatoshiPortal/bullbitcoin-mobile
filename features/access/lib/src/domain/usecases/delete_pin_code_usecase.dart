import 'package:access/src/domain/access_failure.dart';
import 'package:access/src/domain/access_inventory.dart';
import 'package:primitives/primitives.dart';

class DeletePinCodeUsecase {
  final AccessInventory _inventory;

  DeletePinCodeUsecase({required this._inventory});

  Future<Result<void, AccessFailure>> execute() =>
      _inventory.removeCredential();
}
