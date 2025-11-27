import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/exchange/domain/entity/rate_history.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_rate_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';

class RefreshRateHistoryUsecase {
  final ExchangeRateRepository _mainnetExchangeRateRepository;
  final ExchangeRateRepository _testnetExchangeRateRepository;
  final SettingsRepository _settingsRepository;

  RefreshRateHistoryUsecase({
    required ExchangeRateRepository mainnetExchangeRateRepository,
    required ExchangeRateRepository testnetExchangeRateRepository,
    required SettingsRepository settingsRepository,
  }) : _mainnetExchangeRateRepository = mainnetExchangeRateRepository,
       _testnetExchangeRateRepository = testnetExchangeRateRepository,
       _settingsRepository = settingsRepository;

  Future<void> execute({
    required String fromCurrency,
    required String toCurrency,
    required RateTimelineInterval interval,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      final settings = await _settingsRepository.fetch();
      final isTestnet = settings.environment.isTestnet;
      final repo =
          isTestnet
              ? _testnetExchangeRateRepository
              : _mainnetExchangeRateRepository;

      await repo.refreshRateHistory(
        fromCurrency: fromCurrency,
        toCurrency: toCurrency,
        interval: interval,
        fromDate: fromDate,
        toDate: toDate,
      );
    } catch (e) {
      throw RefreshRateHistoryException('$e');
    }
  }
}

class RefreshRateHistoryException extends BullException {
  RefreshRateHistoryException(super.message);
}
