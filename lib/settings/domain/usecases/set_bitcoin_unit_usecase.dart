import 'package:bb_mobile/_core/domain/entities/settings.dart';
import 'package:bb_mobile/_core/domain/repositories/settings_repository.dart';

class SetBitcoinUnitUsecase {
  final SettingsRepository _settingsRepository;

  SetBitcoinUnitUsecase({
    required SettingsRepository settingsRepository,
  }) : _settingsRepository = settingsRepository;

  Future<void> execute(BitcoinUnit bitcoinUnit) async {
    await _settingsRepository.setBitcoinUnit(bitcoinUnit);
  }
}
