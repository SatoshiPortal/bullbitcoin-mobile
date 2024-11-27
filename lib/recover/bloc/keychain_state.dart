import 'package:freezed_annotation/freezed_annotation.dart';

part 'keychain_state.freezed.dart';

@freezed
class KeychainState with _$KeychainState {
  const factory KeychainState({
    @Default('') String error,
    @Default('') String backupKey,
    @Default('') String backupId,
    @Default('') String secret,
  }) = _KeychainState;
}
