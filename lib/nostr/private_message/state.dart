import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:nostr/nostr.dart';

part 'state.freezed.dart';

@freezed
class PrivateMessageState with _$PrivateMessageState {
  const factory PrivateMessageState({
    @Default('') String toast,
    @Default('') String message,
    @Default('') String contact,
    @Default({}) Map<String, List<Event>> privateEvents,
  }) = _PrivateMessageState;
}
