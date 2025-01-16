import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:nostr_sdk/nostr_sdk.dart';

part 'social_state.freezed.dart';

@freezed
class SocialState with _$SocialState {
  const factory SocialState({
    @Default('') String toast,
    @Default('') String message,
    @Default([]) List<Event> events,
    @Default({}) Map<String, List<UnsignedEvent>> dms,
  }) = _SocialState;
}
