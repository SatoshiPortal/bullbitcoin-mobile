import 'package:freezed_annotation/freezed_annotation.dart';

part 'keychain_state.freezed.dart';

@freezed
class KeychainState with _$KeychainState {
  const factory KeychainState({
    @Default(false) bool completed,
    @Default('') String secret,
    @Default(false) bool secretConfirmed,
    @Default('') String error,
  }) = _KeychainState;
}
