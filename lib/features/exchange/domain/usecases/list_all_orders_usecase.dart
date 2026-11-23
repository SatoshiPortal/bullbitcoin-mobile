import 'package:primitives/primitives.dart';
import 'package:exchange/exchange.dart';
import 'package:preferences/preferences.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';

class ListAllOrdersUsecase {
  final Exchange _exchange;
  final Preferences _settingsRepository;

  ListAllOrdersUsecase({
    required this._exchange,
    required this._settingsRepository,
  });

  @useResult
  Future<Result<List<Order>, ExchangeFailure>> execute({
    int? limit,
    int? offset,
    OrderType? type,
  }) async {
    final ExchangeEnvironment environment;
    switch (await _settingsRepository.fetch()) {
      case Err():
        return const Err(ExchangeOrderLoadFailure());
      case Ok(value: SettingsEntity(environment: Environment.regtest)):
        return const Err(ExchangeUnsupportedNetworkFailure());
      case Ok(value: final settings):
        environment = settings.environment == Environment.testnet
            ? ExchangeEnvironment.testnet
            : ExchangeEnvironment.mainnet;
    }
    final result = await _exchange
        .orders(environment)
        .getOrders(limit: limit, offset: offset, type: type);
    if (result case Err(:final failure)) {
      log.warning('Exchange order unavailable: ${failure.runtimeType}');
    }
    return result;
  }
}
