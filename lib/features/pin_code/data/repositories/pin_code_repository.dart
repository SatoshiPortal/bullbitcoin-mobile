import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/keychain_locked_exception.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/pin_code/domain/pin_code_failure.dart';
import 'package:flutter/foundation.dart';

class PinCodeRepository {
  final KeyValueStorageDatasource<String> _storage;

  static const _key =
      'securityKey'; // Use same key as in AuthCubit to stay backward compatible

  static const _healedMarkerKey = 'securityKeyAccessibilityHealedV1';
  static const _healBackupKey = 'securityKeyHealBackupV1';

  bool _accessibilityHealAttempted = false;

  PinCodeRepository(this._storage);

  Future<Result<bool, PinCodeFailure>> isPinCodeSet() async {
    try {
      final pin = await _readPinRestoringFromHealBackupIfNeeded();
      if (pin != null) {
        await _healLegacyKeychainAccessibility(pin);
      }
      return Ok(pin != null);
    } on KeychainLockedException {
      // This is a load-bearing, startup-gating read (see the exception's
      // own doc comment), so it must bubble up rather than be swallowed
      // into a generic failure — AppStartupBloc has a dedicated typed
      // catch that stays on the splash screen and retries once the device
      // unlocks, instead of showing the permanent "Startup Error" screen.
      rethrow;
    } catch (e, st) {
      log.severe(
        message: 'Unexpected failure checking PIN code status',
        error: e,
        trace: st,
      );
      return Err(PinCodeUnexpectedFailure(e.toString()));
    }
  }

  Future<Result<Null, PinCodeFailure>> setPinCode(String pinCode) async {
    try {
      await _storage.saveValue(key: _key, value: pinCode);
      // A prior heal's backup would otherwise be stale (its pin no longer
      // matches [_key]); harmless to leave in this instance since restore
      // only fires when [_key] is absent, but a later deletePinCode()
      // wiping [_key] must not resurrect this old value.
      await _deleteHealBackupBestEffort();
      return const Ok(null);
    } on KeychainLockedException {
      return const Err(PinCodeSaveFailure());
    } catch (e, st) {
      log.severe(
        message: 'Unexpected failure saving PIN code',
        error: e,
        trace: st,
      );
      return Err(PinCodeUnexpectedFailure(e.toString()));
    }
  }

  Future<Result<bool, PinCodeFailure>> verifyPinCode(String pinCode) async {
    try {
      final pin = await _readPinRestoringFromHealBackupIfNeeded();

      if (pin == null) return const Err(PinCodeNotSetFailure());
      await _healLegacyKeychainAccessibility(pin);
      return Ok(pin == pinCode);
    } on KeychainLockedException {
      return const Err(PinCodeUnexpectedFailure('Keychain locked'));
    } catch (e, st) {
      log.severe(
        message: 'Unexpected failure verifying PIN code',
        error: e,
        trace: st,
      );
      return Err(PinCodeUnexpectedFailure(e.toString()));
    }
  }

  // Pre-6.10 PIN items were written with the plugin-default
  // kSecAttrAccessibleWhenUnlocked class, which keychain items keep for
  // life and which makes reads fail with -25308 when iOS launches the app
  // before the screen is unlocked. A plain overwrite cannot fix this:
  // flutter_secure_storage_darwin 0.2.0 (FlutterSecureStorage.swift,
  // write(), lines 319-337) calls SecItemUpdate on existing items with an
  // update dictionary containing only kSecValueData — the configured
  // accessibility is only part of the search query, so it is never applied
  // to the stored item. Only SecItemAdd applies it, so the item must be
  // deleted and re-added.
  //
  // Between delete and re-add, [pin] is backed up under [_healBackupKey]
  // first and only cleared once [_key] is confirmed re-added and the healed
  // marker is written — so a crash (or force-quit) in that window leaves a
  // recoverable backup rather than silently disabling the PIN lock; the next
  // read restores [_key] from it via [_readPinRestoringFromHealBackupIfNeeded].
  Future<void> _healLegacyKeychainAccessibility(String pin) async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    if (_accessibilityHealAttempted) return;
    _accessibilityHealAttempted = true;

    try {
      final healed = await _storage.getValue(_healedMarkerKey);
      if (healed != null) return;

      await _storage.saveValue(key: _healBackupKey, value: pin);
      await _storage.deleteValue(_key);
      try {
        await _storage.saveValue(key: _key, value: pin);
      } catch (_) {
        try {
          await _storage.saveValue(key: _key, value: pin);
        } catch (e, st) {
          log.severe(
            message:
                'PIN keychain accessibility heal deleted the PIN item but '
                'failed to re-save it twice — recoverable from backup on '
                'the next read',
            error: e,
            trace: st,
          );
          return;
        }
      }
      await _storage.saveValue(key: _healedMarkerKey, value: '1');
      await _deleteHealBackupBestEffort();
    } catch (e) {
      log.warning('PIN keychain accessibility heal failed', error: e);
    }
  }

  // Reads [_key], restoring it from [_healBackupKey] first if the heal
  // above crashed between deleting [_key] and re-adding it. Idempotent and
  // safe to call on every read: the backup is absent for the overwhelming
  // majority of reads (no PIN, or already healed) and this is a single
  // local keychain lookup.
  Future<String?> _readPinRestoringFromHealBackupIfNeeded() async {
    final pin = await _storage.getValue(_key);
    if (pin != null) return pin;

    final backup = await _storage.getValue(_healBackupKey);
    if (backup == null) return null;

    try {
      await _storage.saveValue(key: _key, value: backup);
    } catch (e, st) {
      log.warning(
        'Failed to restore PIN from heal backup — will retry next read',
        error: e,
        trace: st,
      );
      // Still report this call's actual PIN correctly; only the durable
      // restore failed, not the pin lookup itself.
    }
    return backup;
  }

  Future<void> _deleteHealBackupBestEffort() async {
    try {
      await _storage.deleteValue(_healBackupKey);
    } catch (e) {
      log.warning('Failed to delete PIN heal backup', error: e);
    }
  }

  Future<Result<Null, PinCodeFailure>> deletePinCode() async {
    try {
      // Clear the heal backup BEFORE deleting the live key, not after:
      // deleting [_key] while [_healBackupKey] still holds the old pin is
      // exactly the state [_readPinRestoringFromHealBackupIfNeeded] would
      // resurrect on the next read — whether from a crash between the two
      // deletes, or this backup delete simply failing on its own. Retry
      // once like the heal's own re-save does; if the backup still can't
      // be cleared, refuse to delete the live key so this fails loudly
      // instead of silently setting up a future resurrection.
      try {
        await _storage.deleteValue(_healBackupKey);
      } on KeychainLockedException {
        rethrow;
      } catch (_) {
        try {
          await _storage.deleteValue(_healBackupKey);
        } on KeychainLockedException {
          rethrow;
        } catch (e, st) {
          log.severe(
            message:
                'Failed to clear PIN heal backup twice — refusing to '
                'delete the live PIN to avoid a stale-backup resurrection',
            error: e,
            trace: st,
          );
          return Err(PinCodeUnexpectedFailure(e.toString()));
        }
      }
      await _storage.deleteValue(_key);
      return const Ok(null);
    } on KeychainLockedException {
      return const Err(PinCodeDeleteFailure());
    } catch (e, st) {
      log.severe(
        message: 'Unexpected failure deleting PIN code',
        error: e,
        trace: st,
      );
      return Err(PinCodeUnexpectedFailure(e.toString()));
    }
  }
}
