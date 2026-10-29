import 'package:bb_mobile/core/swaps/domain/usecases/restore_swaps_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/entity/restored_swap.dart';
import 'package:bb_mobile/core/wallet/domain/bitcoin_sync_operation_exception.dart';
import 'package:primitives/primitives.dart';
import 'package:transaction_sync/transaction_sync.dart';
import 'package:meta/meta.dart';
import '../settings_failure.dart';

class RestoreSettingsSwapsUsecase {
  final RestoreSwapsUsecase _restore;
  RestoreSettingsSwapsUsecase({required this._restore});
  @useResult
  Future<Result<List<RestorableSwap>, SettingsFailure>> execute() async {
    try {
      return Ok(await _restore.execute());
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
