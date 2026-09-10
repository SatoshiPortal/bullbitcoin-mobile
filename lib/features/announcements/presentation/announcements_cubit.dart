import 'dart:async';

import 'package:bb_mobile/features/announcements/domain/announcements_failure.dart';
import 'package:bb_mobile/features/announcements/domain/usecases/dismiss_announcement_usecase.dart';
import 'package:bb_mobile/features/announcements/domain/entities/announcement.dart';
import 'package:bb_mobile/features/announcements/domain/usecases/get_visible_announcements_usecase.dart';
import 'package:bb_mobile/features/announcements/domain/usecases/watch_app_update_announcement_usecase.dart';
import 'package:bb_mobile/features/announcements/domain/entities/recoverbull_announcement.dart';
import 'package:bb_mobile/features/announcements/domain/usecases/watch_recoverbull_announcements_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'announcements_cubit.freezed.dart';
part 'announcements_state.dart';

/// Thin presentation seam for the home announcements carousel.
///
/// It only: loads the currently-visible announcements, re-evaluates when a
/// relevant signal changes (a wallet finishing a sync — which is when the
/// balance signal moves), and records dismissals. All decision logic lives in
/// the use-cases / entities.
class AnnouncementsCubit extends Cubit<AnnouncementsState> {
  final GetVisibleAnnouncementsUsecase _getVisibleAnnouncementsUsecase;
  final DismissAnnouncementUsecase _dismissAnnouncementUsecase;
  late final StreamSubscription<bool> _appUpdateRequiredSubscription;
  late final StreamSubscription<List<RecoverBullAnnouncement>>
  _recoverBullSubscription;
  List<RecoverBullAnnouncement> _recoverBullAnnouncements = const [];

  bool _refreshing = false;
  bool _refreshQueued = false;

  AnnouncementsCubit({
    required this._getVisibleAnnouncementsUsecase,
    required this._dismissAnnouncementUsecase,
    required WatchAppUpdateAnnouncementUsecase
    watchAppUpdateAnnouncementUsecase,
    WatchRecoverBullAnnouncementsUsecase? watchRecoverBullAnnouncementsUsecase,
  }) : super(const AnnouncementsState()) {
    _appUpdateRequiredSubscription = watchAppUpdateAnnouncementUsecase
        .execute()
        .where((isRequired) => isRequired)
        .listen((_) => unawaited(refresh()));
    _recoverBullSubscription =
        (watchRecoverBullAnnouncementsUsecase?.execute() ??
                const Stream<List<RecoverBullAnnouncement>>.empty())
            .listen((announcements) {
              _recoverBullAnnouncements = announcements;
              unawaited(refresh());
            });
  }

  /// (Re)loads the visible announcements. Called on mount and whenever a
  /// trigger signal changes.
  ///
  /// Overlapping calls are coalesced: a request arriving while a load is in
  /// flight re-runs once after it completes, so several wallets syncing
  /// back-to-back can't spawn redundant, out-of-order loads.
  Future<void> refresh() async {
    if (_refreshing) {
      _refreshQueued = true;
      return;
    }
    _refreshing = true;
    try {
      do {
        _refreshQueued = false;
        final result = await _getVisibleAnnouncementsUsecase.execute();
        if (isClosed) return;
        result.fold(
          (announcements) => emit(
            AnnouncementsState(
              announcements: _sorted([
                ...announcements,
                ..._recoverBullAnnouncements,
              ]),
            ),
          ),
          (failure) => emit(state.copyWith(failure: failure)),
        );
      } while (_refreshQueued);
    } finally {
      _refreshing = false;
    }
  }

  List<Announcement> _sorted(List<Announcement> announcements) =>
      announcements..sort((a, b) {
        final priority = a.priority.compareTo(b.priority);
        if (priority != 0) return priority;
        return (a.stableKey ?? a.id.name).compareTo(b.stableKey ?? b.id.name);
      });

  /// Records a dismissal and refreshes the list (which collapses the section
  /// when the last card is dismissed).
  Future<void> dismiss(Announcement announcement) async {
    final result = await _dismissAnnouncementUsecase.execute(announcement);
    if (isClosed) return;
    await result.fold(
      (_) => refresh(),
      (failure) async => emit(state.copyWith(failure: failure)),
    );
  }

  @override
  Future<void> close() async {
    await _appUpdateRequiredSubscription.cancel();
    await _recoverBullSubscription.cancel();
    return super.close();
  }
}
