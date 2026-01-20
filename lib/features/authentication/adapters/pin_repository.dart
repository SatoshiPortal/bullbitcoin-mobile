import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/features/authentication/applications/authentication_application.dart';
import 'package:bb_mobile/features/authentication/applications/authentication_port.dart';
import 'package:bb_mobile/features/authentication/primitives/attempt.dart';
import 'package:bb_mobile/features/authentication/primitives/authentication_status.dart';

class PinRepository implements AuthenticationPort {
  final KeyValueStorageDatasource<String> _storage;

  static const _key =
      'securityKey'; // Use same key as in AuthCubit to stay backward compatible
  static const _failedUnlockAttemptsKey = 'failedUnlockAttemptsKey';

  PinRepository(this._storage);

  @override
  Future<bool> isRequired() async {
    final pin = await _storage.getValue(_key);
    return pin != null;
  }

  @override
  Future<void> enable(AuthenticationApplication authentication) async {
    final pin = (authentication as PinApplication);
    await _storage.saveValue(key: _key, value: pin.value);
  }

  @override
  Future<void> disable() async => await _storage.deleteValue(_key);

  @override
  Future<Attempt> verify(AuthenticationApplication authentication) async {
    final pin = (authentication as PinApplication);

    var lastAttempt = await fetchLastAttempt();
    if (lastAttempt != null && lastAttempt.timeout > Duration.zero) {
      return Attempt(
        status: AuthenticationStatus.ratelimited,
        attempts: lastAttempt.attempts,
        timeout: lastAttempt.timeout,
      );
    }

    final existingPin = await _storage.getValue(_key);
    if (existingPin == null) throw PinCodeNotSetException();

    if (existingPin != pin.value) {
      final newAttempts = lastAttempt!.attempts + 1;
      _setFailedUnlockAttempts(newAttempts);

      return Attempt(
        status: AuthenticationStatus.failed,
        attempts: newAttempts,
        timeout: _calculateTimeout(attempts: newAttempts),
      );
    }

    return Attempt(
      status: AuthenticationStatus.succeed,
      attempts: 0,
      timeout: Duration.zero,
    );
  }

  @override
  Future<Attempt?> fetchLastAttempt() async {
    final value = await _storage.getValue(_failedUnlockAttemptsKey);
    if (value == null) return null;

    final attempts = int.parse(value);
    return Attempt(
      status: AuthenticationStatus.failed,
      attempts: attempts,
      timeout: _calculateTimeout(attempts: attempts),
    );
  }

  Future<void> _setFailedUnlockAttempts(int attempts) async {
    await _storage.saveValue(
      key: _failedUnlockAttemptsKey,
      value: attempts.toString(),
    );
  }

  Duration _calculateTimeout({
    required int attempts,
    int timeoutMultiplier = 30,
  }) {
    if (attempts <= 3) return Duration.zero;
    return Duration(seconds: (attempts - 3) * timeoutMultiplier);
  }
}

class PinCodeNotSetException extends BullException {
  PinCodeNotSetException()
    : super('Pin code is not set. Use create method to set it.');
}

class InvalidPinCodeException extends BullException {
  InvalidPinCodeException(super.message);
}
