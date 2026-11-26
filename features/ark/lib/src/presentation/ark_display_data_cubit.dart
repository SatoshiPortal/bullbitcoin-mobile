import 'dart:async';

import 'package:ark/ark.dart';
import 'package:bloc/bloc.dart';
import 'package:primitives/primitives.dart';

import '../domain/ark_display_data_port.dart';
import '../domain/ark_failure.dart';
import '../domain/usecases/read_ark_display_data_usecase.dart';

sealed class ArkDisplayDataState {
  const ArkDisplayDataState();
}

final class ArkDisplayDataLoading extends ArkDisplayDataState {
  const ArkDisplayDataLoading();
}

final class ArkDisplayDataReady extends ArkDisplayDataState {
  final ArkDisplayData source;
  const ArkDisplayDataReady(this.source);
}

final class ArkDisplayDataUnavailable extends ArkDisplayDataState {
  final ArkFailure failure;
  const ArkDisplayDataUnavailable(this.failure);
}

final class ArkDisplayDataCubit extends Cubit<ArkDisplayDataState> {
  final ReadArkDisplayDataUsecase _read;
  final ArkAccountId account;
  late final StreamSubscription<void> _changes;
  int _epoch = 0;

  ArkDisplayDataCubit(this._read, {required this.account})
    : super(const ArkDisplayDataLoading()) {
    _changes = _read.changes(account).listen((_) => unawaited(load()));
  }

  Future<void> load() async {
    if (isClosed) return;
    final epoch = ++_epoch;
    // A reload keeps the values on screen until fresh ones replace them:
    // clearing them first made every wallet change flash "Unavailable".
    // Display only; Board re-checks funds natively when it prepares.
    if (state is! ArkDisplayDataReady) emit(const ArkDisplayDataLoading());
    final result = await _read.execute(account);
    if (isClosed || epoch != _epoch) return;
    emit(switch (result) {
      Ok(:final value) when value.account == account => ArkDisplayDataReady(
        value,
      ),
      Ok() => const ArkDisplayDataUnavailable(ArkAccountRecoveryFailure()),
      Err(:final failure) => ArkDisplayDataUnavailable(failure),
    });
  }

  @override
  Future<void> close() async {
    ++_epoch;
    final closing = super.close();
    await _changes.cancel();
    await closing;
  }
}
