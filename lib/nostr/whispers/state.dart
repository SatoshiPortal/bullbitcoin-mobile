import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:nostr_sdk/nostr_sdk.dart';

part 'state.freezed.dart';

@freezed
class WhispersState with _$WhispersState {
  const factory WhispersState({
    @Default('') String toast,
    @Default({}) Map<String, List<UnsignedEvent>> privateEvents,
  }) = _WhispersState;
}
