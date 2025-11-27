import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/exchange/domain/entity/rate_history.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_rate_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';

class GetAllIntervalsRateHistoryUsecase {
  final ExchangeRateRepository _mainnetExchangeRateRepository;
  final ExchangeRateRepository _testnetExchangeRateRepository;
  final SettingsRepository _settingsRepository;

  GetAllIntervalsRateHistoryUsecase({
    required ExchangeRateRepository mainnetExchangeRateRepository,
    required ExchangeRateRepository testnetExchangeRateRepository,
    required SettingsRepository settingsRepository,
  }) : _mainnetExchangeRateRepository = mainnetExchangeRateRepository,
       _testnetExchangeRateRepository = testnetExchangeRateRepository,
       _settingsRepository = settingsRepository;

  Future<Map<RateTimelineInterval, RateHistory>> execute({
    required String fromCurrency,
    required String toCurrency,
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

      final allIntervals = await repo.getAllIntervalsRateHistory(
        fromCurrency: fromCurrency,
        toCurrency: toCurrency,
        fromDate: fromDate,
        toDate: toDate,
      );

      return allIntervals;
    } catch (e) {
      throw GetAllIntervalsRateHistoryException('$e');
    }
  }
}

class GetAllIntervalsRateHistoryException extends BullException {
  GetAllIntervalsRateHistoryException(super.message);
}
