import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/restore_bullvault_usecase.dart';
import 'package:bb_mobile/features/bullvault/presentation/bullvault_restore_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

final class BullVaultRestoreCubit extends Cubit<BullVaultRestoreState> {
  final RestoreBullVaultUsecase _restoreUsecase;

  BullVaultRestoreCubit(this._restoreUsecase)
    : super(const BullVaultRestoreState());

  Future<void> restore({
    required BullVaultRestoreInputKind kind,
    required String source,
    required String label,
    String? mobilePassphrase,
  }) async {
    if (state.isRestoring) return;
    emit(state.copyWith(isRestoring: true, clearFailure: true));
    final result = await _restoreUsecase.execute(
      kind: kind,
      source: source,
      label: label,
      mobilePassphrase: mobilePassphrase,
    );
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        emit(state.copyWith(isRestoring: false, result: value));
      case Err(:final failure):
        emit(state.copyWith(isRestoring: false, failure: failure));
    }
  }
}
