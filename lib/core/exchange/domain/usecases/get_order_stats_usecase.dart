import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/exchange/domain/entity/order_stats.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';

class GetOrderStatsUsecase {
  final ExchangeOrderRepository _mainnetRepository;
  final ExchangeOrderRepository _testnetRepository;
  final SettingsRepository _settingsRepository;

  GetOrderStatsUsecase({
    required ExchangeOrderRepository mainnetExchangeOrderRepository,
    required ExchangeOrderRepository testnetExchangeOrderRepository,
    required SettingsRepository settingsRepository,
  })  : _mainnetRepository = mainnetExchangeOrderRepository,
        _testnetRepository = testnetExchangeOrderRepository,
        _settingsRepository = settingsRepository;

  Future<OrderStats> execute() async {
    try {
      final settings = await _settingsRepository.fetch();
      final isTestnet = settings.environment.isTestnet;
      final repo = isTestnet ? _testnetRepository : _mainnetRepository;

      return await repo.getOrderStats();
    } catch (e) {
      throw GetOrderStatsException('$e');
    }
  }
}

class GetOrderStatsException extends BullException {
  GetOrderStatsException(super.message);
}






