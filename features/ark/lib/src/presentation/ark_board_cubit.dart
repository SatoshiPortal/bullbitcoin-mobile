import 'package:ark/ark.dart';
import 'package:bloc/bloc.dart';
import 'package:primitives/primitives.dart';

import '../domain/ark_board_preparation.dart';
import '../domain/ark_failure.dart';
import '../domain/usecases/prepare_ark_board_usecase.dart';
import '../domain/usecases/read_ark_board_usecase.dart';
import '../domain/usecases/confirm_ark_board_usecase.dart';

sealed class ArkBoardState {
  const ArkBoardState();
}

final class ArkBoardEditing extends ArkBoardState {
  const ArkBoardEditing();
}

final class ArkBoardBusy extends ArkBoardState {
  const ArkBoardBusy();
}

final class ArkBoardReviewed extends ArkBoardState {
  final ArkBoardPreparation preparation;
  const ArkBoardReviewed(this.preparation);
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
  String? _operationId;
  ArkBoardCubit(
    this._prepare,
    this._read,
    this._confirm, {
    required this.config,
  }) : super(const ArkBoardEditing());

  Future<void> prepare(Sats amount) async {
    if (isClosed || state is! ArkBoardEditing) return;
    emit(const ArkBoardBusy());
    final result = await _prepare.execute(config, amount);
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        _operationId = value.operationId;
        await _readOriginal(value.operationId);
      case Err(:final failure):
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
    final result = await _confirm.execute(config.id, current.preparation);
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        emit(ArkBoardSubmitted(value));
      case Err(:final failure):
        emit(ArkBoardPending(_operationId, failure));
    }
  }
}
