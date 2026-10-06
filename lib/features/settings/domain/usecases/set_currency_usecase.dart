import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:meta/meta.dart';

class SetCurrencyUsecase {
  final SettingsRepository _settingsRepository;

  const SetCurrencyUsecase({required this._settingsRepository});

  @useResult
  Future<Result<void, SettingsFailure>> execute(String currencyCode) async {
    final result = await _settingsRepository.setCurrency(currencyCode);

    return result.mapErr(
      (failure) => SettingsStorageFailure(failure.logMessage),
    );
  }
}
