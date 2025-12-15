import 'package:bb_mobile/core_deprecated/settings/data/settings_repository.dart';
import 'package:bb_mobile/core_deprecated/settings/domain/settings_entity.dart';

class SetBitcoinUnitUsecase {
  final SettingsRepository _settingsRepository;

  SetBitcoinUnitUsecase({
    required SettingsRepository settingsRepository,
  }) : _settingsRepository = settingsRepository;

  Future<void> execute(BitcoinUnit bitcoinUnit) async {
    await _settingsRepository.setBitcoinUnit(bitcoinUnit);
  }
}
