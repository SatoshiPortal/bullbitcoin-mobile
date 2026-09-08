import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_finished_wallet_syncs_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_details.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/get_bullvault_details_usecase.dart';

class WatchBullVaultDetailsUsecase {
  final WatchFinishedWalletSyncsUsecase _watchSyncsUsecase;
  final GetBullVaultDetailsUsecase _getDetailsUsecase;

  const WatchBullVaultDetailsUsecase(
    this._watchSyncsUsecase,
    this._getDetailsUsecase,
  );

  Stream<Result<BullVaultDetails?, BullVaultFailure>> execute(
    String walletId,
  ) async* {
    await for (final wallet in _watchSyncsUsecase.execute()) {
      if (!wallet.isBitcoin) continue;
      final result = await _getDetailsUsecase.execute(
        walletId,
        syncedWalletId: wallet.id,
      );
      if (result case Ok(value: null)) continue;
      yield result;
    }
  }
}
