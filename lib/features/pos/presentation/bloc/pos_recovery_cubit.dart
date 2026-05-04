import 'package:bb_mobile/features/pos/application/usecases/run_swap_recovery_usecase.dart';
import 'package:bb_mobile/features/pos/domain/value_objects/pos_ref.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nostr_pos/nostr_pos.dart' as nostr;

class PosRecoveryState {
  const PosRecoveryState({
    this.isLoading = false,
    this.results = const [],
    this.error,
  });

  final bool isLoading;
  final List<nostr.ControllerRecoveryResult> results;
  final String? error;

  PosRecoveryState copyWith({
    bool? isLoading,
    List<nostr.ControllerRecoveryResult>? results,
    String? error,
    bool clearError = false,
  }) {
    return PosRecoveryState(
      isLoading: isLoading ?? this.isLoading,
      results: results ?? this.results,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class PosRecoveryCubit extends Cubit<PosRecoveryState> {
  PosRecoveryCubit({required RunSwapRecoveryUsecase runSwapRecoveryUsecase})
    : _runSwapRecoveryUsecase = runSwapRecoveryUsecase,
      super(const PosRecoveryState());

  final RunSwapRecoveryUsecase _runSwapRecoveryUsecase;

  Future<void> run(PosRef ref) async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final results = await _runSwapRecoveryUsecase.execute(ref: ref);
      emit(state.copyWith(isLoading: false, results: results));
    } catch (error) {
      emit(state.copyWith(isLoading: false, error: '$error'));
    }
  }
}
