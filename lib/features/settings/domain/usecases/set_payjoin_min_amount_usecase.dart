import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/utils/constants.dart';

class SetPayjoinMinAmountUsecase {
  final SettingsRepository _settingsRepository;

  SetPayjoinMinAmountUsecase({required this._settingsRepository});

  /// Enforces [PayjoinConstants.minMinAmountSat]/[maxMinAmountSat] here, not
  /// just in the settings screen's input validator — the UI can be bypassed
  /// (a stale build, a future second entry point), the domain must not.
  Future<void> execute(int amountSat) async {
    if (amountSat < PayjoinConstants.minMinAmountSat ||
        amountSat > PayjoinConstants.maxMinAmountSat) {
      throw ArgumentError.value(
        amountSat,
        'amountSat',
        'Must be between ${PayjoinConstants.minMinAmountSat} and '
            '${PayjoinConstants.maxMinAmountSat} sats',
      );
    }
    await _settingsRepository.setPayjoinMinAmountSat(amountSat);
  }
}
