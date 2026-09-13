import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/import_bullvault_cosigner_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

final class BullVaultCosignerState {
  final bool busy;
  final bool imported;
  final BullVaultFailure? failure;
  const BullVaultCosignerState({
    this.busy = false,
    this.imported = false,
    this.failure,
  });
}

final class BullVaultCosignerCubit extends Cubit<BullVaultCosignerState> {
  final ImportBullVaultCosignerUsecase _import;
  BullVaultCosignerCubit(this._import) : super(const BullVaultCosignerState());

  Future<void> import({
    required String walletId,
    required String words,
    required String passphrase,
  }) async {
    if (state.busy) return;
    emit(const BullVaultCosignerState(busy: true));
    final result = await _import.execute(
      walletId: walletId,
      words: words,
      passphrase: passphrase,
    );
    if (isClosed) return;
    emit(switch (result) {
      Ok() => const BullVaultCosignerState(imported: true),
      Err(:final failure) => BullVaultCosignerState(failure: failure),
    });
  }
}
