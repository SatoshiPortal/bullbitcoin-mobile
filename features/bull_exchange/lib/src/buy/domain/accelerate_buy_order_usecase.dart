import 'package:primitives/primitives.dart';
import 'package:bull_exchange/src/buy/domain/map_buy_order_failure.dart';
import 'package:bull_exchange/src/buy/domain/buy_failure.dart';
import 'package:exchange/exchange.dart';
import 'package:preferences/preferences.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';

class AccelerateBuyOrderUsecase {
  final Exchange _exchange;
  final Preferences _settingsRepository;

  AccelerateBuyOrderUsecase({
    required this._exchange,
    required this._settingsRepository,
  });

  @useResult
  Future<Result<BuyOrder, BuyFailure>> execute(String orderId) async {
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
        log.warning('Capability refused feature=buy reason=unsupported');
        return const Err(BuyUnsupportedNetworkFailure());
      }
      final isTestnet = environment == NetworkEnv.testnet;
      final repo = _exchange.orders(
        isTestnet ? ExchangeEnvironment.testnet : ExchangeEnvironment.mainnet,
      );
      return (await repo.accelerateBuyOrder(orderId))
          .mapErr(mapBuyOrderFailure);
    } on Exception catch (e, st) {
      log.severe(
        message: 'Failed to accelerate the buy order',
        error: e.runtimeType,
        trace: st,
      );
      return Err(BuyUnexpectedFailure(e.runtimeType.toString()));
    }
  }
}
