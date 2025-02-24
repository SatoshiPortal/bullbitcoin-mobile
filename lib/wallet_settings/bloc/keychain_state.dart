import 'package:bb_mobile/_pkg/consts/passwords.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'keychain_state.freezed.dart';

enum KeyChainPageState {
  enter,
  confirm,
  recovery,
  delete;

  static KeyChainPageState fromString(String value) {
    return KeyChainPageState.values.firstWhere(
      (element) => element.name.toLowerCase() == value.toLowerCase(),
      orElse: () => KeyChainPageState.enter,
    );
  }
}

enum KeyChainInputType { pin, password, backupKey }

enum KeySecretState { none, saved, recovered, deleted }

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

  String? getValidationError() {
    if (secret.isEmpty) return null;

    if (inputType == KeyChainInputType.pin) {
      if (!RegExp(r'^[0-9]{6,7}$').hasMatch(secret)) {
        return secret.length < 6
            ? 'PIN must be at least 6 digits long'
            : 'PIN must be less than 8 digits';
      }
    }

    return validateSecret(secret)
        ? 'The password is among the top 1000 most common'
        : null;
  }

  bool get isValid => getValidationError() == null;
  bool get showButton => isValid;
  bool get hasError => error.isNotEmpty;
  bool get isRecovering => pageState == KeyChainPageState.recovery;
  bool get canRecoverKey => backupId.isNotEmpty && isValid && !loading;

  bool validateSecret(String secret) => commonPasswordsTop1000.contains(secret);
}
