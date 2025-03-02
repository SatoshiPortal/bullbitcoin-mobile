import 'package:bb_mobile/_core/domain/entities/settings.dart';
import 'package:bb_mobile/_core/domain/repositories/settings_repository.dart';

class GetBitcoinUnitUseCase {
  final SettingsRepository _settingsRepository;

  GetBitcoinUnitUseCase({
    required SettingsRepository settingsRepository,
  }) : _settingsRepository = settingsRepository;

  Future<BitcoinUnit> execute() async {
    final unit = await _settingsRepository.getBitcoinUnit();
    return unit;
  }
}
