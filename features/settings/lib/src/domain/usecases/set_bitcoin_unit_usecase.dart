import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';
import 'package:settings/src/domain/settings_failure.dart';
import 'package:meta/meta.dart';

class SetBitcoinUnitUsecase {
  final Preferences _settingsRepository;

  const SetBitcoinUnitUsecase({required this._settingsRepository});

  @useResult
  Future<Result<void, SettingsFailure>> execute(BitcoinUnit bitcoinUnit) async {
    final result = await _settingsRepository.setBitcoinUnit(bitcoinUnit);

    return result.mapErr(
      (failure) => SettingsStorageFailure(failure.logMessage),
    );
  }
}
