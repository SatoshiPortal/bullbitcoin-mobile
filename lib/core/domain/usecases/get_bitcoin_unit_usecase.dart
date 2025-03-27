import 'package:bb_mobile/core/domain/entities/settings.dart';
import 'package:bb_mobile/core/domain/repositories/settings_repository.dart';

class GetBitcoinUnitUsecase {
  final SettingsRepository _settingsRepository;

  GetBitcoinUnitUsecase({
    required SettingsRepository settingsRepository,
  }) : _settingsRepository = settingsRepository;

  Future<BitcoinUnit> execute() async {
    final unit = await _settingsRepository.getBitcoinUnit();
    return unit;
  }
}
