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

  String displayPin() => List.filled(secret.length, 'x').join('');

  bool get isValid => inputType == KeyChainInputType.pin
      ? secret.length == 6
      : secret.length >= 6;

  bool get showButton => isValid;
  bool get hasError => error.isNotEmpty;
  bool get isRecovering => pageState == KeyChainPageState.recovery;
  bool get canRecover => backupId.isNotEmpty && isValid && !loading;
}
