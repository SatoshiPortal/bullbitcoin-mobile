part of 'announcements_cubit.dart';

@freezed
sealed class AnnouncementsState with _$AnnouncementsState {
  const AnnouncementsState._();

  const factory AnnouncementsState({
    @Default([]) List<Announcement> announcements,
    AnnouncementsFailure? failure,
  }) = _AnnouncementsState;

  /// The section renders only when there's at least one announcement to show;
  /// the home carousel collapses to nothing otherwise.
  bool get hasVisibleAnnouncements => announcements.isNotEmpty;
}
