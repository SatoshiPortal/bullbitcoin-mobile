import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/domain/import_watch_only_failure.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/watch_only_wallet_entity.dart';
import 'package:meta/meta.dart';

class ValidateWatchOnlyImportUsecase {
  final SettingsRepository _settings;

  ValidateWatchOnlyImportUsecase({required this._settings});

  @useResult
  Future<Result<WatchOnlyWalletEntity, ImportWatchOnlyFailure>> execute(
    WatchOnlyWalletEntity? wallet,
  ) async {
    if (wallet == null) return const Err(NoWalletSelectedFailure());
    if (wallet.label.trim().isEmpty) return const Err(LabelRequiredFailure());
    try {
      final settings = await _settings.fetch();
      if (wallet.network.isMainnet != settings.environment.isMainnet) {
        return const Err(NetworkMismatchFailure());
      }
      return Ok(wallet);
    } on Exception {
      return const Err(ImportFailedFailure());
    }
  }
}
