
import 'package:bb_mobile/core/settings/domain/entity/settings.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';

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
