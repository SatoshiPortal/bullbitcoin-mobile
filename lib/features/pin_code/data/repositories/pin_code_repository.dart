import 'package:bb_mobile/core_deprecated/errors/bull_exception.dart';
import 'package:bb_mobile/core_deprecated/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';

class PinCodeRepository {
  final KeyValueStorageDatasource<String> _storage;

  static const _key =
      'securityKey'; // Use same key as in AuthCubit to stay backward compatible

  PinCodeRepository(this._storage);

  Future<bool> isPinCodeSet() async {
    final pin = await _storage.getValue(_key);

    return pin != null;
  }

  Future<void> setPinCode(String pinCode) async {
    await _storage.saveValue(key: _key, value: pinCode);
  }

  Future<bool> verifyPinCode(String pinCode) async {
    final pin = await _storage.getValue(_key);

    if (pin == null) {
      throw PinCodeNotSetException(
        'Pin code is not set. Use create method to set it.',
      );
    }

    return pin == pinCode;
  }

  Future<void> deletePinCode() async => await _storage.deleteValue(_key);
}

class PinCodeNotSetException extends BullException {
  PinCodeNotSetException(super.message);
}

class InvalidPinCodeException extends BullException {
  InvalidPinCodeException(super.message);
}
