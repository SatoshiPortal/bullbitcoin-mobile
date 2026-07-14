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

  bool _accessibilityHealAttempted = false;

  PinCodeRepository(this._storage);

  Future<Result<bool, PinCodeFailure>> isPinCodeSet() async {
    try {
      final pin = await _storage.getValue(_key);
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
      final pin = await _storage.getValue(_key);

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
  // deleted and re-added. Between delete and save the PIN exists only in
  // [pin]; a failed save would silently disable the PIN lock, hence the
  // retry and log.severe.
  Future<void> _healLegacyKeychainAccessibility(String pin) async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    if (_accessibilityHealAttempted) return;
    _accessibilityHealAttempted = true;

    try {
      final healed = await _storage.getValue(_healedMarkerKey);
      if (healed != null) return;

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
                'failed to re-save it twice — PIN lock is now disabled',
            error: e,
            trace: st,
          );
          return;
        }
      }
      await _storage.saveValue(key: _healedMarkerKey, value: '1');
    } catch (e) {
      log.warning('PIN keychain accessibility heal failed', error: e);
    }
  }

  Future<Result<Null, PinCodeFailure>> deletePinCode() async {
    try {
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
