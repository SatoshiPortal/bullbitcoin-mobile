import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/import_bullvault_cosigner_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

sealed class BullVaultCosignerState {
  const BullVaultCosignerState();
}

final class BullVaultCosignerReady extends BullVaultCosignerState {
  const BullVaultCosignerReady();
}

final class BullVaultCosignerImporting extends BullVaultCosignerState {
  const BullVaultCosignerImporting();
}

final class BullVaultCosignerAttached extends BullVaultCosignerState {
  const BullVaultCosignerAttached();
}

final class BullVaultCosignerFailed extends BullVaultCosignerState {
  final BullVaultFailure failure;
  const BullVaultCosignerFailed(this.failure);
}

final class BullVaultCosignerCubit extends Cubit<BullVaultCosignerState> {
  final ImportBullVaultCosignerUsecase _import;
  final String walletId;
  BullVaultCosignerCubit(this._import, {required this.walletId})
    : super(const BullVaultCosignerReady());

  Future<void> attach({required List<String> words, String? passphrase}) async {
    if (isClosed ||
        state is BullVaultCosignerImporting ||
        state is BullVaultCosignerAttached) {
      return;
    }
    emit(const BullVaultCosignerImporting());
    final result = await _import.execute(
      walletId: walletId,
      words: words,
      passphrase: passphrase,
    );
    if (isClosed) return;
    emit(switch (result) {
      Ok() => const BullVaultCosignerAttached(),
      Err(:final failure) => BullVaultCosignerFailed(failure),
    });
  }
}
