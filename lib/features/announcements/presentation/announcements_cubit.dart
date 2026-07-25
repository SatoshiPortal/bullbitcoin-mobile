import 'dart:async';

import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_finished_wallet_syncs_usecase.dart';
import 'package:bb_mobile/features/announcements/domain/announcements_failure.dart';
import 'package:bb_mobile/features/announcements/domain/usecases/dismiss_announcement_usecase.dart';
import 'package:bb_mobile/features/announcements/domain/entities/announcement.dart';
import 'package:bb_mobile/features/announcements/domain/usecases/get_visible_announcements_usecase.dart';
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
  final WatchFinishedWalletSyncsUsecase _watchFinishedWalletSyncsUsecase;

  StreamSubscription<Wallet>? _walletSyncSub;

  bool _refreshing = false;
  bool _refreshQueued = false;

  AnnouncementsCubit({
    required this._getVisibleAnnouncementsUsecase,
    required this._dismissAnnouncementUsecase,
    required this._watchFinishedWalletSyncsUsecase,
  }) : super(const AnnouncementsState()) {
    // Re-evaluate after each wallet sync: the Liquid balance (the autoswap
    // trigger signal) only moves when a sync lands.
    _walletSyncSub = _watchFinishedWalletSyncsUsecase.execute().listen(
      (_) => refresh(),
    );
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
  Future<void> close() {
    _walletSyncSub?.cancel();
    return super.close();
  }
}
