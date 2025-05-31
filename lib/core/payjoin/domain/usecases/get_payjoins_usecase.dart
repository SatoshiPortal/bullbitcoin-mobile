import 'package:bb_mobile/core/payjoin/domain/entity/payjoin.dart';
import 'package:bb_mobile/core/payjoin/domain/repositories/payjoin_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';

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

class GetPayjoinsException implements Exception {
  final String message;

  GetPayjoinsException(this.message);

  @override
  String toString() => '[GetPayjoinsUsecase]: $message';
}
