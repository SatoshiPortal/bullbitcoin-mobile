import 'package:bb_mobile/core/exchange/domain/entity/order_stats.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_stats_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';

class GetOrderStatsUsecase {
  final ExchangeOrderStatsRepository _mainnetRepository;
  final ExchangeOrderStatsRepository _testnetRepository;
  final SettingsRepository _settingsRepository;

  GetOrderStatsUsecase({
    required this._mainnetRepository,
    required this._testnetRepository,
    required this._settingsRepository,
  });

  Future<OrderStatsResponse> execute() async {
    final settings = await _settingsRepository.fetch();
    final isTestnet = settings.environment.isTestnet;

    final repository = isTestnet ? _testnetRepository : _mainnetRepository;
    return repository.getOrderStats();
  }
}
