import 'dart:async';

import 'package:ark/ark.dart';
import 'package:bloc/bloc.dart';
import 'package:primitives/primitives.dart';

import '../domain/ark_display_data_port.dart';
import '../domain/ark_failure.dart';
import '../domain/usecases/read_ark_display_data_usecase.dart';
import '../domain/usecases/refresh_ark_board_source_usecase.dart';

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
  final RefreshArkBoardSourceUsecase? _refresh;
  Future<void>? _refreshing;
  bool _dirty = false;
  late final StreamSubscription<void> _changes;
  int _epoch = 0;

  ArkDisplayDataCubit(this._read, {required this.account, this._refresh})
    : super(const ArkDisplayDataLoading()) {
    _changes = _read.changes(account).listen((_) => unawaited(load()));
  }

  Future<void> load() async {
    if (isClosed) return;
    if (_refreshing != null) {
      _dirty = true;
      return;
    }
    final epoch = ++_epoch;
    emit(const ArkDisplayDataLoading());
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

  bool accepts(ArkDisplayData? observation) =>
      !isClosed &&
      _refreshing == null &&
      observation != null &&
      state is ArkDisplayDataReady &&
      identical((state as ArkDisplayDataReady).source, observation) &&
      (_refresh?.accepts(observation) ?? false);

  Future<void> refreshSource() {
    if (isClosed) return Future.value();
    return _refreshing ??= _refreshSource().whenComplete(() {
      _refreshing = null;
      if (_dirty && !isClosed) {
        _dirty = false;
        unawaited(load());
      }
    });
  }

  Future<void> _refreshSource() async {
    final refresh = _refresh;
    if (refresh == null) return;
    final epoch = ++_epoch;
    emit(const ArkDisplayDataLoading());
    final result = await refresh.execute(account);
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
