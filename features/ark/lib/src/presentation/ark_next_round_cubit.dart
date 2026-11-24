import 'dart:async';

import 'package:ark/ark.dart';
import 'package:bloc/bloc.dart';
import 'package:primitives/primitives.dart';

import '../domain/usecases/read_ark_next_round_usecase.dart';

sealed class ArkNextRoundState {
  const ArkNextRoundState();
}

/// Nothing asked yet, or Ark is off.
final class ArkNextRoundIdle extends ArkNextRoundState {
  const ArkNextRoundIdle();
}

final class ArkNextRoundLoading extends ArkNextRoundState {
  const ArkNextRoundLoading();
}

final class ArkNextRoundKnown extends ArkNextRoundState {
  final DateTime start;
  const ArkNextRoundKnown(this.start);
}

/// The server could not be asked (offline, busy writer, background).
final class ArkNextRoundUnavailable extends ArkNextRoundState {
  const ArkNextRoundUnavailable();
}

/// Fetches the server's next round start once, then asks again only after
/// that round has started, or after [retryAfter] when the server was not
/// reachable. The countdown itself is rendered from [ArkNextRoundKnown.start].
final class ArkNextRoundCubit extends Cubit<ArkNextRoundState> {
  final ReadArkNextRoundUsecase _read;

  /// The clock the countdown is measured against; injectable for tests.
  final DateTime Function() now;
  final Duration retryAfter;
  ArkAccountId? _account;
  Timer? _timer;
  int _epoch = 0;

  ArkNextRoundCubit(
    this._read, {
    DateTime Function()? now,
    this.retryAfter = const Duration(seconds: 30),
  }) : now = now ?? DateTime.now,
       super(const ArkNextRoundIdle());

  /// Starts following [account]'s server schedule; repeated calls for the same
  /// account keep the current schedule.
  void watch(ArkAccountId account) {
    if (isClosed || _account == account) return;
    _account = account;
    unawaited(_fetch());
  }

  /// Stops asking the server, e.g. when Ark is turned off.
  void stop() {
    if (isClosed) return;
    _account = null;
    ++_epoch;
    _timer?.cancel();
    _timer = null;
    emit(const ArkNextRoundIdle());
  }

  Future<void> _fetch() async {
    final account = _account;
    if (isClosed || account == null) return;
    final epoch = ++_epoch;
    _timer?.cancel();
    _timer = null;
    if (state is! ArkNextRoundKnown) emit(const ArkNextRoundLoading());
    final result = await _read.execute(account);
    if (isClosed || epoch != _epoch || account != _account) return;
    switch (result) {
      case Ok(:final value):
        emit(ArkNextRoundKnown(value));
        final wait = value.difference(now());
        // A start already in the past would refetch in a tight loop; the
        // server moves on within one interval, so wait at least a bit.
        _schedule(wait < retryAfter ? retryAfter : wait, epoch);
      case Err():
        emit(const ArkNextRoundUnavailable());
        _schedule(retryAfter, epoch);
    }
  }

  void _schedule(Duration wait, int epoch) {
    _timer = Timer(wait, () {
      if (epoch == _epoch) unawaited(_fetch());
    });
  }

  @override
  Future<void> close() {
    ++_epoch;
    _timer?.cancel();
    return super.close();
  }
}
