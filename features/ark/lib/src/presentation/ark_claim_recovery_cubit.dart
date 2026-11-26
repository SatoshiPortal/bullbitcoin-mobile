import 'package:ark/ark.dart';
import 'package:bloc/bloc.dart';
import 'package:primitives/primitives.dart';

import '../domain/ark_claim_recovery_selection.dart';
import '../domain/ark_failure.dart';
import '../domain/usecases/review_ark_claim_recovery_usecase.dart';
import '../domain/usecases/rebroadcast_ark_claim_usecase.dart';

sealed class ArkClaimRecoveryState {
  const ArkClaimRecoveryState();
}

final class ArkClaimRecoveryLoading extends ArkClaimRecoveryState {
  const ArkClaimRecoveryLoading();
}

final class ArkClaimRecoveryReady extends ArkClaimRecoveryState {
  final ArkClaimRecoverySelection selection;
  const ArkClaimRecoveryReady(this.selection);
}

final class ArkClaimRecoverySubmitting extends ArkClaimRecoveryState {
  final ArkClaimRecoverySelection selection;
  const ArkClaimRecoverySubmitting(this.selection);
}

final class ArkClaimRecoveryFailed extends ArkClaimRecoveryState {
  final ArkFailure failure;
  final ArkClaimRecoverySelection? lastReview;
  const ArkClaimRecoveryFailed(this.failure, {this.lastReview});
}

final class ArkClaimRecoveryFinished extends ArkClaimRecoveryState {
  final ArkOperation operation;
  const ArkClaimRecoveryFinished(this.operation);
}

/// Review loading reads only. Each sending attempt needs a fresh user action;
/// neither a lost reply nor a rebuilt screen implicitly submits the command.
final class ArkClaimRecoveryCubit extends Cubit<ArkClaimRecoveryState> {
  final ArkAccountId account;
  final String operationId;
  final ReviewArkClaimRecoveryUsecase _review;
  final RebroadcastArkClaimUsecase _rebroadcast;
  bool _loading = false;
  ArkClaimRecoveryCubit(
    this._review,
    this._rebroadcast, {
    required this.account,
    required this.operationId,
  }) : super(const ArkClaimRecoveryLoading());

  Future<void> load() async {
    if (isClosed || _loading || state is ArkClaimRecoverySubmitting) return;
    _loading = true;
    emit(const ArkClaimRecoveryLoading());
    try {
      final result = await _review.execute(account, operationId);
      if (isClosed) return;
      switch (result) {
        case Ok(:final value):
          emit(ArkClaimRecoveryReady(value));
        case Err(:final failure):
          emit(ArkClaimRecoveryFailed(failure));
      }
    } finally {
      _loading = false;
    }
  }

  Future<void> confirm() async {
    final current = state;
    if (isClosed || current is! ArkClaimRecoveryReady) return;
    emit(ArkClaimRecoverySubmitting(current.selection));
    final result = await _rebroadcast.execute(account, current.selection);
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        emit(ArkClaimRecoveryFinished(value));
      case Err(:final failure):
        emit(ArkClaimRecoveryFailed(failure, lastReview: current.selection));
    }
  }
}
