import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:nostr/nostr.dart';

part 'state.freezed.dart';

@freezed
class WhispersState with _$WhispersState {
  const factory WhispersState({
    @Default('') String toast,
    @Default({}) Map<String, List<Event>> privateEvents,
  }) = _WhispersState;
}
