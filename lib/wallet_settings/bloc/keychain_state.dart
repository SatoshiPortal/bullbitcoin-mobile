import 'package:bb_mobile/_pkg/consts/passwords.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'keychain_state.freezed.dart';

enum KeyChainPageState { enter, confirm, recovery }

enum KeyChainInputType { pin, password }

enum KeySecretState { saved, recovered, none }

@freezed
class KeychainState with _$KeychainState {
  const factory KeychainState({
    @Default(false) bool loading,
    @Default(KeyChainPageState.enter) KeyChainPageState pageState,
    @Default(KeyChainInputType.pin) KeyChainInputType inputType,
    @Default(KeySecretState.none) KeySecretState keySecretState,
    @Default('') String secret,
    @Default('') String tempSecret,
    @Default(false) bool obscure,
    @Default('') String backupId,
    @Default('') String backupKey,
    @Default([]) List<int> backupSalt,
    @Default(false) bool isSecretConfirmed,
    @Default([]) List<int> shuffledNumbers,
    @Default('') String error,
  }) = _KeychainState;

  const KeychainState._();

  String displayPin() => 'x' * secret.length;

  static final _pinRegex = RegExp(r'^[0-9]{6,7}$');
  static final _uppercaseRegex = RegExp(r'(?=(?:.*[A-Z]){2})');
  static final _numbersRegex = RegExp(r'(?=(?:.*\d){2})');

  String? getValidationError() {
    if (secret.isEmpty) return null;

    if (inputType == KeyChainInputType.pin) {
      if (!_pinRegex.hasMatch(secret)) {
        return secret.length < 6
            ? 'PIN must be at least 6 digits long'
            : 'PIN must be less than 8 digits';
      }
      return validateSecret(secret) ? 'PIN contains a common pattern' : null;
    }

    if (secret.length < 7) {
      return 'Password must be at greater than 6 characters long';
    }
    if (!_uppercaseRegex.hasMatch(secret)) {
      return 'Password must contain at least 2 uppercase letters';
    }
    if (!_numbersRegex.hasMatch(secret)) {
      return 'Password must contain at least 2 numbers';
    }
    return validateSecret(secret)
        ? 'Password contains a common word or pattern'
        : null;
  }

  bool get isValid => getValidationError() == null;
  bool get showButton => isValid;
  bool get hasError => error.isNotEmpty;
  bool get isRecovering => pageState == KeyChainPageState.recovery;
  bool get canRecover => backupId.isNotEmpty && isValid && !loading;

  // Cache the compiled regex patterns
  static final _blacklistPattern = RegExp(
    r'\b(' +
        passwordBlacklist.map((word) => RegExp.escape(word)).join('|') +
        r')\b',
    caseSensitive: false,
  );

  bool validateSecret(String secret) => _blacklistPattern.hasMatch(secret);
}
