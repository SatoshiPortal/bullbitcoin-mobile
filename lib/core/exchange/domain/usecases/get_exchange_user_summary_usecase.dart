import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/errors/exchange_errors.dart';
import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_user_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';

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
      final repo =
          isTestnet
              ? _testnetExchangeUserRepository
              : _mainnetExchangeUserRepository;
      final userSummary = await repo.getUserSummary();

      if (userSummary == null) {
        throw GetExchangeUserSummaryException('User summary is null');
      }

      return userSummary;
    } catch (e) {
      // TODO: Check if we really need a specific exception for this instead
      // of just using GetEchangeUserSummaryException also for ApiKeyException
      if (e is ApiKeyException) {
        rethrow;
      }
      throw GetExchangeUserSummaryException('$e');
    }
  }
}

class GetExchangeUserSummaryException extends BullException {
  GetExchangeUserSummaryException(super.message);
}
