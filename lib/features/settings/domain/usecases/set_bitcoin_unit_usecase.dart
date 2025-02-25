import 'package:bb_mobile/core/domain/entities/settings.dart';
import 'package:bb_mobile/core/domain/repositories/settings_repository.dart';

class SetBitcoinUnitUseCase {
  final SettingsRepository _settingsRepository;

  SetBitcoinUnitUseCase({
    required SettingsRepository settingsRepository,
  }) : _settingsRepository = settingsRepository;

  Future<void> execute(BitcoinUnit bitcoinUnit) async {
    await _settingsRepository.setBitcoinUnit(bitcoinUnit);
  }
}
