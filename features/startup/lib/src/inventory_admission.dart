import 'package:bull_logger/bull_logger.dart';
import 'package:legacy_storage/legacy_storage.dart';
import 'package:primitives/primitives.dart';

import 'domain/app_startup_failure.dart';
import 'inventory_recovery_for.dart';

/// What startup holds once the storage is admitted and the wallet inventory is
/// open.
typedef AdmittedInventory<A extends Object, I extends Object> = ({
  A admission,
  I inventory,
});

/// Admits the storage, then opens the wallet inventory, and decides what each
/// failure means.
///
/// The prepare failures of an unreadable inventory block, those of a locked
/// keystore, contention or another owner retry, and the rest end startup.
/// Nothing here replaces or erases a file.
///
/// [openInventory] receives the admission and registers whatever it opens.
/// When it fails or throws, [release] runs once before any screen is shown, so
/// a retry starts from nothing; an exception is then rethrown.
Future<Result<AdmittedInventory<A, I>, Failure>>
admitInventory<A extends Object, I extends Object>({
  required Future<Result<A, LegacyImportFailure>> Function() prepare,
  required Future<Result<I, Failure>> Function(A admission) openInventory,
  required Future<void> Function(A admission) release,
  Future<void> Function(LegacyImportFailure)? retryStorage,
  Future<void> Function(InventoryRecoveryRequired)? blockedInventory,
}) async {
  while (true) {
    var admitted = await prepare();
    while (admitted is Err<A, LegacyImportFailure>) {
      final failure = admitted.failure;
      if (inventoryRecoveryFor(failure) case final blocked?) {
        if (blockedInventory == null) return Err(blocked);
        await blockedInventory(blocked);
      } else if (retryStorage != null &&
          (failure is LegacyImportUnavailable ||
              failure is LegacyImportDeferred ||
              failure is LegacyOwnerFailure)) {
        await retryStorage(failure);
      } else {
        return Err(failure);
      }
      admitted = await prepare();
    }
    final admission = (admitted as Ok<A, LegacyImportFailure>).value;
    final Result<I, Failure> opened;
    try {
      opened = await openInventory(admission);
    } catch (_) {
      // A partial registration must not outlive the failed attempt, and the
      // original exception, with its stack, is the one that propagates.
      await _release(release, admission);
      rethrow;
    }
    switch (opened) {
      case Ok(:final value):
        return Ok((admission: admission, inventory: value));
      case Err(:final failure):
        // Cleaned before any screen: a retry starts from nothing. If the
        // cleanup itself fails, nothing is retried or shown over what may be
        // left behind, and the typed failure ends the attempt.
        if (!await _release(release, admission)) return Err(failure);
        final owner = inventoryOpenFailureOf(failure);
        if (owner == null) return Err(failure);
        if (inventoryRecoveryFor(owner) case final blocked?) {
          if (blockedInventory == null) return Err(blocked);
          await blockedInventory(blocked);
        } else if (retryStorage != null) {
          await retryStorage(owner);
        } else {
          return Err(failure);
        }
    }
  }
}

/// Runs [release] once. A failure of the cleanup is logged by a fixed label,
/// never by the raw exception, and reported to the caller as false.
Future<bool> _release<A extends Object>(
  Future<void> Function(A admission) release,
  A admission,
) async {
  try {
    await release(admission);
    return true;
  } catch (_) {
    log.warning('Storage admission cleanup failed');
    return false;
  }
}
