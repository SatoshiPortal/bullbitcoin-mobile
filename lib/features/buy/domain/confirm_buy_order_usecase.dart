import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/buy/domain/map_buy_order_failure.dart';
import 'package:bb_mobile/features/buy/domain/buy_failure.dart';
import 'package:exchange/exchange.dart';
import 'package:preferences/preferences.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';
import 'package:labels/labels.dart';

class ConfirmBuyOrderUsecase {
  final Exchange _exchange;
  final Preferences _settingsRepository;
  final Labels _labelsFacade;

  ConfirmBuyOrderUsecase({
    required this._exchange,
    required this._settingsRepository,
    required this._labelsFacade,
  });

  @useResult
  Future<Result<BuyOrder, BuyFailure>> execute({
    required String orderId,
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
        log.warning('Capability refused feature=buy reason=unsupported');
        return const Err(BuyUnsupportedNetworkFailure());
      }
      final isTestnet = environment == NetworkEnv.testnet;
      final repo = _exchange.orders(
        isTestnet ? ExchangeEnvironment.testnet : ExchangeEnvironment.mainnet,
      );
      final BuyOrder order;
      switch (await repo.confirmBuyOrder(orderId)) {
        case Ok(:final value):
          order = value;
        case Err(:final failure):
          return Err(mapBuyOrderFailure(failure));
      }

      if (order.toAddress case final address?) {
        await _labelsFacade.store(
          NewLabel.addr(address: address, label: LabelSystem.exchangeBuy.label),
        );
      }

      return Ok(order);
    } on Exception catch (e, st) {
      log.severe(
        message: 'Failed to confirm the buy order',
        error: e.runtimeType,
        trace: st,
      );
      return Err(BuyUnexpectedFailure(e.runtimeType.toString()));
    }
  }
}
