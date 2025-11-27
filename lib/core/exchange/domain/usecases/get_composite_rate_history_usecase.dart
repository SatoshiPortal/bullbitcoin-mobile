import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/exchange/domain/entity/composite_rate_history.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_rate_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';

class GetCompositeRateHistoryUsecase {
  final ExchangeRateRepository _mainnetExchangeRateRepository;
  final ExchangeRateRepository _testnetExchangeRateRepository;
  final SettingsRepository _settingsRepository;

  GetCompositeRateHistoryUsecase({
    required ExchangeRateRepository mainnetExchangeRateRepository,
    required ExchangeRateRepository testnetExchangeRateRepository,
    required SettingsRepository settingsRepository,
  }) : _mainnetExchangeRateRepository = mainnetExchangeRateRepository,
       _testnetExchangeRateRepository = testnetExchangeRateRepository,
       _settingsRepository = settingsRepository;

  Future<CompositeRateHistory> execute({
    required String fromCurrency,
    required String toCurrency,
  }) async {
    try {
      final settings = await _settingsRepository.fetch();
      final isTestnet = settings.environment.isTestnet;
      final repo =
          isTestnet
              ? _testnetExchangeRateRepository
              : _mainnetExchangeRateRepository;

      final compositeRateHistory = await repo.getCompositeRateHistory(
        fromCurrency: fromCurrency,
        toCurrency: toCurrency,
      );

      return compositeRateHistory;
    } catch (e) {
      throw GetCompositeRateHistoryException('$e');
    }
  }
}

class GetCompositeRateHistoryException extends BullException {
  GetCompositeRateHistoryException(super.message);
}
