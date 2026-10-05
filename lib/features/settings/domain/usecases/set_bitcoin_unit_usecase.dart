import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:meta/meta.dart';

class SetBitcoinUnitUsecase {
  final SettingsRepository _settingsRepository;

  const SetBitcoinUnitUsecase({required this._settingsRepository});

  @useResult
  Future<Result<void, SettingsFailure>> execute(BitcoinUnit bitcoinUnit) async {
    final result = await _settingsRepository.setBitcoinUnit(bitcoinUnit);

    return result.mapErr(
      (failure) => SettingsStorageFailure(failure.logMessage),
    );
  }
}
