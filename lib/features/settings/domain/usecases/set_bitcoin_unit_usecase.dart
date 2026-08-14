import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';

class SetBitcoinUnitUsecase {
  final SettingsRepository _settingsRepository;

  SetBitcoinUnitUsecase({required this._settingsRepository});

  Future<void> execute(BitcoinUnit bitcoinUnit) async {
    await _settingsRepository.setBitcoinUnit(bitcoinUnit);
  }
}
