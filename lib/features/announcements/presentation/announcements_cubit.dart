import 'dart:async';

import 'package:bb_mobile/core/settings/domain/watch_payjoin_enabled_changes_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_finished_wallet_syncs_usecase.dart';
import 'package:bb_mobile/features/announcements/domain/announcements_failure.dart';
import 'package:bb_mobile/features/announcements/domain/dismiss_announcement_usecase.dart';
import 'package:bb_mobile/features/announcements/domain/entities/announcement.dart';
import 'package:bb_mobile/features/announcements/domain/get_visible_announcements_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'announcements_cubit.freezed.dart';
part 'announcements_state.dart';

/// Thin presentation seam for the home announcements carousel.
///
/// It only: loads the currently-visible announcements, re-evaluates when a
/// relevant signal changes (payjoin toggled elsewhere, or a wallet finishing a
/// sync — which is when transaction history first appears after a recovery),
/// and records dismissals. All decision logic lives in the use-cases /
/// entities.
class AnnouncementsCubit extends Cubit<AnnouncementsState> {
  final GetVisibleAnnouncementsUsecase _getVisibleAnnouncementsUsecase;
  final DismissAnnouncementUsecase _dismissAnnouncementUsecase;
  final WatchPayjoinEnabledChangesUsecase _watchPayjoinEnabledChangesUsecase;
  final WatchFinishedWalletSyncsUsecase _watchFinishedWalletSyncsUsecase;

  StreamSubscription<bool>? _payjoinEnabledSub;
  StreamSubscription<Wallet>? _walletSyncSub;

  AnnouncementsCubit({
    required this._getVisibleAnnouncementsUsecase,
    required this._dismissAnnouncementUsecase,
    required this._watchPayjoinEnabledChangesUsecase,
    required this._watchFinishedWalletSyncsUsecase,
  }) : super(const AnnouncementsState()) {
    _payjoinEnabledSub = _watchPayjoinEnabledChangesUsecase.execute().listen(
      (_) => refresh(),
    );
    // Re-evaluate after each wallet sync: a freshly recovered wallet only gets
    // its transaction history (the payjoin-privacy trigger) once it syncs.
    _walletSyncSub = _watchFinishedWalletSyncsUsecase.execute().listen(
      (_) => refresh(),
    );
  }

  /// (Re)loads the visible announcements. Called on mount and whenever a
  /// trigger signal changes.
  Future<void> refresh() async {
    final result = await _getVisibleAnnouncementsUsecase.execute();
    result.fold(
      (announcements) => emit(AnnouncementsState(announcements: announcements)),
      (failure) => emit(state.copyWith(failure: failure)),
    );
  }

  /// Records a dismissal and refreshes the list (which collapses the section
  /// when the last card is dismissed).
  Future<void> dismiss(AnnouncementId id) async {
    final result = await _dismissAnnouncementUsecase.execute(id);
    await result.fold(
      (_) => refresh(),
      (failure) async => emit(state.copyWith(failure: failure)),
    );
  }

  @override
  Future<void> close() {
    _payjoinEnabledSub?.cancel();
    _walletSyncSub?.cancel();
    return super.close();
  }
}
