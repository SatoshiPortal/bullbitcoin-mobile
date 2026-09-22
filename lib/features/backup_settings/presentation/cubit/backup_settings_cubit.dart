import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:bb_mobile/core/utils/result.dart';
part 'backup_settings_cubit.freezed.dart';
part 'backup_settings_state.dart';

class BackupSettingsCubit extends Cubit<BackupSettingsState> {
  BackupSettingsCubit({
    required this._getWalletsUsecase,
    required this._settingsRepository,
  }) : super(BackupSettingsState());

  final GetWalletsUsecase _getWalletsUsecase;
  final SettingsRepository _settingsRepository;

  Future<void> checkBackupStatus() async {
    emit(state.copyWith(status: BackupSettingsStatus.loading));

    final List<Wallet> defaultWallets;
    switch (await _getWalletsUsecase.execute(onlyDefaults: true)) {
      case Ok(:final value):
        defaultWallets = value;
      // "No wallets yet" is not a backup problem — there is nothing to back
      // up. The use case reports an empty result as a failure, so this has to
      // be matched explicitly or the intent below becomes unreachable.
      case Err(failure: NoWalletsFoundFailure()):
        emit(state.copyWith(status: BackupSettingsStatus.success));
        return;
      case Err(:final failure):
        log.warning('Backup status: ${failure.logMessage}');
        // The wallet layer's vocabulary stops here.
        emit(
          state.copyWith(
            status: BackupSettingsStatus.error,
            failure: BackupSettingsUnexpectedFailure(
              'wallets: ${failure.runtimeType}',
            ),
          ),
        );
        return;
    }

    try {
      final isDefaultPhysicalBackupTested = defaultWallets.every(
        (e) => e.isPhysicalBackupTested,
      );
      final isDefaultEncryptedBackupTested = defaultWallets.every(
        (e) => e.isEncryptedVaultTested,
      );

      final settings = await _settingsRepository.fetch();
      final environment = settings.environment;
      final network = Network.fromEnvironment(
        isTestnet: environment.isTestnet,
        isLiquid: false,
      );

      final lastPhysicalBackup = defaultWallets
          .firstWhere((e) => e.network == network)
          .latestPhysicalBackup;
      final lastEncryptedBackup = defaultWallets
          .firstWhere((e) => e.network == network)
          .latestEncryptedBackup;
      emit(
        state.copyWith(
          isDefaultPhysicalBackupTested: isDefaultPhysicalBackupTested,
          isDefaultEncryptedBackupTested: isDefaultEncryptedBackupTested,
          lastPhysicalBackup: lastPhysicalBackup,
          lastEncryptedBackup: lastEncryptedBackup,
          status: BackupSettingsStatus.success,
          failure: null,
        ),
      );
    } catch (e) {
      log.warning('checkBackupStatus failed', error: e);
      emit(
        state.copyWith(
          status: BackupSettingsStatus.error,
          failure: BackupSettingsUnexpectedFailure(e.toString()),
        ),
      );
    }
  }
}
