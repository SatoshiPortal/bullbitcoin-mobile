import 'package:bb_mobile/core/data/datasources/key_value_storage_data_source.dart';
import 'package:bb_mobile/features/pin_code/domain/repositories/pin_code_repository.dart';

class PinCodeRepositoryImpl implements PinCodeRepository {
  final KeyValueStorageDataSource<String> _storage;

  static const _key = 'pinCodeKey';
  static const _unlockTimeoutKey = 'unlockTimeoutKey';

  PinCodeRepositoryImpl(this._storage);

  @override
  Future<bool> isPinCodeSet() async {
    final pin = await _storage.getValue(_key);

    return pin != null;
  }

  @override
  Future<void> createPinCode(String pinCode) async {
    final isPinCodeAlreadySet = await isPinCodeSet();

    if (isPinCodeAlreadySet) {
      throw PinCodeAlreadySetException(
        message: 'Pin code is already set. Use update method to change it.',
      );
    }

    await _storage.saveValue(key: _key, value: pinCode);
  }

  @override
  Future<bool> checkPinCode(String pinCode) async {
    final pin = await _storage.getValue(_key);

    if (pin == null) {
      throw PinCodeNotSetException(
        message: 'Pin code is not set. Use create method to set it.',
      );
    }

    return pin == pinCode;
  }

  @override
  Future<void> updatePinCode({
    required String oldPinCode,
    required String newPinCode,
  }) async {
    final isPinCodeCorrect = await checkPinCode(oldPinCode);

    if (!isPinCodeCorrect) {
      throw InvalidPinCodeException(
        message: 'Pin code is incorrect. Cannot update it.',
      );
    }

    await _storage.saveValue(key: _key, value: newPinCode);
  }

  @override
  Future<void> setUnlockTimeout(int timeoutSeconds) async {
    await _storage.saveValue(
      key: _unlockTimeoutKey,
      value: timeoutSeconds.toString(),
    );
  }

  @override
  Future<int> getUnlockTimeout() async {
    final timeout = await _storage.getValue(_unlockTimeoutKey);

    return int.tryParse(timeout ?? '0') ?? 0;
  }
}

class PinCodeAlreadySetException implements Exception {
  final String message;

  PinCodeAlreadySetException({required this.message});
}

class PinCodeNotSetException implements Exception {
  final String message;

  PinCodeNotSetException({required this.message});
}

class InvalidPinCodeException implements Exception {
  final String message;

  InvalidPinCodeException({required this.message});
}
