import 'package:primitives/primitives.dart';
import 'package:exchange/exchange.dart';
import 'package:preferences/preferences.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';

class GetOrderUsecase {
  final Exchange _exchange;
  final Preferences _settingsRepository;

  GetOrderUsecase({required this._exchange, required this._settingsRepository});

  @useResult
  Future<Result<Order, ExchangeFailure>> execute({
    required String orderId,
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
    final result = await _exchange.orders(environment).getOrder(orderId);
    if (result case Err(:final failure)) {
      log.warning('Exchange order unavailable: ${failure.runtimeType}');
    }
    return result;
  }
}
