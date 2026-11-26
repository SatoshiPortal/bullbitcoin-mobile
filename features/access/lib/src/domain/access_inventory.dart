import 'package:access/src/domain/access_failure.dart';
import 'package:access/src/domain/entities/unlock_attempt.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/storage.dart';

/// Maps the inventory's persisted credential and attempt state to Access.
final class AccessInventory {
  final SecretsInventory _inventory;

  const AccessInventory(this._inventory);

  Future<Result<bool, AccessFailure>> isProtected() async =>
      (await _inventory.isProtected()).mapErr(
        (_) => const AccessPinCheckFailure(),
      );

  /// Revokes immediately. An unprotected view can reopen after drainage,
  /// provided no newer lock has superseded it.
  Future<bool> lockIfProtected() => _inventory.lockIfProtected();

  Stream<bool> get locked => _inventory.lockedChanges;

  Future<Result<void, AccessFailure>> setCredential(String pin) async =>
      (await _inventory.setCredential(pin)).mapErr(_saveFailure);

  /// Whether the active view can take a PIN: every secret it holds has a
  /// tested backup. A read that cannot tell never says yes. This is the same
  /// rule the inventory applies when saving, offered ahead for the screen.
  Future<Result<void, AccessFailure>> checkBackups() async =>
      switch (await _inventory.unbackedSecrets()) {
        Ok(value: final missing) when missing.isEmpty => const Ok(null),
        Ok(value: final missing) => Err(
          AccessBackupRequiredFailure(missing.length),
        ),
        Err(:final failure) => Err(_saveFailure(failure)),
      };

  AccessFailure _saveFailure(SecretFailure failure) => switch (failure) {
    BackupRequiredFailure(:final missing) => AccessBackupRequiredFailure(
      missing.length,
    ),
    BackupStateUnavailableFailure() ||
    BackupVerifierUnboundFailure() => const AccessBackupUnavailableFailure(),
    _ => const AccessPinSaveFailure(),
  };

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
    final milliseconds = attempt.remaining.inMilliseconds;
    return UnlockAttempt(
      success: attempt.accepted,
      failedAttempts: attempt.failedAttempts,
      timeout: (milliseconds + 999) ~/ 1000,
    );
  }
}
