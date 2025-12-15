import 'package:bb_mobile/core_deprecated/errors/bull_exception.dart';
import 'package:bb_mobile/core_deprecated/payjoin/domain/entity/payjoin.dart';
import 'package:bb_mobile/core_deprecated/payjoin/domain/repositories/payjoin_repository.dart';
import 'package:bb_mobile/core_deprecated/settings/data/settings_repository.dart';

class GetPayjoinsUsecase {
  final PayjoinRepository _payjoinRepository;
  final SettingsRepository _settingsRepository;

  GetPayjoinsUsecase({
    required PayjoinRepository payjoinRepository,
    required SettingsRepository settingsRepository,
  }) : _settingsRepository = settingsRepository,
       _payjoinRepository = payjoinRepository;

  Future<List<Payjoin>> execute({
    String? walletId,
    bool onlyOngoing = false,
  }) async {
    try {
      final settings = await _settingsRepository.fetch();
      final environment = settings.environment;

      final payjoins = await _payjoinRepository.getPayjoins(
        walletId: walletId,
        onlyOngoing: onlyOngoing,
        environment: environment,
      );

      return payjoins;
    } catch (e) {
      throw GetPayjoinsException('Failed to fetch payjoins: $e');
    }
  }
}

class GetPayjoinsException extends BullException {
  GetPayjoinsException(super.message);
}
