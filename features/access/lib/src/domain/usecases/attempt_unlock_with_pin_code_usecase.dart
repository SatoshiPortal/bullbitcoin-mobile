import 'package:access/src/domain/access_failure.dart';
import 'package:access/src/domain/access_inventory.dart';
import 'package:access/src/domain/entities/unlock_attempt.dart';
import 'package:primitives/primitives.dart';

class AttemptUnlockWithPinCodeUsecase {
  final AccessInventory _inventory;

  AttemptUnlockWithPinCodeUsecase({required this._inventory});

  Future<Result<UnlockAttempt, AccessFailure>> execute(String pinCode) =>
      _inventory.unlock(pinCode);
}
