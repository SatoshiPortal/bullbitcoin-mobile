import 'package:freezed_annotation/freezed_annotation.dart';

part 'keychain_state.freezed.dart';

enum KeyChainPageState { enter, confirm }

enum KeyChainInputType { pin, password }

@freezed
class KeychainState with _$KeychainState {
  const factory KeychainState({
    @Default(false) bool saving,
    @Default(false) bool saved,
    @Default('') String error,
    @Default(false) bool loading,
    @Default([]) List<String> pin,
    @Default('') String password,
    @Default([]) List<int> shuffledNumbers,
    @Default(KeyChainPageState.enter) KeyChainPageState pageState,
    @Default(KeyChainInputType.pin) KeyChainInputType inputType,
    @Default('') String tempPin,
    @Default('') String tempPassword,
    @Default(false) bool pinConfirmed,
    @Default(false) bool passwordConfirmed,
  }) = _KeychainState;
  const KeychainState._();

  String displayPin() {
    final hide = List.filled(pin.length, 'x').join('');
    return hide;
  }

  bool showButton() {
    if (inputType == KeyChainInputType.pin) {
      return pin.length >= 6;
    } else {
      //TODO: Implement password  validation
      return password.isNotEmpty && password.length >= 6;
    }
  }

  bool get isPasswordValid => password.length >= 6;
}
