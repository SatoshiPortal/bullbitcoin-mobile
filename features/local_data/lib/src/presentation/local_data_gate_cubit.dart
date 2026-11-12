import 'package:bull_local_data/src/domain/local_data_failure.dart';
import 'package:bull_local_data/src/domain/usecases/reset_local_database_usecase.dart';
import 'package:bull_local_data/src/presentation/local_data_gate_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:primitives/primitives.dart';

/// Serialises the gate's two actions: a retry and a consented reset never overlap, and neither runs twice at once.
class LocalDataGateCubit extends Cubit<LocalDataGateState> {
  final ResetLocalDatabaseUsecase _reset;
  final Future<void> Function() _retry;

  LocalDataGateCubit({
    required LocalDataFailure failure,
    required this._reset,
    required this._retry,
  }) : super(LocalDataGateState(failure: failure));

  Future<void> retry() async {
    if (state.busy) return;
    emit(state.copyWith(busy: true));
    await _retry();
  }

  /// Erases the database named by the failure, then starts again. Only reachable from an unrecoverable failure, after the user confirmed.
  Future<void> reset() async {
    final failure = state.failure;
    if (state.busy || failure is! LocalDataUnrecoverableFailure) return;
    emit(state.copyWith(busy: true, resetFailure: () => null));
    switch (await _reset.execute(failure.database)) {
      case Ok():
        await _retry();
      case Err(failure: final resetFailure):
        emit(state.copyWith(busy: false, resetFailure: () => resetFailure));
    }
  }
}
