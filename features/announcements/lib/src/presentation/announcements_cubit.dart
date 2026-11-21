import 'dart:async';

import 'package:announcements/src/domain/announcements_failure.dart';
import 'package:announcements/src/domain/usecases/dismiss_announcement_usecase.dart';
import 'package:announcements/src/domain/entities/announcement.dart';
import 'package:announcements/src/domain/usecases/get_visible_announcements_usecase.dart';
import 'package:announcements/src/domain/usecases/watch_app_update_announcement_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'announcements_cubit.freezed.dart';
part 'announcements_state.dart';

/// Thin presentation seam for the home announcements carousel.
///
/// It only: loads the currently-visible announcements, re-evaluates when a
/// swap service starts requiring an app update, and records dismissals.
/// All decision logic lives in the use cases and entities.
class AnnouncementsCubit extends Cubit<AnnouncementsState> {
  final GetVisibleAnnouncementsUsecase _getVisibleAnnouncementsUsecase;
  final DismissAnnouncementUsecase _dismissAnnouncementUsecase;
  late final StreamSubscription<bool> _appUpdateRequiredSubscription;

  bool _refreshing = false;
  bool _refreshQueued = false;

  AnnouncementsCubit({
    required this._getVisibleAnnouncementsUsecase,
    required this._dismissAnnouncementUsecase,
    required WatchAppUpdateAnnouncementUsecase
    watchAppUpdateAnnouncementUsecase,
  }) : super(const AnnouncementsState()) {
    _appUpdateRequiredSubscription = watchAppUpdateAnnouncementUsecase
        .execute()
        .where((isRequired) => isRequired)
        .listen((_) => unawaited(refresh()));
  }

  /// (Re)loads the visible announcements. Called on mount and whenever a
  /// trigger signal changes.
  ///
  /// Overlapping calls are coalesced: a request arriving while a load is in
  /// flight re-runs once after it completes, so a dismissal and an update
  /// signal can't produce redundant, out-of-order loads.
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
          (announcements) =>
              emit(AnnouncementsState(announcements: announcements)),
          (failure) => emit(state.copyWith(failure: failure)),
        );
      } while (_refreshQueued);
    } finally {
      _refreshing = false;
    }
  }

  /// Records a dismissal and refreshes the list (which collapses the section
  /// when the last card is dismissed).
  Future<void> dismiss(AnnouncementId id) async {
    final result = await _dismissAnnouncementUsecase.execute(id);
    if (isClosed) return;
    await result.fold(
      (_) => refresh(),
      (failure) async => emit(state.copyWith(failure: failure)),
    );
  }

  @override
  Future<void> close() async {
    await _appUpdateRequiredSubscription.cancel();
    return super.close();
  }
}
