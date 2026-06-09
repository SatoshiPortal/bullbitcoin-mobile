import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_user_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/utils/staging_env.dart';

class GetExchangeUserSummaryUsecase {
  final ExchangeUserRepository _mainnetExchangeUserRepository;
  final ExchangeUserRepository _testnetExchangeUserRepository;
  final SettingsRepository _settingsRepository;

  GetExchangeUserSummaryUsecase({
    required ExchangeUserRepository mainnetExchangeUserRepository,
    required ExchangeUserRepository testnetExchangeUserRepository,
    required SettingsRepository settingsRepository,
  }) : _mainnetExchangeUserRepository = mainnetExchangeUserRepository,
       _testnetExchangeUserRepository = testnetExchangeUserRepository,
       _settingsRepository = settingsRepository;

  Future<UserSummary> execute() async {
    try {
      final settings = await _settingsRepository.fetch();
      final isTestnet = settings.environment.isTestnet;
      if (isTestnet && !StagingEnv.isConfigured) {
        throw GetExchangeUserSummaryException('User summary is null');
      }
      final repo = StagingEnv.useTestnetExchange(isTestnet)
          ? _testnetExchangeUserRepository
          : _mainnetExchangeUserRepository;
      final userSummary = await repo.getUserSummary();

      if (userSummary == null) {
        throw GetExchangeUserSummaryException('User summary is null');
      }

      return userSummary;
    } catch (e) {
      throw GetExchangeUserSummaryException('$e');
    }
  }
}

class GetExchangeUserSummaryException extends BullException {
  GetExchangeUserSummaryException(super.message);
}
