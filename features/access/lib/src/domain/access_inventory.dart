import 'package:access/src/domain/access_failure.dart';
import 'package:access/src/domain/entities/unlock_attempt.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/storage.dart';

/// Maps the inventory's persisted credential and attempt state to Access.
final class AccessInventory {
  final SecretsInventory _inventory;
  final InventoryBackupVerification _backupVerification;

  const AccessInventory(this._inventory, this._backupVerification);

  Future<Result<bool, AccessFailure>> isProtected() async =>
      (await _inventory.isProtected()).mapErr(
        (_) => const AccessPinCheckFailure(),
      );

  Future<Result<void, AccessFailure>> setCredential(String pin) async =>
      (await _inventory.setCredential(
        pin,
        backupVerification: _backupVerification,
      )).mapErr((_) => const AccessPinSaveFailure());

  Future<Result<void, AccessFailure>> removeCredential() async =>
      (await _inventory.removeCredential()).mapErr(
        (_) => const AccessPinDeleteFailure(),
      );

  Future<Result<UnlockAttempt, AccessFailure>> status() async =>
      (await _inventory.accessStatus())
          .map(_convert)
          .mapErr((_) => const AccessUnlockUnexpectedFailure());

  Future<Result<UnlockAttempt, AccessFailure>> unlock(String pin) async =>
      (await _inventory.unlock(pin))
          .map(_convert)
          .mapErr((_) => const AccessPinVerifyFailure());

  UnlockAttempt _convert(AccessAttempt attempt) {
    final milliseconds =
        attempt.lockedUntil?.difference(DateTime.now()).inMilliseconds ?? 0;
    return UnlockAttempt(
      success: attempt.accepted,
      failedAttempts: attempt.failedAttempts,
      timeout: milliseconds <= 0 ? 0 : (milliseconds + 999) ~/ 1000,
    );
  }
}
