import 'start_wallet_sync_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_sync_settings.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_sync_settings_repository.dart';
import 'package:bb_mobile/features/wallet_sync/domain/wallet_sync_selection.dart';
import 'package:bb_mobile/features/wallet_sync/domain/wallet_sync_options_failure.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

class SaveWalletSyncSettingsUsecase {
  final WalletSyncSettingsRepository _repository;
  final StartWalletSyncUsecase _start;

  SaveWalletSyncSettingsUsecase({
    required this._repository,
    required this._start,
  });

  @useResult
  Future<Result<WalletSyncSettings, WalletSyncOptionsFailure>> execute({
    required String walletId,
    required WalletSyncSelection selection,
    bool earlierOnly = false,
  }) async {
    switch (await _repository.updateBitcoinSyncSettings(
      walletId: walletId,
      source: selection.source,
      birthday: selection.birthday,
      earlierOnly: earlierOnly,
    )) {
      case Err():
        return const Err(WalletSyncOptionsStorageFailure());
      case Ok():
        final result = (await _repository.getSyncSettings(
          walletId,
        )).mapErr((_) => const WalletSyncOptionsStorageFailure());
        if (result is Ok) _start.execute(walletId, policyChanged: true);
        return result;
    }
  }
}
