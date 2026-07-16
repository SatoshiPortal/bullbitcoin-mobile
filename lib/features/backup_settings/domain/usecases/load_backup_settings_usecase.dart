import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/domain/entities/backup_settings_snapshot.dart';
import 'package:bb_mobile/features/backup_settings/domain/wallet_metadata_backup_settings_mapping.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/public/wallet_metadata_backup_facade.dart';
import 'package:meta/meta.dart';

class LoadBackupSettingsUsecase {
  final GetWalletsUsecase _getWallets;
  final SettingsRepository _settingsRepository;
  final WalletMetadataBackupFacade _metadataBackup;

  const LoadBackupSettingsUsecase(
    this._getWallets,
    this._settingsRepository,
    this._metadataBackup,
  );

  @useResult
  Future<Result<BackupSettingsSnapshot, BackupSettingsFailure>>
  execute() async {
    try {
      final metadataResult = await _metadataBackup.getState();
      final WalletMetadataBackupState metadataState;
      switch (metadataResult) {
        case Ok(:final value):
          metadataState = value;
        case Err(:final failure):
          return Err(mapWalletMetadataBackupFailure(failure));
      }

      final List<Wallet> defaultWallets;
      try {
        defaultWallets = await _getWallets.execute(onlyDefaults: true);
      } on NoWalletsFoundException {
        return Ok(_emptyWalletSnapshot(metadataState));
      }
      if (defaultWallets.isEmpty) {
        return Ok(_emptyWalletSnapshot(metadataState));
      }

      final settings = await _settingsRepository.fetch();
      final network = Network.fromEnvironment(
        isTestnet: settings.environment.isTestnet,
        isLiquid: false,
      );
      final networkWallet = defaultWallets
          .where((wallet) => wallet.network == network)
          .firstOrNull;
      return Ok(
        BackupSettingsSnapshot(
          isDefaultPhysicalBackupTested: defaultWallets.every(
            (wallet) => wallet.isPhysicalBackupTested,
          ),
          lastPhysicalBackup: networkWallet?.latestPhysicalBackup,
          isDefaultEncryptedBackupTested: defaultWallets.every(
            (wallet) => wallet.isEncryptedVaultTested,
          ),
          lastEncryptedBackup: networkWallet?.latestEncryptedBackup,
          walletMetadata: mapWalletMetadataBackupSettings(metadataState),
        ),
      );
    } on Exception catch (error, stack) {
      log.warning(
        'Load backup settings failed',
        error: StateError(error.runtimeType.toString()),
        trace: stack,
      );
      return Err(BackupSettingsUnexpectedFailure(error.runtimeType.toString()));
    }
  }

  BackupSettingsSnapshot _emptyWalletSnapshot(
    WalletMetadataBackupState metadataState,
  ) {
    return BackupSettingsSnapshot(
      isDefaultPhysicalBackupTested: false,
      lastPhysicalBackup: null,
      isDefaultEncryptedBackupTested: false,
      lastEncryptedBackup: null,
      walletMetadata: mapWalletMetadataBackupSettings(metadataState),
    );
  }
}
