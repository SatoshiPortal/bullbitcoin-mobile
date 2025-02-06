import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:nostr/nostr.dart';

part 'social_state.freezed.dart';

@freezed
class SocialState with _$SocialState {
  const factory SocialState({
    @Default(0) int cached,
    @Default('') String toast,
    @Default('') String message,
    @Default([]) List<Event> events,
    @Default({}) Map<String, List<Event>> dms,
  }) = _SocialState;
}
