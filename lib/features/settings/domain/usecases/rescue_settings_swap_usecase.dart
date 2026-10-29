import 'package:bb_mobile/core/swaps/domain/usecases/rescue_swap_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/entity/restored_swap.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/wallet/domain/bitcoin_sync_operation_exception.dart';
import 'package:primitives/primitives.dart';
import 'package:transaction_sync/transaction_sync.dart';
import 'package:meta/meta.dart';
import '../settings_failure.dart';

class RescueSettingsSwapUsecase {
  final RescueSwapUsecase _rescue;
  RescueSettingsSwapUsecase({required this._rescue});
  @useResult
  Future<Result<Swap, SettingsFailure>> execute({
    required RestoredSwap restored,
    required String selectedWalletId,
  }) async {
    try {
      return Ok(
        await _rescue.execute(
          restored: restored,
          selectedWalletId: selectedWalletId,
        ),
      );
    } on BitcoinSyncOperationException catch (error) {
      return Err(
        error.failure is CbfRemoteLookupForbiddenFailure
            ? const SettingsSwapRecoveryUnavailableFailure()
            : const SettingsUnexpectedFailure(),
      );
    } on Exception {
      return const Err(SettingsUnexpectedFailure());
    }
  }
}
