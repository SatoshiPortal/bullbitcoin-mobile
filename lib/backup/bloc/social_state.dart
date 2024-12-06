import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:nostr/nostr.dart';

part 'social_state.freezed.dart';

@freezed
class SocialState with _$SocialState {
  const factory SocialState({
    @Default('') String error,
    @Default([]) List<Event> messages,
    @Default({}) Map<String, Event> filter,
  }) = _SocialState;
}
