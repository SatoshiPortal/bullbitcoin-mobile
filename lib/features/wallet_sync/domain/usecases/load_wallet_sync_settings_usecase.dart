import 'package:bb_mobile/core/wallet/domain/entities/wallet_sync_settings.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_sync_settings_repository.dart';
import 'package:bb_mobile/features/wallet_sync/domain/wallet_sync_options_failure.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

class LoadWalletSyncSettingsUsecase {
  final WalletSyncSettingsRepository _repository;

  LoadWalletSyncSettingsUsecase({required this._repository});

  @useResult
  Future<Result<WalletSyncSettings, WalletSyncOptionsFailure>> execute(
    String walletId,
  ) async => (await _repository.getSyncSettings(
    walletId,
  )).mapErr((_) => const WalletSyncOptionsStorageFailure());
}
