import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:meta/meta.dart';

class SetHideAmountsUsecase {
  final SettingsRepository _settingsRepository;

  const SetHideAmountsUsecase({required this._settingsRepository});

  @useResult
  Future<Result<void, SettingsFailure>> execute(bool hide) async {
    final result = await _settingsRepository.setHideAmounts(hide);

    return result.mapErr(
      (failure) => SettingsStorageFailure(failure.logMessage),
    );
  }
}
