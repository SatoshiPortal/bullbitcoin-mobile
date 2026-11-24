import 'package:ark/ark.dart';
import 'package:bloc/bloc.dart';
import 'package:primitives/primitives.dart';

import '../domain/ark_board_preparation.dart';
import '../domain/ark_failure.dart';
import '../domain/usecases/prepare_ark_board_usecase.dart';
import '../domain/usecases/read_ark_board_minimum_usecase.dart';
import '../domain/usecases/read_ark_board_usecase.dart';
import '../domain/usecases/confirm_ark_board_usecase.dart';

sealed class ArkBoardState {
  const ArkBoardState();
}

final class ArkBoardEditing extends ArkBoardState {
  final ArkFailure? failure;
  const ArkBoardEditing([this.failure]);
}

final class ArkBoardBusy extends ArkBoardState {
  const ArkBoardBusy();
}

final class ArkBoardReviewed extends ArkBoardState {
  final ArkBoardPreparation preparation;

  /// Why the last confirm was refused before anything was signed.
  final ArkFailure? failure;

  const ArkBoardReviewed(this.preparation, [this.failure]);
}

final class ArkBoardPending extends ArkBoardState {
  final String? operationId;
  final ArkFailure failure;
  const ArkBoardPending(this.operationId, this.failure);
}

final class ArkBoardSubmitted extends ArkBoardState {
  final ArkOperation operation;
  const ArkBoardSubmitted(this.operation);
}

final class ArkBoardCubit extends Cubit<ArkBoardState> {
  final ArkAccountConfig config;
  final PrepareArkBoardUsecase _prepare;
  final ReadArkBoardUsecase _read;
  final ConfirmArkBoardUsecase _confirm;
  final ReadArkBoardMinimumUsecase _readMinimum;
  String? _operationId;
  Sats? _minimum;

  /// The source the user asked to board from, kept for a re-quote.
  String? _expectedSource;
  ArkBoardCubit(
    this._prepare,
    this._read,
    this._confirm,
    this._readMinimum, {
    required this.config,
  }) : super(const ArkBoardEditing());

  /// The server's minimum Board amount, once known.
  Sats? get minimum => _minimum;

  /// Await before showing the amount screen, so the minimum is known while
  /// the amount is typed rather than only after a refused Board.
  Future<void> loadMinimum() async {
    final minimum = await _readMinimum.execute(config.id);
    if (!isClosed && minimum != null) _minimum = minimum;
  }

  Future<void> prepare(Sats amount, {String? expectedSourceWalletId}) async {
    if (isClosed || state is! ArkBoardEditing) return;
    _expectedSource = expectedSourceWalletId;
    emit(const ArkBoardBusy());
    final result = await _prepare.execute(
      config,
      amount,
      expectedSourceWalletId: expectedSourceWalletId,
    );
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        _operationId = value.operationId;
        await _readOriginal(value.operationId);
      case Err(:final failure):
        // The server's refusal carries its current minimum.
        if (failure case ArkBoardBelowMinimumFailure(:final minimum)
            when minimum.value > BigInt.zero) {
          _minimum = minimum;
        }
        // The host answers an unknown outcome once a reservation may exist;
        // any other answer is a refusal with nothing held: the amount
        // screen shows why and the user may try again.
        if (_operationId == null && failure is! ArkSubmissionUncertainFailure) {
          emit(ArkBoardEditing(failure));
          return;
        }
        if (failure case ArkSubmissionUncertainFailure(:final operationId)) {
          _operationId = operationId;
        }
        emit(ArkBoardPending(_operationId, failure));
    }
  }

  Future<void> _readOriginal(String operationId) async {
    final result = await _read.execute(config.id, operationId);
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        emit(ArkBoardReviewed(value));
      case Err(:final failure):
        emit(ArkBoardPending(operationId, failure));
    }
  }

  Future<void> reconcile() async {
    if (isClosed || state is! ArkBoardPending) return;
    final id = _operationId;
    if (id == null || id.trim().isEmpty) return;
    emit(const ArkBoardBusy());
    await _readOriginal(
      id,
    ); // Host must refuse non-reviewable/unknown journal rows.
  }

  Future<void> confirm() async {
    if (isClosed) return;
    final current = state;
    if (current is! ArkBoardReviewed) return;
    emit(const ArkBoardBusy());
    // An expired review cannot be signed: price the same amount again and
    // show that fresh review to confirm.
    if (current.failure is ArkReviewExpiredFailure) {
      return _requote(current);
    }
    final result = await _confirm.execute(config.id, current.preparation);
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        emit(ArkBoardSubmitted(value));
      case Err(:final failure) when failure is! ArkSubmissionUncertainFailure:
        // Refused before signing: nothing left the wallet. Stay on the
        // review and say why, as the app does under its confirm buttons.
        emit(ArkBoardReviewed(current.preparation, failure));
      case Err(:final failure):
        emit(ArkBoardPending(_operationId, failure));
    }
  }

  Future<void> _requote(ArkBoardReviewed expired) async {
    final amount = expired.preparation.fundingAmount;
    final result = await _prepare.execute(
      config,
      amount,
      expectedSourceWalletId: _expectedSource,
    );
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        _operationId = value.operationId;
        await _readOriginal(value.operationId);
      case Err(:final failure) when failure is! ArkSubmissionUncertainFailure:
        emit(ArkBoardReviewed(expired.preparation, failure));
      case Err(:final failure):
        emit(ArkBoardPending(_operationId, failure));
    }
  }
}
