import '../../domain/settings_failure.dart';
import '../../domain/usecases/restore_settings_swaps_usecase.dart';
import 'package:primitives/primitives.dart';
import 'package:bb_mobile/core/swaps/domain/entity/restored_swap.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/restore_swaps_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum SwapRestoreStatus { initial, loading, success, error }

class SwapRestoreState {
  final SwapRestoreStatus status;
  final List<RestorableSwap> swaps;
  final SettingsFailure? failure;

  const SwapRestoreState({
    this.status = SwapRestoreStatus.initial,
    this.swaps = const [],
    this.failure,
  });

  int get storedCount => swaps.where((s) => s.existsLocally).length;
  int get total => swaps.length;
  bool get allStoredLocally =>
      swaps.isNotEmpty && swaps.every((s) => s.existsLocally);

  /// Swaps the user can act on here: funds locked & unresolved, not yet imported.
  List<RestorableSwap> get recoverableSwaps =>
      swaps.where((s) => s.isRescuable).toList();

  /// Display-only swaps: resolved, never funded, or already imported.
  List<RestorableSwap> get otherSwaps =>
      swaps.where((s) => !s.isRescuable).toList();

  int get actionableCount => recoverableSwaps.length;

  SwapRestoreState copyWith({
    SwapRestoreStatus? status,
    List<RestorableSwap>? swaps,
    SettingsFailure? failure,
  }) {
    return SwapRestoreState(
      status: status ?? this.status,
      swaps: swaps ?? this.swaps,
      failure: failure,
    );
  }
}

class SwapRestoreCubit extends Cubit<SwapRestoreState> {
  final RestoreSwapsUsecase _restoreSwapsUsecase;
  late final _restore = RestoreSettingsSwapsUsecase(
    restore: _restoreSwapsUsecase,
  );

  SwapRestoreCubit({required this._restoreSwapsUsecase})
    : super(const SwapRestoreState());

  Future<void> restore() async {
    emit(state.copyWith(status: SwapRestoreStatus.loading));
    final result = await _restore.execute();
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        emit(state.copyWith(status: SwapRestoreStatus.success, swaps: value));
      case Err(:final failure):
        emit(state.copyWith(status: SwapRestoreStatus.error, failure: failure));
    }
  }
}
