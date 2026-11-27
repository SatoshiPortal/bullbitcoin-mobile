import 'package:access/src/domain/access_failure.dart';
import 'package:access/src/domain/access_inventory.dart';
import 'package:primitives/primitives.dart';

/// Checks whether every secret of the view has a tested backup, which permits
/// creating a PIN. Changing an existing PIN needs no proof and does not call it.
class CheckPinBackupUsecase {
  final AccessInventory _inventory;

  const CheckPinBackupUsecase({required this._inventory});

  Future<Result<void, AccessFailure>> execute() => _inventory.checkBackups();
}
