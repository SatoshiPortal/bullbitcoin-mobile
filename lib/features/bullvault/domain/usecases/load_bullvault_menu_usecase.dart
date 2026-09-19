import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_record.dart';
import 'package:bb_mobile/features/bullvault/domain/repositories/bullvault_repository.dart';
import 'package:meta/meta.dart';

class LoadBullVaultMenuUsecase {
  final BullVaultRepository _records;
  final GetSettingsUsecase _getSettings;
  const LoadBullVaultMenuUsecase(this._records, this._getSettings);

  @useResult
  Future<Result<List<BullVaultRecord>, BullVaultFailure>> execute() async {
    try {
      final settings = await _getSettings.execute();
      return await _records.getVisible(
        Network.fromEnvironment(
          isTestnet: settings.environment.isTestnet,
          isLiquid: false,
        ),
      );
    } on Exception {
      return const Err(BullVaultBackupStatusFailure());
    }
  }
}
