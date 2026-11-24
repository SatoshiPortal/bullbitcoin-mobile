import 'package:primitives/primitives.dart';
import 'package:bull_exchange/src/buy/domain/map_buy_order_failure.dart';
import 'package:bull_exchange/src/buy/domain/buy_failure.dart';
import 'package:exchange/exchange.dart';
import 'package:preferences/preferences.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';

class RefreshBuyOrderUsecase {
  final Exchange _exchange;
  final Preferences _settingsRepository;

  RefreshBuyOrderUsecase({
    required this._exchange,
    required this._settingsRepository,
  });

  /// A fresh quote for an order awaiting confirmation; once [confirmed], the
  /// order as the exchange now sees it, which asks for no new quote.
  @useResult
  Future<Result<BuyOrder, BuyFailure>> execute({
    required String orderId,
    bool confirmed = false,
  }) async {
    try {
      final SettingsEntity settings;
      switch (await _settingsRepository.fetch()) {
        case Ok(:final value):
          settings = value;
        case Err():
          return const Err(BuyUnexpectedFailure('Preferences read failed'));
      }
      final environment = settings.environment.networkEnv;
      final exchangeNetwork = switch (environment) {
        NetworkEnv.mainnet => BitcoinNetwork.mainnet,
        NetworkEnv.testnet => BitcoinNetwork.testnet,
        NetworkEnv.regtest => BitcoinNetwork.regtest,
        NetworkEnv.signet => BitcoinNetwork.signet,
      };
      if (!NetworkCapabilities.supports(
        exchangeNetwork,
        NetworkCapability.exchange,
      )) {
        return const Err(BuyUnsupportedNetworkFailure());
      }
      final isTestnet = environment == NetworkEnv.testnet;
      final repo = _exchange.orders(
        isTestnet ? ExchangeEnvironment.testnet : ExchangeEnvironment.mainnet,
      );
      if (!confirmed) {
        return (await repo.refreshBuyOrder(orderId)).mapErr(mapBuyOrderFailure);
      }
      final Order order;
      switch (await repo.getOrder(orderId)) {
        case Ok(:final value):
          order = value;
        case Err(:final failure):
          return Err(mapBuyOrderFailure(failure));
      }
      if (order is! BuyOrder) {
        log.severe(
          error: 'Expected a buy order but read ${order.runtimeType}',
          trace: StackTrace.current,
        );
        return const Err(BuyUnexpectedFailure('Expected a buy order'));
      }
      return Ok(order);
    } on Exception catch (e, st) {
      log.severe(
        message: 'Failed to refresh the buy order',
        error: e.runtimeType,
        trace: st,
      );
      return Err(BuyUnexpectedFailure(e.runtimeType.toString()));
    }
  }
}
