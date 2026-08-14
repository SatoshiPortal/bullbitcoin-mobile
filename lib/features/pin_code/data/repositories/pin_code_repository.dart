import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/keychain_locked_exception.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/pin_code/domain/pin_code_failure.dart';

class PinCodeRepository {
  final KeyValueStorageDatasource<String> _storage;

  static const _key =
      'securityKey'; // Use same key as in AuthCubit to stay backward compatible

  PinCodeRepository(this._storage);

  Future<Result<bool, PinCodeFailure>> isPinCodeSet() async {
    try {
      final pin = await _storage.getValue(_key);
      return Ok(pin != null);
    } on KeychainLockedException {
      return const Err(PinCodeKeychainLockedFailure());
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
