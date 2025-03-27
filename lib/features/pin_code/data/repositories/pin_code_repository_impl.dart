import 'package:bb_mobile/core/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/features/pin_code/domain/repositories/pin_code_repository.dart';

class PinCodeRepositoryImpl implements PinCodeRepository {
  final KeyValueStorageDatasource<String> _storage;

  static const _key =
      'securityKey'; // Use same key as in AuthCubit to stay backward compatible

  PinCodeRepositoryImpl(this._storage);

  @override
  Future<bool> isPinCodeSet() async {
    final pin = await _storage.getValue(_key);

    return pin != null;
  }

  @override
  Future<void> setPinCode(String pinCode) async {
    await _storage.saveValue(key: _key, value: pinCode);
  }

  @override
  Future<bool> verifyPinCode(String pinCode) async {
    final pin = await _storage.getValue(_key);

    if (pin == null) {
      throw PinCodeNotSetException(
        message: 'Pin code is not set. Use create method to set it.',
      );
    }

    return pin == pinCode;
  }

  @override
  Future<void> deletePinCode() async {
    await _storage.deleteValue(_key);
  }
}

class PinCodeNotSetException implements Exception {
  final String message;

  PinCodeNotSetException({required this.message});
}

class InvalidPinCodeException implements Exception {
  final String message;

  InvalidPinCodeException({required this.message});
}
